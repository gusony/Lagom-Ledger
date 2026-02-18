//
//  AccountingApp.swift
//  Lagom Ledger
//

import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct AccountingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(LotteryAppState.shared)
                .onAppear {
                    Task { @MainActor in
                        await appDelegate.checkLotteryOnLaunch()
                    }
                }
        }
    }
}

/// 對獎結果狀態（供 UI 顯示）
@MainActor
class LotteryAppState: ObservableObject {
    static let shared = LotteryAppState()
    @Published var pendingLotteryAlert: LotteryResultSummary?
    
    private init() {}
}

// MARK: - App Delegate（對獎、背景、通知）
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        registerBackgroundTasks()
        requestNotificationPermission()
        scheduleLotteryRefresh()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.lagom.ledger.lottery", using: nil) { task in
            self.handleLotteryRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    func scheduleLotteryRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.lagom.ledger.lottery")
        request.earliestBeginDate = nextLotteryDate()
        do {
            try BGTaskScheduler.shared.submit(request)
            print("已排程對獎背景任務")
        } catch {
            print("排程失敗: \(error)")
        }
    }
    
    private func nextLotteryDate() -> Date {
        let cal = Calendar.current
        var comp = DateComponents()
        comp.hour = 14
        comp.minute = 0
        let oddMonths = [1, 3, 5, 7, 9, 11]
        let now = Date()
        let month = cal.component(.month, from: now)
        let day = cal.component(.day, from: now)
        
        for m in oddMonths {
            if month < m || (month == m && day < 25) {
                comp.year = cal.component(.year, from: now)
                comp.month = m
                comp.day = 25
                return cal.date(from: comp) ?? now
            }
        }
        comp.year = cal.component(.year, from: now) + 1
        comp.month = 1
        comp.day = 25
        return cal.date(from: comp) ?? now
    }
    
    private func handleLotteryRefresh(task: BGAppRefreshTask) {
        scheduleLotteryRefresh()
        Task { @MainActor in
            if let summary = await runLotteryCheck(), !summary.wins.isEmpty {
                notifyLotteryWins(summary)
            }
            task.setTaskCompleted(success: true)
        }
    }
    
    func checkLotteryOnLaunch() async {
        guard LotteryChecker.shared.needsCheckOnLaunch() else { return }
        if let summary = await runLotteryCheck() {
            LotteryChecker.shared.markChecked()
            if !summary.wins.isEmpty {
                await MainActor.run {
                    LotteryAppState.shared.pendingLotteryAlert = summary
                }
            }
        }
    }
    
    private func runLotteryCheck() async -> LotteryResultSummary? {
        await LotteryChecker.shared.runCheck(transactions: TransactionStore.shared.transactions)
    }
    
    private func notifyLotteryWins(_ summary: LotteryResultSummary) {
        let content = UNMutableNotificationContent()
        content.title = "發票中獎了！"
        content.body = "共 \(summary.wins.count) 張中獎，總計 $\(summary.totalAmount)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
