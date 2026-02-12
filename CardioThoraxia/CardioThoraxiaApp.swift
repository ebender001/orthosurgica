//
//  CardioThoraxiaApp.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/28/26.
//

import SwiftUI
import SwiftData
import TipKit
import ParseSwift

@main
struct CardioThoraxiaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var meshManager = MeshCatalogManager()
    @UIApplicationDelegateAdaptor(PushNotificationsDelegate.self) private var pushDelegate
    
    init() {
        try? Tips.configure()
        
        func plist(_ key: String) -> String {
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
                  !value.isEmpty,
                  !value.hasPrefix("$(") else {
                fatalError("Missing info.plist value for \(key). Check Secrets.xcconfig + Info.plist mapping")
            }
            return value
        }
        
        let appId = plist("PARSE_APP_ID")
        let clientKey = plist("PARSE_CLIENT_KEY")
        let serverURL = URL(string: plist("PARSE_SERVER_URL"))!
        
        #if DEBUG
        print("PARSE_SERVER_URL =", plist("PARSE_SERVER_URL"))
        #endif
        
        ParseSwift.initialize(
            applicationId: appId,
            clientKey: clientKey,
            serverURL: serverURL
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(meshManager)
                .task { await meshManager.loadRemote() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await meshManager.loadRemote() }
                    }
                }
        }
        .modelContainer(for: [FeedRecord.self, ArticleRecord.self])
    }
}

// MARK: - Tips

struct AddFirstTopicTip: Tip {
    var title: Text {
        Text("Start with a topic")
    }

    var message: Text? {
        Text("Tap Add First Topic to choose a specialty area. You can add more topics later.")
    }

    var image: Image? {
        Image(systemName: "plus.circle")
    }
}

struct AddAdvancedSearchTip: Tip {
    var title: Text {
        Text("Refine your search")
    }

    var message: Text? {
        Text(
            "You can refine results by adding another topic, or use Advanced Search if you’re comfortable editing the PubMed query directly."
        )
    }

    var image: Image? {
        Image(systemName: "slider.horizontal.3")
    }
}

struct SuggestTopicTip: Tip {
    var title: Text {
        Text("Suggest a new topic")
    }

    var message: Text? {
        Text("Can’t find what you’re looking for? Tap the lightbulb to suggest a new term or topic group for the catalog.")
    }

    var image: Image? {
        Image(systemName: "lightbulb")
    }
}
