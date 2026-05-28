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
    var displayNameLabel: String { txt("Display Name", "显示名称") }
    var avatarLabel: String { txt("Avatar", "头像") }
    var choosePhoto: String { txt("Choose Photo", "选择照片") }
    var user: String { txt("User", "用户") }

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

    // MARK: - Errors
    func localizedError(_ string: String) -> String { string }
}

extension View {
    func loc() -> LocaleManager { LocaleManager.shared }
}
