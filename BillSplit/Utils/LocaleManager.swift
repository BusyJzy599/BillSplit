import SwiftUI

enum AppLocale: String, CaseIterable {
    case en
    case zh
}

class LocaleManager: ObservableObject {
    static let shared = LocaleManager()

    @AppStorage("appLocale") var appLocale: String = AppLocale.en.rawValue

    var locale: AppLocale { AppLocale(rawValue: appLocale) ?? .en }

    // MARK: - String helpers

    func txt(_ en: String, _ zh: String) -> String {
        locale == .zh ? zh : en
    }

    // MARK: - Tabs
    var tabHome: String { txt("Home", "首页") }
    var tabGroups: String { txt("Groups", "账单组") }
    var tabJoin: String { txt("Join", "加入") }
    var tabProfile: String { txt("Me", "我的") }

    // MARK: - Common
    var cancel: String { txt("Cancel", "取消") }
    var delete: String { txt("Delete", "删除") }
    var edit: String { txt("Edit", "编辑") }
    var save: String { txt("Save", "保存") }
    var done: String { txt("Done", "完成") }
    var confirm: String { txt("Confirm", "确认") }
    var loading: String { txt("Loading...", "加载中...") }

    // MARK: - Home
    var navHome: String { txt("Overview", "账单概览") }
    var totalSpent: String { txt("Total Spent", "总支出") }
    var billCount: String { txt("Bills", "账单数") }
    var groupCount: String { txt("Groups", "账单组") }
    var spendingHeatmap: String { txt("Spending Heatmap", "消费热力图") }
    var categoryBreakdown: String { txt("Spending Categories", "支出分类") }
    var categoryDetail: String { txt("Category Detail", "分类明细") }
    var less: String { txt("Less", "少") }
    var more: String { txt("More", "多") }
    var total: String { txt("Total", "总计") }
    var food: String { txt("Food", "餐饮") }
    var transport: String { txt("Transport", "交通") }
    var housing: String { txt("Housing", "住宿") }
    var shopping: String { txt("Shopping", "购物") }
    var entertainment: String { txt("Entertainment", "娱乐") }
    var other: String { txt("Other", "其他") }

    // MARK: - Groups
    var navGroups: String { txt("My Groups", "我的账单组") }
    var noGroups: String { txt("No groups yet", "还没有账单组") }
    var noGroupsHint: String { txt("Create a group and invite friends", "创建一个账单组，邀请朋友一起分摊") }
    var newGroup: String { txt("New Group", "新建账单组") }
    var groupName: String { txt("Group Name", "账单组名称") }
    var groupNamePlaceholder: String { txt("e.g. Trip Lunch", "例如: 旅行聚餐") }
    var create: String { txt("Create", "创建") }
    var members: String { txt("Members", "成员") }
    var creator: String { txt("Creator", "创建者") }
    var inviteCode: String { txt("Invite Code", "邀请码") }
    var copy: String { txt("Copy", "复制") }
    var toSettle: String { txt("To Settle", "待结算") }
    var billRecords: String { txt("Bills", "账单记录") }
    var noBills: String { txt("No bills yet", "还没有账单") }
    var noBillsHint: String { txt("Tap + to add a bill", "点击右上角 + 添加账单") }
    var payer: String { txt("Payer", "付款人") }
    var participants: String { txt("Participants", "参与人") }
    var pay: String { txt("Pay", "付款:") }
    var paid: String { txt("Paid", "已付") }
    var markPaid: String { txt("Mark Paid", "标记已还") }
    var deleteGroup: String { txt("Delete Group", "删除账单组") }
    var leaveGroup: String { txt("Leave Group", "退出账单组") }
    var cannotLeave: String { txt("Outstanding debts", "有未结清欠款") }
    var cannotLeaveMsg: String { txt("Please settle all debts before leaving", "请先结清所有欠款后再退出账单组") }
    var deleteBillTitle: String { txt("Delete Bill", "删除账单") }
    func deleteBillMsg(_ desc: String) -> String {
        locale == .zh ? "确定要删除「\(desc)」吗？该操作不可撤销。" : "Delete \"\(desc)\"? This cannot be undone."
    }
    var you: String { locale == .zh ? "你" : "You" }
    var currencyLabel: String { txt("Currency", "货币") }
    var displayCurrency: String { txt("Display Currency", "显示货币") }
    var languageLabel: String { txt("Language", "语言") }
    var signOut: String { txt("Sign Out", "退出登录") }

