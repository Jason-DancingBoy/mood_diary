-- ============================================
-- 心情日记 Supabase 数据库建表脚本
-- 在 Supabase SQL Editor 中执行此脚本
-- 可重复执行（先删旧策略再建新的，表用 IF NOT EXISTS）
-- ============================================

-- 1. Profiles 表 (用户资料，关联 auth.users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nickname TEXT NOT NULL,
    friend_code TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    bio TEXT DEFAULT '',
    show_mood_to_friends BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 为已有数据库补加 show_mood_to_friends 列
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS show_mood_to_friends BOOLEAN DEFAULT TRUE;

DROP POLICY IF EXISTS "Profiles are viewable by all authenticated users" ON profiles;
CREATE POLICY "Profiles are viewable by all authenticated users"
    ON profiles FOR SELECT
    USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
CREATE POLICY "Users can insert their own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- 2. Friends 表 (好友关系)
CREATE TABLE IF NOT EXISTS friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT different_users CHECK (requester_id <> addressee_id),
    UNIQUE(requester_id, addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_friends_requester ON friends(requester_id);
CREATE INDEX IF NOT EXISTS idx_friends_addressee ON friends(addressee_id);

ALTER TABLE friends ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own friend relationships" ON friends;
CREATE POLICY "Users can view their own friend relationships"
    ON friends FOR SELECT
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

DROP POLICY IF EXISTS "Users can send friend requests" ON friends;
CREATE POLICY "Users can send friend requests"
    ON friends FOR INSERT
    WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS "Users can update requests addressed to them" ON friends;
CREATE POLICY "Users can update requests addressed to them"
    ON friends FOR UPDATE
    USING (auth.uid() = addressee_id);

-- 3. Remote Moods 表 (远端心情记录)
CREATE TABLE IF NOT EXISTS remote_moods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    local_id TEXT,
    mood_type TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    comment TEXT DEFAULT '',
    image_urls TEXT[] DEFAULT '{}',
    audio_url TEXT,
    audio_duration INTEGER,
    custom_emoji TEXT,
    custom_emoji_label TEXT,
    custom_color_value INTEGER,
    ai_comfort TEXT,
    ai_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_remote_moods_owner ON remote_moods(owner_id);

ALTER TABLE remote_moods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own moods" ON remote_moods;
CREATE POLICY "Users can insert their own moods"
    ON remote_moods FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can view their own moods" ON remote_moods;
CREATE POLICY "Users can view their own moods"
    ON remote_moods FOR SELECT
    USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can delete their own moods" ON remote_moods;
CREATE POLICY "Users can delete their own moods"
    ON remote_moods FOR DELETE
    USING (auth.uid() = owner_id);

-- 4. Shared Moods 表 (分享记录)
CREATE TABLE IF NOT EXISTS shared_moods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    mood_id UUID NOT NULL REFERENCES remote_moods(id) ON DELETE CASCADE,
    permission TEXT NOT NULL DEFAULT 'view' CHECK (permission IN ('view', 'comment')),
    status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'received', 'deleted')),
    shared_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_shared_moods_from ON shared_moods(from_user_id);
CREATE INDEX IF NOT EXISTS idx_shared_moods_to ON shared_moods(to_user_id);

ALTER TABLE shared_moods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view shares they sent or received" ON shared_moods;
CREATE POLICY "Users can view shares they sent or received"
    ON shared_moods FOR SELECT
    USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

DROP POLICY IF EXISTS "Users can create shares" ON shared_moods;
CREATE POLICY "Users can create shares"
    ON shared_moods FOR INSERT
    WITH CHECK (auth.uid() = from_user_id);

DROP POLICY IF EXISTS "Recipients can mark as read or update status" ON shared_moods;
CREATE POLICY "Recipients can mark as read or update status"
    ON shared_moods FOR UPDATE
    USING (auth.uid() = to_user_id);

-- 4.5 补 remote_moods 交叉引用 shared_moods 的策略 (需 shared_moods 表先存在)
DROP POLICY IF EXISTS "Users can view moods shared with them" ON remote_moods;
CREATE POLICY "Users can view moods shared with them"
    ON remote_moods FOR SELECT
    USING (
        auth.uid() = owner_id
        OR id IN (
            SELECT mood_id FROM shared_moods WHERE to_user_id = auth.uid()
        )
    );

