import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

interface RequestPayload {
  targetToken?: string;
  targetTokens?: string[];
  title: string;
  body: string;
  senderName: string;
}

export default {
  fetch: withSupabase({ auth: ["secret"] }, async (req, ctx) => {
    // Hanya terima secret key untuk keamanan
    if (ctx.authMode !== "secret") {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Use secret API key" }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    let payload: RequestPayload;
    try {
      payload = await req.json();
    } catch (_error) {
      return new Response(
        JSON.stringify({ error: "Invalid JSON payload" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Validasi input
    const { targetToken, targetTokens, title, body, senderName } = payload;
    const tokens = targetTokens || (targetToken ? [targetToken] : []);

    if (tokens.length === 0 || !title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: targetToken/targetTokens, title, body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    try {
      // Ambil Firebase Service Account dari Supabase Secret
      const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
      if (!serviceAccountJson) {
        throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON secret not configured");
      }

      const serviceAccount = JSON.parse(serviceAccountJson);
      const projectId = serviceAccount.project_id;

      // Build JWT assertion and exchange for OAuth2 access token
      function base64UrlEncode(str: string) {
        return btoa(unescape(encodeURIComponent(str)))
          .replace(/\+/g, "-")
          .replace(/\//g, "_")
          .replace(/=+$/, "");
      }

      function base64UrlEncodeBuffer(buf: ArrayBuffer) {
        const bytes = new Uint8Array(buf);
        let binary = "";
        for (let i = 0; i < bytes.byteLength; i++) {
          binary += String.fromCharCode(bytes[i]);
        }
        return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
      }

      // Prepare JWT
      const header = { alg: "RS256", typ: "JWT" };
      const now = Math.floor(Date.now() / 1000);
      const jwtPayload = {
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        exp: now + 3600,
        iat: now,
      };

      const headerEncoded = base64UrlEncode(JSON.stringify(header));
      const payloadEncoded = base64UrlEncode(JSON.stringify(jwtPayload));
      const signatureInput = `${headerEncoded}.${payloadEncoded}`;

      // Import private key (PKCS8 PEM) into CryptoKey
      function pemToArrayBuffer(pem: string): ArrayBuffer {
        const pemBody = pem
          .replace(/-----BEGIN PRIVATE KEY-----/g, "")
          .replace(/-----END PRIVATE KEY-----/g, "")
          .replace(/\s+/g, "");
        const binary = atob(pemBody);
        const len = binary.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binary.charCodeAt(i);
        }
        return bytes.buffer;
      }

      const pkcs8 = pemToArrayBuffer(serviceAccount.private_key);
      const cryptoKey = await crypto.subtle.importKey(
        "pkcs8",
        pkcs8,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
      );

      // Sign the JWT
      const signatureBuf = await crypto.subtle.sign(
        { name: "RSASSA-PKCS1-v1_5" },
        cryptoKey,
        new TextEncoder().encode(signatureInput),
      );
      const signatureEncoded = base64UrlEncodeBuffer(signatureBuf);
      const assertion = `${signatureInput}.${signatureEncoded}`;

      // Exchange assertion for access token
      const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: assertion,
        }).toString(),
      });

      if (!tokenResp.ok) {
        const txt = await tokenResp.text();
        console.error("Token endpoint error:", tokenResp.status, txt);
        throw new Error("Failed to obtain access token for FCM");
      }

      const tokenData = await tokenResp.json();
      const accessToken = tokenData.access_token as string | undefined;
      if (!accessToken) throw new Error("No access_token received from OAuth token endpoint");

      const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

      // Kirim ke semua token secara paralel
      const sendPromises = tokens.map(async (token) => {
        const fcmMessage = {
          message: {
            token: token,
            notification: { title, body },
            data: { senderName: senderName || "Unknown" },
          },
        };

        try {
          const fcmResponse = await fetch(fcmEndpoint, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(fcmMessage),
          });

          if (!fcmResponse.ok) {
            const errorText = await fcmResponse.text();
            console.error(`FCM API error for token ${token.substring(0, 10)}...: ${fcmResponse.status} - ${errorText}`);
            return { token, success: false, error: errorText };
          }

          const result = await fcmResponse.json() as { name?: string };
          const messageId = result.name?.split("/").pop() || "unknown";
          return { token, success: true, messageId };
        } catch (e) {
          console.error(`Fetch error for token ${token.substring(0, 10)}...:`, e);
          return { token, success: false, error: String(e) };
        }
      });

      const results = await Promise.all(sendPromises);
      const successCount = results.filter(r => r.success).length;

      return new Response(
        JSON.stringify({
          success: true,
          successCount,
          totalCount: tokens.length,
          results: results.map(r => ({
            token: `${r.token.substring(0, 10)}...`,
            success: r.success,
            messageId: r.success ? r.messageId : undefined,
            error: !r.success ? r.error : undefined,
          })),
          message: `Notifikasi terkirim ke ${successCount} dari ${tokens.length} perangkat.`,
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
          },
        }
      );
    } catch (error) {
      console.error("Error in send-notification:", error);
      return new Response(
        JSON.stringify({
          success: false,
          error: String(error),
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }
  }),
};