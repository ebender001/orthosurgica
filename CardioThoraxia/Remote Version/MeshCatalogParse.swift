//
//  MeshCatalogParse.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/11/26.
//

import Foundation
import ParseSwift

/// Back4App class: MeshCatalog
struct MeshCatalogParse: ParseObject {

    static var className: String { "MeshCatalog" }

    // Required ParseObject fields
    var originalData: Data?
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?

    // Columns in Back4App
    var version: String?
    var schemaVersion: Int?
    var isActive: Bool?
    var changelog: String?
    var json: ParseFile?   // File column
}
