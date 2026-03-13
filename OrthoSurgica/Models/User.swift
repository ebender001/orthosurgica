//
//  User.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/24/26.
//

import Foundation
import ParseSwift

struct User: ParseUser {
    var authData: [String : [String : String]?]?
    
    // Required by ParseSwift
    var originalData: Data?
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?

    // ParseUser-required fields
    var username: String?
    var email: String?
    var emailVerified: Bool?
    var password: String?

    // ParseUser-required fields (auth/session)
    var sessionToken: String?

    // Optional: store display name, etc.
    var name: String?

    init() {}
}
