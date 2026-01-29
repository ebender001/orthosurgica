//
//  AppEnvironment.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

final class AppEnvironment {
    static let shared = AppEnvironment()

    let pubMedClient: PubMedClient

    private init() {
        let client = PubMedClient()
        Task {
            await client.updateConfig { cfg in
                cfg.apiKey = PubMedAppConfig.apiKey
                cfg.tool = PubMedAppConfig.tool
                cfg.email = PubMedAppConfig.email
            }
        }
        self.pubMedClient = client
    }
}
