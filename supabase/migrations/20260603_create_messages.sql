-- Create messages table for realtime chat
-- Migration: 20260603_create_messages.sql

-- Buat tabel messages
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  room_id TEXT NOT NULL DEFAULT 'general',
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Jika tabel sudah ada dari SQL editor lama, tambahkan kolom yang hilang dulu
ALTER TABLE messages ADD COLUMN IF NOT EXISTS room_id TEXT NOT NULL DEFAULT 'general';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Buat index untuk query yang lebih cepat
CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_user_id ON messages(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_room_created ON messages(room_id, created_at DESC);

-- Enable RLS pada tabel messages
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policy: INSERT - hanya user yang sudah login bisa insert pesan dengan user_id mereka sendiri
CREATE POLICY "Users can insert their own messages"
  ON messages
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: SELECT - semua authenticated user bisa membaca pesan
CREATE POLICY "Authenticated users can view messages"
  ON messages
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Policy: UPDATE - user hanya bisa update pesan mereka sendiri (optional, untuk edit fitur)
CREATE POLICY "Users can update their own messages"
  ON messages
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: DELETE - user hanya bisa delete pesan mereka sendiri (optional)
CREATE POLICY "Users can delete their own messages"
  ON messages
  FOR DELETE
  USING (auth.uid() = user_id);

-- Enable realtime untuk tabel messages jika belum ditambahkan
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_rel pr
    JOIN pg_publication p ON pr.prpubid = p.oid
    JOIN pg_class c ON pr.prrelid = c.oid
    WHERE p.pubname = 'supabase_realtime' AND c.relname = 'messages'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE messages';
  END IF;
END;
$$;

-- Create trigger untuk update updated_at
CREATE OR REPLACE FUNCTION update_messages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_messages_updated_at_trigger
BEFORE UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_messages_updated_at();
