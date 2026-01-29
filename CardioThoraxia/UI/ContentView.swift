//
//  ContentView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/28/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            #if DEBUG
            Button("Test Network Only (Mitral)") {
                runMitralValveRepairESearch()
            }

            Button("Test SwiftData Refresh (Mitral)") {
                refreshMitralFeed(context: modelContext)
            }
            #endif
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
