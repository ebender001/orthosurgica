//
//  PushNotificationsDelegate.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/11/26.
//

import Foundation
import UIKit
import UserNotifications
import ParseSwift

extension Notification.Name {
    static let meshCatalogUpdated = Notification.Name("meshCatalogUpdated")
}

// Concrete Installation type for ParseSwift.
// ParseSwift's `ParseInstallation` is a protocol; you typically define your own concrete type.
struct Installation: ParseInstallation {
    // Required ParseObject fields
    var originalData: Data?
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?

    // ParseInstallation fields
    var installationId: String?
    var deviceType: String?
    var deviceToken: String?
    var badge: Int?
    var timeZone: String?
    var pushType: String?
    var channels: [String]?

    // Optional fields (keep if you want later)
    var appName: String?
    var appIdentifier: String?
    var appVersion: String?
    var parseVersion: String?
    var localeIdentifier: String?
}

final class PushNotificationsDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            do {
                guard var installation = Installation.current else {
                    throw NSError(domain: "PushNotifications", code: 1, userInfo: [NSLocalizedDescriptionKey: "No current Parse installation available"])
                }
                installation.setDeviceToken(deviceToken)
                installation.channels = ["meshCatalog"] // channels supported  [oai_citation:3‡The Swift Package Index](https://swiftpackageindex.com/netreconlab/Parse-Swift/6.0.5/documentation/parseswift/parseinstallation/channels?utm_source=chatgpt.com)
                _ = try await installation.save()
                #if DEBUG
                print("✅ Saved ParseInstallation with channel meshCatalog")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to save ParseInstallation:", error)
                #endif
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("❌ Failed to register for remote notifications:", error)
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // App is in the foreground. Trigger refresh immediately.
        let userInfo = notification.request.content.userInfo
        let handled = handleMeshCatalogPush(userInfo)

        // For catalog-update pushes, you may choose not to show a banner.
        // During testing you might prefer showing it; production can be quieter.
        return handled ? [] : [.banner, .sound]
    }

    // User tapped notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        handleMeshCatalogPush(userInfo)
    }

    // Silent/background delivery (if APNs delivers it that way)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let handled = handleMeshCatalogPush(userInfo)
        completionHandler(handled ? .newData : .noData)
    }

    @discardableResult
    private func handleMeshCatalogPush(_ userInfo: [AnyHashable: Any]) -> Bool {
        // We expect Cloud Code to send: type=meshCatalogUpdated, version=...
        let type = userInfo["type"] as? String
        guard type == "meshCatalogUpdated" else { return false }

        let version = userInfo["version"] as? String
        NotificationCenter.default.post(
            name: .meshCatalogUpdated,
            object: nil,
            userInfo: ["version": version as Any]
        )
        return true
    }
}
