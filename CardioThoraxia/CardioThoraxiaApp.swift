//
//  CardioThoraxiaApp.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/28/26.
//

import SwiftUI
import SwiftData

@main
struct CardioThoraxiaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [FeedRecord.self, ArticleRecord.self])
    }
}
