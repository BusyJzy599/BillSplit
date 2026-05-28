-- BillSplit v1.0 — Supabase Migration
-- Run in Supabase SQL Editor or via: supabase db push

-- Users table (syncs with Supabase Auth)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER SECURITY DEFINER SET search_path = ''
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.users (id, display_name, email, created_at)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email), NEW.email, NOW());
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Groups
CREATE TABLE IF NOT EXISTS groups (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  invite_code TEXT NOT NULL UNIQUE,
  creator_id UUID NOT NULL REFERENCES users(id),
  member_ids UUID[] NOT NULL DEFAULT '{}',
  icon TEXT NOT NULL DEFAULT '👥',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Dedup trigger for member_ids
CREATE OR REPLACE FUNCTION public.dedup_member_ids()
RETURNS TRIGGER SECURITY DEFINER SET search_path = ''
LANGUAGE plpgsql AS $$
BEGIN
  NEW.member_ids = ARRAY(SELECT DISTINCT unnest(NEW.member_ids));
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dedup_member_ids() FROM PUBLIC, anon, authenticated;

-- Bills
CREATE TABLE IF NOT EXISTS bills (
  id BIGSERIAL PRIMARY KEY,
  group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  payer_id UUID NOT NULL REFERENCES users(id),
  amount DOUBLE PRECISION NOT NULL,
  description TEXT NOT NULL,
  participant_ids UUID[] NOT NULL DEFAULT '{}',
  currency TEXT NOT NULL DEFAULT 'cny',
  exchange_rate DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  category TEXT NOT NULL DEFAULT 'other',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Settlements
CREATE TABLE IF NOT EXISTS settlements (
  id BIGSERIAL PRIMARY KEY,
  bill_id BIGINT REFERENCES bills(id) ON DELETE SET NULL,
  group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  from_user_id UUID NOT NULL REFERENCES users(id),
  to_user_id UUID NOT NULL REFERENCES users(id),
  amount DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_groups_invite_code ON groups (invite_code);
CREATE INDEX IF NOT EXISTS idx_bills_group_id ON bills (group_id);
CREATE INDEX IF NOT EXISTS idx_bills_payer_id ON bills (payer_id);
CREATE INDEX IF NOT EXISTS idx_groups_creator_id ON groups (creator_id);
CREATE INDEX IF NOT EXISTS idx_settlements_group_id ON settlements (group_id);
CREATE INDEX IF NOT EXISTS idx_settlements_from_user_id ON settlements (from_user_id);
CREATE INDEX IF NOT EXISTS idx_settlements_to_user_id ON settlements (to_user_id);
CREATE INDEX IF NOT EXISTS idx_settlements_bill_id ON settlements (bill_id);

-- RLS — all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;

-- Users
CREATE POLICY "Users are viewable by authenticated users" ON users
  FOR SELECT USING ((select auth.role()) = 'authenticated');
CREATE POLICY "Users can update own record" ON users
  FOR UPDATE USING ((select auth.uid()) = id);

-- Groups
CREATE POLICY "Groups viewable by authenticated users" ON groups
  FOR SELECT USING ((select auth.role()) = 'authenticated');
CREATE POLICY "Groups creatable by authenticated users" ON groups
  FOR INSERT WITH CHECK ((select auth.role()) = 'authenticated');
CREATE POLICY "Groups updatable by creator" ON groups
  FOR UPDATE USING ((select auth.uid()) = creator_id);
CREATE POLICY "Groups deletable by creator" ON groups
  FOR DELETE USING ((select auth.uid()) = creator_id);
CREATE POLICY "Groups updatable by any member" ON groups
  FOR UPDATE USING ((select auth.uid()) = ANY(member_ids));

-- Bills
CREATE POLICY "Bills viewable by group members" ON bills
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = bills.group_id AND (select auth.uid()) = ANY(groups.member_ids))
  );
CREATE POLICY "Bills creatable by group members" ON bills
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = bills.group_id AND (select auth.uid()) = ANY(groups.member_ids))
  );
CREATE POLICY "Bills updatable by group members" ON bills
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = bills.group_id AND (select auth.uid()) = ANY(groups.member_ids))
  );
CREATE POLICY "Bills deletable by group members" ON bills
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = bills.group_id AND (select auth.uid()) = ANY(groups.member_ids))
  );

-- Settlements
CREATE POLICY "Settlements viewable by group members" ON settlements
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = settlements.group_id AND (select auth.uid()) = ANY(groups.member_ids))
  );
CREATE POLICY "Settlements creatable by involved users" ON settlements
  FOR INSERT WITH CHECK (
    (select auth.uid()) = from_user_id OR (select auth.uid()) = to_user_id
  );
CREATE POLICY "Settlements updatable by involved users" ON settlements
  FOR UPDATE USING ((select auth.uid()) = from_user_id OR (select auth.uid()) = to_user_id);
CREATE POLICY "Settlements deletable by involved users" ON settlements
  FOR DELETE USING ((select auth.uid()) = from_user_id OR (select auth.uid()) = to_user_id);

-- Storage: avatars bucket
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;
CREATE POLICY "Avatars readable by authenticated" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars' AND (select auth.role()) = 'authenticated');
CREATE POLICY "Users can upload avatar" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars' AND (select auth.role()) = 'authenticated');
CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (bucket_id = 'avatars' AND (select auth.uid())::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete own avatar" ON storage.objects
  FOR DELETE USING (bucket_id = 'avatars' AND (select auth.uid())::text = (storage.foldername(name))[1]);