-- 4.5.1 允许好友查看开启了"向好友展示心情"的用户的心情
DROP POLICY IF EXISTS "Friends can view moods of users who share them" ON remote_moods;
CREATE POLICY "Friends can view moods of users who share them"
    ON remote_moods FOR SELECT
    USING (
      owner_id IN (
        SELECT id FROM profiles WHERE show_mood_to_friends = true
      )
      AND (
        auth.uid() IN (
          SELECT requester_id FROM friends
          WHERE addressee_id = remote_moods.owner_id AND status = 'accepted'
          UNION
          SELECT addressee_id FROM friends
          WHERE requester_id = remote_moods.owner_id AND status = 'accepted'
        )
      )
    );

-- 4.6 Friend Messages 表 (好友聊天消息)
CREATE TABLE IF NOT EXISTS friend_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL DEFAULT '',
    image_url TEXT,
    audio_url TEXT,
    audio_duration INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 为已存在的表补加列（幂等）
ALTER TABLE remote_moods ADD COLUMN IF NOT EXISTS audio_url TEXT;
ALTER TABLE remote_moods ADD COLUMN IF NOT EXISTS audio_duration INTEGER;
ALTER TABLE friend_messages ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE friend_messages ADD COLUMN IF NOT EXISTS audio_url TEXT;
ALTER TABLE friend_messages ADD COLUMN IF NOT EXISTS audio_duration INTEGER;
ALTER TABLE friend_messages ADD COLUMN IF NOT EXISTS is_ai_message BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_friend_messages_sender ON friend_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_friend_messages_receiver ON friend_messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_friend_messages_pair ON friend_messages(sender_id, receiver_id);

ALTER TABLE friend_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view messages they sent or received" ON friend_messages;
CREATE POLICY "Users can view messages they sent or received"
    ON friend_messages FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can send messages" ON friend_messages;
CREATE POLICY "Users can send messages"
    ON friend_messages FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- 5. Storage bucket (图片存储)
