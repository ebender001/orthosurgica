//
//  TopicSuggestion.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/12/26.
//

import Foundation
import ParseSwift

struct TopicSuggestion: ParseObject {
    // Required ParseObject fields
    var originalData: Data?
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?

    // Your fields
    var suggestedTerm: String?
    var suggestionType: String?
    var categoryPath: String?
    var notes: String?
    var appVersion: String?

}
