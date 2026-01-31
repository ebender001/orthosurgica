//
//  CardioThoraxiaApp.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/28/26.
//

import SwiftUI
import SwiftData
import TipKit

@main
struct CardioThoraxiaApp: App {
    
    init() {
        try? Tips.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
