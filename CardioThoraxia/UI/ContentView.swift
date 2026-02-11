//
//  ContentView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/28/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var meshManager: MeshCatalogManager
    @State private var query = QueryDefinition.andGroup([])
    private let client = PubMedClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                QueryTermsView(query: $query, client: client)
            }
        }
    }
}

#Preview {
    ContentView()
}
