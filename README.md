<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue?logo=apple" />
  <img src="https://img.shields.io/badge/SwiftUI-5.0-orange?logo=swift" />
  <img src="https://img.shields.io/badge/Supabase-Realtime-green?logo=supabase" />
  <img src="https://img.shields.io/badge/AI-DeepSeek-purple?logo=openai" />
</p>

<h1 align="center">💸 BillSplit</h1>
<p align="center"><i>Split bills, not friendships.</i></p>

---

## ✨ What it does

| | |
|---|---|
| 👥 **Groups** | Create groups, invite friends with a 6-digit code |
| 💰 **Bills** | 12 emoji categories — 🍽️ ☕ 🚗 🏠 🛍️ 🎮 ✈️ 🏥 📚 🎁 💡 💰 |
| 📸 **OCR Scan** | Snap a receipt → AI parses items → auto-generate bills |
| 🌍 **Localized** | English · 中文 — every label, toast, and error message |
| 🔐 **Auth** | Email sign up with verification + password strength meter |
| 💱 **Currency** | USD ↔ CNY with daily auto-refreshed exchange rate |
| 🔄 **Realtime** | WebSocket sync — changes appear instantly for everyone |
| 📊 **Analytics** | 12-week heatmap, category pie chart, spending breakdown |
| 💳 **Settlements** | Pay debts, revoke if mistaken, full history |

## 🛠 Stack

`SwiftUI` `Supabase Auth` `Postgres + RLS` `Supabase Storage` `Supabase Realtime` `Edge Functions` `DeepSeek LLM` `Vision OCR`

## 🚀 Quick Start

```bash
git clone git@github.com:BusyJzy599/BillSplit.git
open BillSplit/BillSplit.xcodeproj
```

Then run `supabase/migration.sql` in your Supabase SQL Editor.

---

<p align="center"><sub>Built with ☕ and late nights</sub></p>
