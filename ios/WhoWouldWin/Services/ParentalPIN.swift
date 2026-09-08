import Foundation
import CryptoKit
import Security

/// Parent-controlled PIN gate. The PIN is kept in the device-only Keychain and
/// guesses are throttled. Older UserDefaults hashes are migrated after the
/// parent next enters the correct PIN.
enum ParentalPIN {
    private static let legacyHashKey = "parental.pinHash"
    private static let failedAttemptsKey = "parental.pinFailedAttempts"
    private static let lockedUntilKey = "parental.pinLockedUntil"
    private static let service = "com.whowouldin.WhoWouldWin.parental-pin"
    private static let account = "parent"
    private static let ud = UserDefaults.standard

    static var isPINSet: Bool {
        readPIN() != nil || !(ud.string(forKey: legacyHashKey) ?? "").isEmpty
    }

    static func setPIN(_ pin: String) {
        guard pin.range(of: #"^\d{4}$"#, options: .regularExpression) != nil else { return }
        writePIN(pin)
        ud.removeObject(forKey: legacyHashKey)
        resetFailures()
    }

    static func verify(_ pin: String) -> Bool {
        guard Date().timeIntervalSince1970 >= ud.double(forKey: lockedUntilKey) else { return false }

        if let stored = readPIN(), constantTimeEqual(stored, pin) {
            resetFailures()
            return true
        }

        // One-way migration path for users who set a PIN in an older build.
        if let legacy = ud.string(forKey: legacyHashKey), !legacy.isEmpty,
           constantTimeEqual(legacy, hash(pin)) {
            writePIN(pin)
            ud.removeObject(forKey: legacyHashKey)
            resetFailures()
            return true
        }

        recordFailure()
        return false
    }

    static func clear() {
        SecItemDelete(keychainQuery() as CFDictionary)
        ud.removeObject(forKey: legacyHashKey)
        resetFailures()
    }

    private static func hash(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func readPIN() -> String? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writePIN(_ pin: String) {
        let query = keychainQuery()
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(pin.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func recordFailure() {
        let attempts = ud.integer(forKey: failedAttemptsKey) + 1
        ud.set(attempts, forKey: failedAttemptsKey)
        guard attempts >= 5 else { return }
        let delay = min(3_600.0, 30.0 * pow(2.0, Double(attempts - 5)))
        ud.set(Date().addingTimeInterval(delay).timeIntervalSince1970, forKey: lockedUntilKey)
    }

    private static func resetFailures() {
        ud.removeObject(forKey: failedAttemptsKey)
        ud.removeObject(forKey: lockedUntilKey)
    }

    private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let a = [UInt8](lhs.utf8)
        let b = [UInt8](rhs.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices { difference |= a[index] ^ b[index] }
        return difference == 0
    }
}
