-- Run this in Supabase SQL Editor (https://supabase.com/dashboard)
-- or via supabase CLI: supabase db push

-- Users table (syncs with Supabase Auth)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, display_name, email, created_at)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email), NEW.email, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bills
CREATE TABLE IF NOT EXISTS bills (
  id BIGSERIAL PRIMARY KEY,
  group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  payer_id UUID NOT NULL REFERENCES users(id),
  amount DOUBLE PRECISION NOT NULL,
  description TEXT NOT NULL,
  participant_ids UUID[] NOT NULL DEFAULT '{}',
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
CREATE INDEX IF NOT EXISTS idx_groups_member_ids ON groups USING GIN (member_ids);
CREATE INDEX IF NOT EXISTS idx_groups_invite_code ON groups (invite_code);
CREATE INDEX IF NOT EXISTS idx_bills_group_id ON bills (group_id);
CREATE INDEX IF NOT EXISTS idx_settlements_group_id ON settlements (group_id);

-- Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;

-- Users: anyone authenticated can read; user can update own row
CREATE POLICY "Users are viewable by authenticated users" ON users
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users can update own record" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Groups: members can read; anyone authenticated can create
CREATE POLICY "Groups viewable by members" ON groups
  FOR SELECT USING (auth.uid() = ANY(member_ids));
CREATE POLICY "Groups creatable by authenticated users" ON groups
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Groups updatable by creator" ON groups
  FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "Groups deletable by creator" ON groups
  FOR DELETE USING (auth.uid() = creator_id);

-- Bills: group members can read/payer can create
CREATE POLICY "Bills viewable by group members" ON bills
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = bills.group_id AND auth.uid() = ANY(groups.member_ids))
  );
CREATE POLICY "Bills creatable by group members" ON bills
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = bills.group_id AND auth.uid() = ANY(groups.member_ids))
  );

-- Settlements: involved users can read/create
CREATE POLICY "Settlements viewable by group members" ON settlements
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = settlements.group_id AND auth.uid() = ANY(groups.member_ids))
  );
CREATE POLICY "Settlements creatable by involved users" ON settlements
  FOR INSERT WITH CHECK (
    auth.uid() = from_user_id OR auth.uid() = to_user_id
  );
