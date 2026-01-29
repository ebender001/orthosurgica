//
//  ContentView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/28/26.
//

import SwiftUI

struct ContentView: View {
    
    @State private var query = QueryDefinition.andGroup([])
    private let client = PubMedClient()

    var body: some View {
        NavigationStack {
            QueryTermsView(query: $query, client: client)
        }
    }
}

#Preview {
    ContentView()
}
