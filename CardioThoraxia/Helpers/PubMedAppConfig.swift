//
//  PubMedAppConfig.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//
import Foundation

enum PubMedAppConfig {
    static var apiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "PUBMED_API_KEY") as? String
    }

    static var tool: String? {
        Bundle.main.object(forInfoDictionaryKey: "PUBMED_TOOL_NAME") as? String
    }

    static var email: String? {
        Bundle.main.object(forInfoDictionaryKey: "PUBMED_CONTACT_EMAIL") as? String
    }
}
