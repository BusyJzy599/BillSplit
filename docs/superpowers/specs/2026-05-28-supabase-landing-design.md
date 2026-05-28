# BillSplit Supabase 落地设计

## 目标

本地跑通 → TestFlight 上线。核心：填入真实 Supabase 凭证 + 实时账单同步 + 用户头像。

## 前提

- Supabase 项目 `prmjucdsuejtdxxyucxo` 已配置
- 数据库迁移已执行（users, groups, bills, settlements + RLS + Realtime）
- Storage bucket `avatars` 需手动创建（一次性）
- Apple Sign In 已实现，依赖 Supabase Auth

## 改动清单

### 1. 配置层

**BillSplitApp.swift** — 填入真实凭证
- `supabaseURL`: `https://prmjucdsuejtdxxyucxo.supabase.co`
- `supabaseKey`: anon key（已获取）

### 2. 数据层

**Model `AppUser`** — 加 `avatarUrl` 字段
- 可选 `String?`，映射 `avatar_url` → `avatarUrl`

**Migration SQL 已更新** — `users` 表已含 `avatar_url TEXT`

### 3. 存储层

**新增 `StorageService`**
- `uploadAvatar(userId: String, imageData: Data) async throws -> String` — 上传到 `avatars/` bucket，返回 public URL
- 上传前本地压缩（JPEG quality 0.7, max 512px）
- `getPublicURL(path: String) -> String`

**Storage bucket 配置（手动一次）**
- bucket: `avatars`（public）
- RLS: authenticated 可读，owner 可写

### 4. 实时层

**新增 `RealtimeService`**
- `subscribeBills(groupId: Int, onChange: @escaping () -> Void)` — 监听 bills 表变更
- `subscribeSettlements(groupId: Int, onChange: @escaping () -> Void)` — 监听 settlements 表变更
- 使用 Supabase Swift 的 `channel().on(.postgresChange, ...)` API
- 返回 channel handle，支持 `unsubscribe()`

**`GroupDetailViewModel` 改动**
- `onAppear` 时订阅 realtime channels
- 收到变更 → 重新加载数据 + 重新计算债务
- 离开页面时取消订阅

### 5. UI 层

**`ProfileView` 改动**
- 显示头像（圆形，点击可换）
- 集成 PhotosPicker 选图
- 显示用户 displayName（从 `users` 表取）
- 上传后更新 `avatar_url`

**`EditProfileView`（新增）**
- 编辑 displayName
- PhotosPicker 换头像
- 本地压缩 → StorageService.upload → 更新 users 表

**全局头像组件**
- 在所有显示用户名的位置（成员列表、账单列表、结算行）显示头像
- 优先显示 `avatar_url`，fallback 到 SF Symbol `person.circle.fill`

### 6. 环境

**Supabase Swift 客户端**
- 不需要额外依赖，`BillSplitApp.swift` 已 `import Supabase`
- `supabase` 实例已全局可用

**Info.plist**
- 已配置 Sign In with Apple capability
- PhotosPicker 不需要额外权限

## 数据流

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  PhotosPicker │────▶│ StorageService│────▶│  users 表    │
│  (选图)       │     │ (压缩+上传)   │     │  avatar_url  │
└──────────────┘     └──────────────┘     └──────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  AddBillView │────▶│  BillService │────▶│  bills 表     │
│  (新增账单)   │     │  (insert)    │     │              │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │ Realtime
┌──────────────┐     ┌──────────────┐              │
│ DetailView   │◀────│RealtimeService│◀─────────────┘
│  (UI 更新)   │     │  (监听变更)   │
└──────────────┘     └──────────────┘
```

## 文件变更

| 操作 | 文件 |
|------|------|
| 改 | `BillSplitApp.swift` — 凭证 |
| 改 | `Models/User.swift` — avatarUrl |
| 改 | `upabase/migration.sql` — avatar_url |
| 新 | `Services/StorageService.swift` |
| 新 | `Services/RealtimeService.swift` |
| 改 | `ViewModels/GroupDetailViewModel.swift` — 实时监听 |
| 改 | `Views/ProfileView.swift` — 头像 + 编辑 |
| 新 | `Views/EditProfileView.swift` |
| 新 | `Views/Components/AvatarView.swift` |
| 改 | `Views/GroupDetailView.swift` — 头像显示 |
| 改 | `Views/GroupListView.swift` — 头像显示 |
| 改 | `Views/Components/SettlementRow.swift` — 头像显示 |

## Storage bucket 创建

在 Supabase Dashboard → Storage → New bucket:
- Name: `avatars`
- Public: yes
- 或者 SQL: `INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);`

RLS policies（Storage）:
```sql
-- 所有人可读
CREATE POLICY "Avatars are publicly viewable" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

-- 认证用户可上传
CREATE POLICY "Users can upload their avatar" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

-- 用户可更新/删除自己的头像
CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete own avatar" ON storage.objects
  FOR DELETE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
```

## 测试清单

- [ ] Apple Sign In 正常登录
- [ ] 创建/加入账单组
- [ ] 添加账单后，同组其他设备实时看到
- [ ] 标记结算后实时更新
- [ ] 头像上传/更换
- [ ] 头像在各页面正确显示
- [ ] 退出登录 → 重新登录数据还在
