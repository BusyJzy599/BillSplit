# OCR Receipt Scanning — Design Spec

Date: 2026-05-27

## Overview

账单组详情页 + 按钮增加「拍照识别」入口。用 Apple Vision OCR 识别收据，用户确认后自动生成账单（共享项合并为一笔，个人项各生成独立账单）。

## Tech

- **OCR Engine:** Apple Vision (`VNRecognizeTextRequest`) — iOS 内置，免费，离线，中文识别
- **Camera:** `UIImagePickerController` (拍照) / `PHPickerViewController` (选图)
- **Image Source:** 拍照或相册选图

## Data Flow

```
拍照/选图 → Vision OCR → 解析行项目 → 用户确认/编辑/标记 → 生成多笔账单
```

## Entry Point

AddBillView 入口改为弹出选择：

```
+ 按钮
  ├─ 「手动输入」→ 现有 AddBillView
  └─ 「拍照识别」→ ReceiptScanView
```

## OCR Parsing Rules

- Vision fast mode（速度快，中文够用）
- 每行包含数字/¥ 符号的行 → 候选消费项
- 金额取该行最后一段数字（支持 ¥、元、小数点）
- 描述取其余文字
- Minimum confidence: 0.3

## ReceiptConfirmationView

### 页面结构

```
┌──────────────────────────────┐
│ ← 返回    收据识别    确认    │
│                              │
│ 📷 收据缩略图（可选展示）     │
│                              │
│ 共享项目（均分给全组）        │
│ ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐│
│ ╎ [✓] 薯片       ¥12.50 ✎ ╎│  ← toggle: 共享/个人
│ ╎ [✓] 饮料        ¥8.00 ✎ ╎│  ← 点击文字或金额可编辑
│ ╎ [ ] 纸巾        ¥5.00 ✎ ╎│
│ └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘│
│                              │
│ 个人项目                      │
│ ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐│
│ ╎ 👤 张三       ¥35.00 ✎  ╎│  ← 每人一条独立账单
│ ╎ 👤 李四       ¥22.00 ✎  ╎│
│ └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘│
│                              │
│ [+ 添加项目]                  │
│                              │
│ 付款人: [选择]  ← 默认当前用户│
└──────────────────────────────┘
```

### 交互规则

- 每项有 toggle 开关：开=共享（均分），关=个人（该项生成单独账单，仅该人在 participant 里）
- 点击文字 → 编辑描述
- 点击金额 → 编辑金额
- [+ 添加项目] → 手动加一行（OCR 漏掉的行）
- 左滑删除项目

### 确认提交

点击「确认」后生成账单：

```
共享项（toggle ON）:
  → 合并金额，生成 1 笔 Bill
    - payerId: 拍照人
    - participantIds: 全组成员
    - amount: 所有共享项总金额
    - description: 各共享项描述用 "、" 拼接

个人项（toggle OFF）:
  → 每人生成 1 笔 Bill
    - payerId: 支付该项的人（用户从成员列表中选）
    - participantIds: [该项所属人]
    - amount: 该项金额
    - description: 该项描述
```

## New Files

```
BillSplit/Services/OCRService.swift           ← Vision OCR 引擎
BillSplit/Models/ReceiptItem.swift            ← OCR 解析结果模型
BillSplit/Views/ReceiptScanView.swift         ← 拍照/选图 + OCR 执行
BillSplit/Views/ReceiptConfirmationView.swift ← 结果确认编辑页
```

## Modified Files

```
BillSplit/Views/GroupDetailView.swift  ← + 按钮改为弹出选择（ActionSheet/Menu）
```

## Error Handling

| 场景 | 处理 |
|------|------|
| OCR 未识别到任何文字 | 提示「未识别到文字，请拍摄清晰的收据」+ 重拍 |
| 识别到文字但没有金额 | 正常展示列表，金额列空，用户手动填 |
| 相机/相册权限拒绝 | 系统弹窗，引导去设置开启 |
| 识别中退出页面 | 无副作用，下次重新拍 |

## NOT Included (MVP Scope)

- 自动商品分类（零食/日用品等）
- 多页收据
- 历史扫描记录
- 收据图片上传 Firestore（仅本地展示）
- 手写收据识别（中文字体够好，但不保证）
