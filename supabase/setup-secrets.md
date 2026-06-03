# Setup Firebase Secrets untuk Supabase

Panduan langkah demi langkah untuk mengintegrasikan Firebase Service Account dengan Supabase Edge Functions.

## 📋 Prasyarat

- Project Firebase sudah dibuat (Project ID: `mapia-9b430`)
- Supabase CLI sudah terinstall
- Akses ke Google Cloud Console

## 🔑 Langkah 1: Dapatkan Firebase Service Account JSON

### Via Firebase Console:

1. Buka [Firebase Console](https://console.firebase.google.com)
2. Pilih Project: **mapia-9b430**
3. Klik **⚙️ Project Settings** (gear icon, kanan atas)
4. Buka tab **Service Accounts**
5. Klik tombol **Generate New Private Key**
6. File JSON akan ter-download otomatis

### File JSON akan berisi:
```json
{
  "type": "service_account",
  "project_id": "mapia-9b430",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@mapia-9b430.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  ...
}
```

## 🔐 Langkah 2: Simpan sebagai Supabase Secret

### Gunakan Supabase CLI:

**Option 1: Interaktif**
```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON
# Paste isi file JSON, tekan Enter, lalu Ctrl+D (Linux/Mac) atau Ctrl+Z (Windows)
```

**Option 2: Dari File**
```bash
# Ganti <path-to-file> dengan lokasi file JSON
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON "$(cat <path-to-file>)"
```

**Option 3: Langsung paste (Linux/Mac)**
```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON < service-account.json
```

## ✅ Verifikasi Secret Tersimpan

```bash
# List semua secrets
supabase secrets list

# Output akan menampilkan:
# FIREBASE_SERVICE_ACCOUNT_JSON    [Encrypted]
```

## 🚀 Langkah 3: Deploy Edge Function

```bash
# Deploy function send-notification
supabase functions deploy send-notification

# Output:
# ✓ Function deployed successfully
```

## 🧪 Test Edge Function

### Test dengan curl (sebelum production):

```bash
# Ganti dengan secret API key Anda
SECRET_API_KEY="sb_secret_xxxxxxxxxxxxx"

curl -X POST \
  http://127.0.0.1:54321/functions/v1/send-notification \
  -H "apiKey: $SECRET_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "targetToken": "YOUR_FCM_TOKEN",
    "title": "Test Notification",
    "body": "Hello from Supabase!",
    "senderName": "Test User"
  }'
```

### Response Sukses:
```json
{
  "success": true,
  "messageId": "projects/mapia-9b430/messages/1234567890",
  "message": "Notifikasi berhasil dikirim ke Test User"
}
```

## 🐛 Troubleshooting

### Error: "FIREBASE_SERVICE_ACCOUNT_JSON secret not configured"
- Pastikan secret sudah di-set: `supabase secrets list`
- Redeploy function: `supabase functions deploy send-notification`

### Error: "Invalid JSON in service account"
- Periksa apakah JSON valid di [jsonlint.com](https://jsonlint.com)
- Pastikan escape character sudah benar (terutama pada `private_key`)

### Error: "FCM API returned 403"
- Pastikan Firebase Admin SDK API sudah enabled:
  - Buka [Google Cloud Console](https://console.cloud.google.com)
  - APIs & Services → Enabled APIs
  - Cari "Firebase Admin SDK API", pastikan enabled

### Error: "Unauthorized: Use secret API key"
- Pastikan menggunakan `secret` API key, bukan `publishable` key
- Lihat `.supabase/config.toml` untuk mendapatkan secret key

## 📝 Untuk Development Lokal

```bash
# 1. Jalankan Supabase lokal
supabase start

# 2. Copy isi service account JSON
# (Ganti path-nya)
cat path/to/service-account.json

# 3. Set secret (terminal terpisah)
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON < path/to/service-account.json

# 4. Restart functions
supabase functions deploy send-notification
```

## 🔒 Security Best Practices

- ✅ **Jangan** commit `service-account.json` ke Git
- ✅ **Jangan** hardcode credentials di code
- ✅ **Jangan** share service account JSON ke orang lain
- ✅ Rotate service account keys secara berkala
- ✅ Gunakan environment variables untuk secrets

## 📚 Referensi

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [FCM v1 API Reference](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
- [Google Cloud Service Accounts](https://cloud.google.com/docs/authentication/production)
