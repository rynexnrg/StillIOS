import SwiftUI
import UIKit
import UserNotifications

@main
struct StillApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let defaults = UserDefaults(suiteName: "group.com.johannes.still") ?? .standard
        switch response.actionIdentifier {
        case "STILL_RESUME": defaults.set("resumeTimer", forKey: "pendingCommand")
        case "STILL_CANCEL": defaults.set("cancelAll", forKey: "pendingCommand")
        default: break
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == "still.alarm.fired" {
            NotificationCenter.default.post(name: .stillAlarmFired, object: nil)
        }
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let stillAlarmFired = Notification.Name("StillAlarmFired")
}