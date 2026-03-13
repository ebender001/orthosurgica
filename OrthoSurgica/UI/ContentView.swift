//
//  ContentView.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/28/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var meshManager: MeshCatalogManager
    @AppStorage("didShowNotificationPrePrompt") private var didShowNotificationPrePrompt = false
    @State private var showNotificationPrePrompt = false
    @State private var query = QueryDefinition.andGroup([])
    private let client = PubMedClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                QueryTermsView(query: $query, client: client)
            }
            .sheet(isPresented: $showNotificationPrePrompt) {
                NotificationPrePermissionView {
                    didShowNotificationPrePrompt = true
                    showNotificationPrePrompt = false
                }
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                if !didShowNotificationPrePrompt {
                    showNotificationPrePrompt = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