    // MARK: - Add Bill
    var newBill: String { txt("New Bill", "新建账单") }
    var editBill: String { txt("Edit Bill", "编辑账单") }
    var amount: String { txt("Amount", "金额") }
    var currencyType: String { txt("Currency", "币种") }
    var exchangeRateLabel: String { txt("Rate (→ CNY)", "汇率 (→ CNY)") }
    var description: String { txt("Description", "描述") }
    var descriptionPlaceholder: String { txt("e.g. Dinner", "例如: 晚餐") }
    var submitBill: String { txt("Submit Bill", "提交账单") }
    var updateBill: String { txt("Update Bill", "更新账单") }
    var manualInput: String { txt("Manual Input", "手动输入") }
    var scanReceipt: String { txt("Scan Receipt", "拍照识别") }
    var sectionPayer: String { txt("Payer", "付款人") }
    var sectionParticipants: String { txt("Participants", "参与人") }
    var sectionCurrency: String { txt("Currency", "币种") }
    var storedAsCNY: String { txt("Stored as CNY", "以人民币存储") }

    // MARK: - Join
    var navJoin: String { txt("Join Group", "加入账单组") }
    var enterInviteCode: String { txt("Enter invite code to join", "输入邀请码加入账单组") }
    var inviteCodePlaceholder: String { txt("6-digit code", "6位邀请码") }
    var joinButton: String { txt("Join Group", "加入账单组") }
    var alreadyInGroup: String { txt("Already in this group", "你已在该账单组中") }
    var groupNotFound: String { txt("Group not found", "未找到账单组") }

    // MARK: - Profile
    var navProfile: String { txt("Profile", "个人中心") }
    var editProfile: String { txt("Edit Profile", "编辑资料") }
    var editProfileTitle: String { txt("Edit Profile", "编辑资料") }
    var displayNameLabel: String { txt("Display Name", "显示名称") }
    var avatarLabel: String { txt("Avatar", "头像") }
    var choosePhoto: String { txt("Choose Photo", "选择照片") }
    var summary: String { txt("Summary", "概览") }
    var user: String { txt("User", "用户") }
    var nameLabel: String { txt("Name", "名字") }
    var saveProfile: String { txt("Save", "保存") }
    var addBill: String { txt("Add Bill", "添加账单") }
    var settled: String { txt("Settled", "已结算") }
    var whoOwesWho: String { txt("Who Owes Who", "欠款明细") }
    func showAll(_ count: Int) -> String {
        locale == .zh ? "显示全部 (\(count))" : "Show all (\(count))"
    }
    var showLess: String { txt("Show less", "收起") }
    var allSettled: String { txt("All settled!", "全部结清!") }
    var youReceive: String { txt("You receive", "应收") }
    var youOwe: String { txt("You owe", "应付") }
    var settledStatus: String { txt("Settled", "已结清") }
    var toastPaid: String { txt("Paid! 🎉", "已还款! 🎉") }
    var toastCopied: String { txt("Copied! 📋", "已复制! 📋") }
    var toastSettlementRevoked: String { txt("Settlement revoked ↩️", "已撤销结算 ↩️") }
    var toastDeleted: String { txt("Deleted 🗑️", "已删除 🗑️") }
    var manual: String { txt("Manual", "手动") }
    var scan: String { txt("Scan", "扫描") }
    var copyCode: String { txt("Copy Code", "复制邀请码") }
    var youPaid: String { txt("You paid", "你支付") }
    var yourShare: String { txt("Your share:", "分摊:") }
    func yourShareAmount(_ amount: String) -> String {
        locale == .zh ? "· 分摊: \(amount)" : "· Your share: \(amount)"
    }

