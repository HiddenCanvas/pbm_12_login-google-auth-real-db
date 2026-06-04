-- Alter fcm_tokens table to support multiple tokens per user
-- We set the primary key to be 'token' instead of 'user_id'

CREATE TABLE IF NOT EXISTS fcm_tokens (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (token)
);

-- In case fcm_tokens already exists, we drop the primary key constraint or unique constraint on user_id, and make token the primary key.
DO $$
BEGIN
  -- Check if fcm_tokens exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'fcm_tokens') THEN
    -- Try to drop constraint if it exists (usually fcm_tokens_pkey or fcm_tokens_user_id_key)
    ALTER TABLE fcm_tokens DROP CONSTRAINT IF EXISTS fcm_tokens_pkey;
    ALTER TABLE fcm_tokens DROP CONSTRAINT IF EXISTS fcm_tokens_user_id_key;
    
    -- Ensure token is the primary key
    IF NOT EXISTS (
      SELECT 1 
      FROM information_schema.table_constraints 
      WHERE table_name = 'fcm_tokens' AND constraint_type = 'PRIMARY KEY'
    ) THEN
      ALTER TABLE fcm_tokens ADD CONSTRAINT fcm_tokens_pkey PRIMARY KEY (token);
    END IF;
  END IF;
END $$;

-- Enable RLS
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can insert/update their own tokens" ON fcm_tokens;
DROP POLICY IF EXISTS "Users can delete their own tokens" ON fcm_tokens;
DROP POLICY IF EXISTS "Users can read all tokens" ON fcm_tokens;

-- Policy: INSERT/UPDATE - users can only upsert their own tokens
CREATE POLICY "Users can insert/update their own tokens" ON fcm_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: SELECT - authenticated users can read other users' tokens to send notifications
CREATE POLICY "Users can read all tokens" ON fcm_tokens
  FOR SELECT
  USING (auth.role() = 'authenticated');
