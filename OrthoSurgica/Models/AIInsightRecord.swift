//
//  AIInsightRecord.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/22/26.
//

import Foundation
import ParseSwift

/// Server-side cache record for AI Insight results.
/// Stored on Back4App in class `AIInsightRecord`.
struct AIInsightRecord: ParseObject {
    // ParseSwift requirements
    var originalData: Data?
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?

    // Class name in Parse Dashboard
    static var className: String {
        "AIInsightRecord"
    }

    // Custom fields (keep these names aligned with Cloud Code)
    var pmid: String
    var model: String
    var promptVersion: Int
    /// The full AIInsight payload as a JSON string.
    var insightJSON: String

    init() {
        self.pmid = ""
        self.model = ""
        self.promptVersion = 0
        self.insightJSON = ""
    }

    init(pmid: String, model: String, promptVersion: Int, insightJSON: String) {
        self.pmid = pmid
        self.model = model
        self.promptVersion = promptVersion
        self.insightJSON = insightJSON
    }
}
