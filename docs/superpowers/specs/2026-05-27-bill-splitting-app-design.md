# Bill Splitting App — Design Spec

Date: 2026-05-27

## Overview

复刻 Splitwire 核心功能：共享账单组，邀请码加入，Apple ID 登录，iOS 原生 SwiftUI。

## Architecture

```
GitHub Pages          Firebase              iOS App (SwiftUI)
────────────          ────────              ─────────────────
落地页                 Firestore (数据)      账单创建/查看
Universal Link        Firebase Auth         加入账单组
(/invite/ABC123)      (Apple ID 登录)        上传账单
                                             标记已还
```

- iOS App 通过 Firebase SDK 直连 Firestore，无中间层。
- GitHub Pages 只托管落地页和邀请链接跳转（Universal Link）。
- 不需要自己写后端 API。

## Data Model

```
users/{userId}
  - displayName: string
  - email: string (Apple ID email)
  - createdAt: timestamp

groups/{groupId}
  - name: string
  - inviteCode: string (6位大写字母数字)
  - creatorId: string
  - memberIds: [string]
  - createdAt: timestamp

bills/{billId}
  - groupId: string
  - payerId: string (上传者，默认自己付)
  - amount: number
  - description: string
  - participantIds: [string] (默认全组成员)
  - createdAt: timestamp

settlements/{settlementId}
  - billId: string
  - groupId: string
  - fromUserId: string
  - toUserId: string
  - amount: number
  - status: "pending" | "paid"
```

- 所有金额用 Firestore `number` 存储，单位元，保留两位小数。
- 欠款关系（谁欠谁多少）客户端根据 bills 计算得出，不单独存储。

## Pages

```
Tab 1: 我的账单组
  ├─ 账单组列表（毛玻璃卡片）
  └─ 点击进入 → 账单组详情
       ├─ 成员列表
       ├─ 账单列表
       ├─ 欠款总结（谁欠谁多少）
       ├─ + 新建账单
       └─ 管理（删除/退出账单组）

Tab 2: 加入账单组
  └─ 6位邀请码输入 → 校验 → 加入成功 → 跳转详情

Tab 3: 个人中心
  ├─ 用户 ID / 昵称
  └─ 退出登录
```

## Key Flows

**创建账单组:**
1. 用户点击「新建账单组」→ 输入名称 → 创建
2. 系统自动生成 6 位唯一邀请码
3. 创建者成为第一个成员
4. 跳转账单组详情

**加入账单组:**
1. 用户输入 6 位邀请码
2. 查询 Firestore 校验邀请码是否存在
3. 已加入 → 提示「你已在该账单组中」
4. 不存在 → 提示「未找到账单组」
5. 成功 → 加入 memberIds → 跳转详情

**上传账单:**
1. 用户在账单组详情点击 +
2. 输入金额、描述
3. 付款人默认当前用户，可修改
4. 参与人默认全组成员，可减选
5. 提交 → 写入 Firestore → 实时同步到其他成员

**标记已还:**
1. 用户在结算列表看到自己的待还项
2. 点击「标记已还」→ 收款方确认 → 状态变为 paid

## UI Design

### 设计语言
iOS 原生毛玻璃风格（Frosted Glass），系统自适应深浅色。

### 核心要素
- 卡片: `.background(.ultraThinMaterial)` + 圆角 + 柔和阴影
- 字体: SF Pro Display（标题）/ SF Pro Text（正文）
- 颜色: 系统自适应，强调色用系统默认 tint
- 触觉反馈: 按钮点击、滑动操作
- 所有卡片下方透出背景色，随滚动变化

### 卡片示例
```
┌──────────────────────────────┐
│ ⠁   我的账单组               │  ← 大标题
│                              │
│ ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐ │
│ ╎ 🏷 三亚旅游                ╎ │  ← .ultraThinMaterial
│ ╎                            ╎ │
│ ╎ 5人 · 12笔账单             ╎ │
│ ╎                            ╎ │
│ ╎ 👤 你欠小王 ¥128.50        ╎ │
│ ╎ ━━━━━━━━━━━━━━━━ 待结算    ╎ │
│ ╎                            ╎ │
│ ╎ 邀请码 ABC123   [📋]       ╎ │
│ └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘ │
│                              │
│ [+] 新建账单组               │
└──────────────────────────────┘
```

## Error Handling

| 场景 | 处理 |
|------|------|
| 邀请码不存在 | Toast 提示「未找到账单组，请检查邀请码」 |
| 重复加入 | Toast 提示「你已在该账单组中」 |
| 网络错误 | 系统原生错误提示 + 重试按钮 |
| 退出有欠款的账单组 | 阻止退出，提示「请先结清欠款」 |
| 删除账单组 | 仅创建者可删，二次确认 |

## What's NOT Included (MVP Scope)

- 邀请码过期机制
- 账单修改 / 删除历史
- 逐项自定义分摊比例（只有均分）
- 图片附件、备注
- 消息通知推送（Phase 2）
- Android 版本

## Tech Stack Detail

| 层 | 技术 |
|------|------|
| iOS App | SwiftUI + Swift 5.9+, iOS 17+ |
| 认证 | Firebase Auth (Apple Sign-In) |
| 数据库 | Cloud Firestore |
| 静态托管 | GitHub Pages |
| 依赖管理 | Swift Package Manager |
| 构建 | Xcode 15+ |

## Firestore Security Rules (概要)

```
- users: 本人可读写
- groups: 成员可读，创建者可写（含删除）
- bills: 同组成员可读，创建者可写
- settlements: 交易双方可读可写
```

## Test Distribution

需要 Apple Developer Program ($99/年) 才能:
- 真机调试
- TestFlight 分发测试
- 正式上架 App Store

免费方案: Xcode 模拟器开发 + 个人设备 7 天签名（需每周重签）
