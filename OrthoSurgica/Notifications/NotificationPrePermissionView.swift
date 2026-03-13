//
//  NotificationPrePermissionView.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/12/26.
//

import SwiftUI
import UserNotifications
import UIKit

struct NotificationPrePermissionView: View {
    /// Called after the user completes the flow (allowed/denied/skip).
    var onDone: (() -> Void)? = nil

    @State private var isRequesting = false
    @State private var status: UNAuthorizationStatus? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 12)

                Image(systemName: "bell.badge")
                    .font(.system(size: 44))
                    .symbolRenderingMode(.hierarchical)
                    .padding(.bottom, 6)

                Text("Stay current with updates")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Enable notifications to be alerted when the topic catalog is updated, so your topic list stays current.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Catalog updates only (no marketing)", systemImage: "checkmark.seal")
                    Label("You can turn this off anytime in Settings", systemImage: "gearshape")
                    if let s = status {
                        statusRow(for: s)
                            .padding(.top, 6)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        Task { await requestNotifications() }
                    } label: {
                        HStack {
                            Spacer()
                            if isRequesting {
                                ProgressView()
                                    .padding(.trailing, 6)
                            }
                            Text("Enable notifications")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequesting)

                    Button {
                        onDone?()
                    } label: {
                        Text("Not now")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)
            }
            .padding()
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshStatus()
            }
        }
    }

    // MARK: - Helpers

    private func statusRow(for s: UNAuthorizationStatus) -> some View {
        HStack(spacing: 10) {
            switch s {
            case .authorized, .provisional, .ephemeral:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Notifications are enabled.")
                    .foregroundStyle(.secondary)

            case .denied:
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                Text("Notifications are off. You can enable them in Settings.")
                    .foregroundStyle(.secondary)

            case .notDetermined:
                Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                Text("Not enabled yet.")
                    .foregroundStyle(.secondary)

            @unknown default:
                Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                Text("Unknown notification status.")
                    .foregroundStyle(.secondary)
            }

            if s == .denied {
                Button("Open Settings") {
                    openAppSettings()
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.subheadline)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func refreshStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            status = settings.authorizationStatus
        }
    }

    private func requestNotifications() async {
        isRequesting = true
        errorMessage = nil
        defer { isRequesting = false }

        let center = UNUserNotificationCenter.current()

        // If already denied, send them to Settings rather than showing system prompt (which won't reappear)
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .denied {
            await MainActor.run { status = .denied }
            openAppSettings()
            return
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()

            if granted {
                // Register with APNs (this triggers didRegisterForRemoteNotificationsWithDeviceToken)
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                onDone?()
            } else {
                // user tapped "Don't Allow"
                await MainActor.run {
                    errorMessage = "You can enable notifications later in Settings."
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Notification permission request failed: \(error.localizedDescription)"
            }
        }
    }
}