    // MARK: - Receipt
    var receiptScan: String { txt("Receipt Scan", "收据识别") }
    var takePhoto: String { txt("Take Photo", "拍照") }
    var fromAlbum: String { txt("From Album", "相册") }
    var scanning: String { txt("Scanning...", "识别中...") }
    var scanFailed: String { txt("Scan failed", "识别失败") }
    var noTextFound: String { txt("No text found", "未识别到文字") }
    var sharedItems: String { txt("Shared Items", "共享项目") }
    var personalItems: String { txt("Personal Items", "个人项目") }
    var addItem: String { txt("Add Item", "添加项目") }
    var noSharedItems: String { txt("No shared items", "无共享项目") }
    var noPersonalItems: String { txt("No personal items", "无个人项目") }
    var unnamed: String { txt("Unnamed", "未命名") }
    var generateBills: String { txt("Generate Bills", "确认生成账单") }
    var codeGenFailed: String { txt("Code generation failed", "邀请码生成失败，请重试") }
    var imageCompressFailed: String { txt("Image compress failed", "图片压缩失败") }
    var takeReceiptPhoto: String { txt("Take a photo of your receipt", "拍摄收据照片") }
    var camera: String { txt("Camera", "拍照") }
    var album: String { txt("Album", "相册") }
    var aiAnalyzing: String { txt("AI analyzing receipt...", "AI 识别中...") }
    var itemsLabel: String { txt("Items", "项目") }
    var receiptInfo: String { txt("Receipt in", "收据币种") }
    func receiptInfoFull(_ currency: String, _ count: Int) -> String {
        locale == .zh ? "收据币种 \(currency) · \(count)人" : "Receipt in \(currency) · \(count) people"
    }
    func selectedLabel(_ selected: Int, _ total: Int) -> String {
        locale == .zh ? "已选 \(selected)/\(total)" : "\(selected)/\(total) selected"
    }
    var perPerson: String { txt("/ person", "/人") }
    var paidBy: String { txt("Paid by", "付款人") }
    var creatingBills: String { txt("Creating bills...", "生成账单中...") }
    func generateBillsBtn(_ count: Int, _ total: String) -> String {
        locale == .zh ? "生成 \(count) 笔账单 (\(total))" : "Generate \(count) Bills (\(total))"
    }
    var rescan: String { txt("Rescan", "重新扫描") }
    var editItem: String { txt("Edit Item", "编辑项目") }
    var itemName: String { txt("Name", "名称") }
    var itemAmount: String { txt("Amount", "金额") }
    var confirmItems: String { txt("Confirm Items", "确认项目") }
    var scanReceiptTitle: String { txt("Scan Receipt", "扫描收据") }

    // MARK: - Home
    var noDataYet: String { txt("No data yet", "暂无数据") }
    var noDataHint: String { txt("Add bills to see your spending analysis", "添加账单以查看消费分析") }

    // MARK: - Login
    var appTagline: String { txt("Split bills with friends", "和朋友轻松分账") }
    var email: String { txt("Email", "邮箱") }
    var emailPlaceholder: String { txt("you@example.com", "you@example.com") }
    var password: String { txt("Password", "密码") }
    var passwordPlaceholder: String { txt("Min 6 characters", "至少6个字符") }
    var nameField: String { txt("Name", "名字") }
    var namePlaceholder: String { txt("Your name", "你的名字") }
    var signIn: String { txt("Sign In", "登录") }
    var signUp: String { txt("Sign Up", "注册") }
    var toggleSignIn: String { txt("Already have an account? Sign In", "已有账号？登录") }
    var toggleSignUp: String { txt("Don't have an account? Sign Up", "没有账号？注册") }
    var testAccount1: String { txt("Test 1", "测试 1") }
    var testAccount2: String { txt("Test 2", "测试 2") }
    var emailConfirmRequired: String { txt("Email confirmation required. Disable it in Supabase Auth settings.", "需要邮箱验证，请在Supabase Auth设置中关闭。") }

    // MARK: - Profile / Settings
    var exchangeRate: String { txt("Exchange Rate", "汇率") }
    var updated: String { txt("Updated", "更新于") }

    // MARK: - Errors
    func localizedError(_ string: String) -> String { string }
}

extension View {
    func loc() -> LocaleManager { LocaleManager.shared }
}
