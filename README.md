# BillSplit

Split bills with friends. Built with SwiftUI + Supabase.

## Features

- Create groups, invite friends via code
- Add bills with 12 emoji categories
- OCR receipt scanning (DeepSeek AI)
- USD/CNY with live exchange rate
- Real-time sync via Supabase Realtime
- Spending heatmap & category pie chart
- Settlements with revoke
- English / 中文

## Tech

SwiftUI, Supabase (Auth + DB + Storage + Realtime + Edge Functions), DeepSeek LLM

## Setup

```bash
# Clone & open in Xcode
open BillSplit.xcodeproj

# Apply DB migration
# Run supabase/migration.sql in Supabase SQL Editor
```
