//
//  DeviceToken.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/24/26.
//

import Foundation
import Security

enum DeviceToken {
    private static let service = "com.benderapps.orthosurgica"
    private static let account = "deviceToken"
    

    static func getOrCreate() -> String {
        if let existing = read() { return existing }
        let token = UUID().uuidString
        save(token)
        return token
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8)
        else { return nil }
        return str
    }

    private static func save(_ token: String) {
        let data = Data(token.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        let add: [String: Any] = query.merging([
            kSecValueData as String: data
        ]) { $1 }

        SecItemAdd(add as CFDictionary, nil)
    }
}
