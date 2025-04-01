// MARK: - KeychainHelper.swift
import Foundation

class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    func save(key: String, value: String) {
        // Get the existing data if any
        if let existingItem = getKeychainQuery(key: key) {
            let attributesToUpdate: [CFString: Any] = [
                kSecValueData: value.data(using: .utf8)!
            ]
            
            // Update the keychain item
            SecItemUpdate(existingItem as CFDictionary, attributesToUpdate as CFDictionary)
        } else {
            // Create a new keychain item
            let keychainQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
                kSecValueData: value.data(using: .utf8)!,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
            ]
            
            SecItemAdd(keychainQuery as CFDictionary, nil)
        }
    }
    
    func get(key: String) -> String? {
        var keychainQuery = getKeychainQuery(key: key)
        keychainQuery?[kSecReturnData] = kCFBooleanTrue
        keychainQuery?[kSecMatchLimit] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQuery! as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    func delete(key: String) {
        if let keychainQuery = getKeychainQuery(key: key) {
            SecItemDelete(keychainQuery as CFDictionary)
        }
    }
    
    private func getKeychainQuery(key: String) -> [CFString: Any]? {
        let keychainQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &result)
        
        return status == errSecSuccess || status == errSecDuplicateItem ? keychainQuery : nil
    }
}