INSERT INTO storage.buckets (id, name, public)
VALUES ('mood_images', 'mood_images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Authenticated users can upload images" ON storage.objects;
CREATE POLICY "Authenticated users can upload images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'mood_images'
        AND auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "Anyone can view images" ON storage.objects;
CREATE POLICY "Anyone can view images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'mood_images');

-- 5.5 App Config 表 (应用配置，如版本更新)
CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "App config is viewable by everyone" ON app_config;
CREATE POLICY "App config is viewable by everyone"
    ON app_config FOR SELECT
    USING (true);

-- 插入默认版本信息
INSERT INTO app_config (key, value)
VALUES ('latest_version', '1.0.0'),
       ('update_url_android', ''),
       ('update_url_ios', ''),
       ('force_update', 'false')
ON CONFLICT (key) DO NOTHING;

-- 6.5 User Mood Status 表 (好友当前心情状态，持续同步)
CREATE TABLE IF NOT EXISTS user_mood_status (
    owner_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    mood_type TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE user_mood_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own mood status" ON user_mood_status;
CREATE POLICY "Users can insert their own mood status"
    ON user_mood_status FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can update their own mood status" ON user_mood_status;
CREATE POLICY "Users can update their own mood status"
    ON user_mood_status FOR UPDATE
    USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can delete their own mood status" ON user_mood_status;
CREATE POLICY "Users can delete their own mood status"
    ON user_mood_status FOR DELETE
    USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Friends can view mood status of users who share" ON user_mood_status;
CREATE POLICY "Friends can view mood status of users who share"
    ON user_mood_status FOR SELECT
    USING (
      owner_id IN (
        SELECT id FROM profiles WHERE show_mood_to_friends = true
      )
      AND (
        auth.uid() IN (
          SELECT requester_id FROM friends
          WHERE addressee_id = user_mood_status.owner_id AND status = 'accepted'
          UNION
          SELECT addressee_id FROM friends
          WHERE requester_id = user_mood_status.owner_id AND status = 'accepted'
        )
      )
    );

-- 7. Realtime 配置 (好友心情实时更新)
-- 必须执行以下 SQL，否则 Realtime 不会推送 remote_moods 变更事件

-- 7.1 将 remote_moods 表加入 supabase_realtime 发布
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'remote_moods'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE remote_moods;
  END IF;
END $$;

-- 7.2 设置 REPLICA IDENTITY FULL，确保 UPDATE/DELETE 事件包含完整旧数据
ALTER TABLE public.remote_moods REPLICA IDENTITY FULL;

-- 7.3 将 friend_messages 表加入 supabase_realtime 发布
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'friend_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE friend_messages;
  END IF;
END $$;

-- 7.4 设置 REPLICA IDENTITY FULL for friend_messages
ALTER TABLE public.friend_messages REPLICA IDENTITY FULL;

-- 7.5 将 friends 表加入 supabase_realtime 发布
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'friends'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE friends;
  END IF;
END $$;

-- 7.6 设置 REPLICA IDENTITY FULL for friends，确保 UPDATE/DELETE 事件包含完整数据
ALTER TABLE public.friends REPLICA IDENTITY FULL;

-- 7.7 将 user_mood_status 表加入 supabase_realtime 发布
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'user_mood_status'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE user_mood_status;
  END IF;
END $$;

-- 7.8 设置 REPLICA IDENTITY FULL for user_mood_status
ALTER TABLE public.user_mood_status REPLICA IDENTITY FULL;

-- ============================================
-- 8. Mood Meter (RULER framework) migration
-- ============================================

-- Add Mood Meter coordinate fields to remote_moods
ALTER TABLE remote_moods ADD COLUMN IF NOT EXISTS energy DOUBLE PRECISION;
ALTER TABLE remote_moods ADD COLUMN IF NOT EXISTS pleasantness DOUBLE PRECISION;
ALTER TABLE remote_moods ADD COLUMN IF NOT EXISTS emotion_word TEXT;
ALTER TABLE remote_moods ADD COLUMN IF NOT EXISTS quadrant TEXT;

-- Add Mood Meter coordinate fields to user_mood_status
ALTER TABLE user_mood_status ADD COLUMN IF NOT EXISTS energy DOUBLE PRECISION;
ALTER TABLE user_mood_status ADD COLUMN IF NOT EXISTS pleasantness DOUBLE PRECISION;
ALTER TABLE user_mood_status ADD COLUMN IF NOT EXISTS emotion_word TEXT;
ALTER TABLE user_mood_status ADD COLUMN IF NOT EXISTS quadrant TEXT;

-- Indexes for quadrant-based queries
CREATE INDEX IF NOT EXISTS idx_remote_moods_quadrant ON remote_moods(quadrant);
CREATE INDEX IF NOT EXISTS idx_remote_moods_energy_pleasantness ON remote_moods(energy, pleasantness);

-- ============================================
-- 9. Token Usage Logs (API token 用量统计)
-- ============================================
CREATE TABLE IF NOT EXISTS token_usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    model TEXT NOT NULL DEFAULT 'deepseek-chat',
    prompt_tokens INTEGER NOT NULL DEFAULT 0,
    completion_tokens INTEGER NOT NULL DEFAULT 0,
    total_tokens INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_token_usage_user_id ON token_usage_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_token_usage_user_month ON token_usage_logs(user_id, created_at);

ALTER TABLE token_usage_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own token usage" ON token_usage_logs;
CREATE POLICY "Users can insert their own token usage"
    ON token_usage_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view their own token usage" ON token_usage_logs;
CREATE POLICY "Users can view their own token usage"
    ON token_usage_logs FOR SELECT
    USING (auth.uid() = user_id);

-- 6. friend_code 自动生成触发器
CREATE OR REPLACE FUNCTION generate_friend_code()
RETURNS TRIGGER AS $$
BEGIN
    NEW.friend_code := UPPER(SUBSTRING(MD5(NEW.id::TEXT || NOW()::TEXT) FROM 1 FOR 6));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_friend_code ON profiles;
CREATE TRIGGER set_friend_code
    BEFORE INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION generate_friend_code();
