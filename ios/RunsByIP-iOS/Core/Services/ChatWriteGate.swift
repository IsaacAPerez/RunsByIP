import Foundation
import Security
@preconcurrency import Supabase

// MARK: - Keychain

private enum ChatWriteKeychain {
    static let service = "com.isaacperez.runsbyip.chatwrite"
    static let account = "unlocked"
    private static let unlockedMarker = Data([0x01])

    static func readUnlocked() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return false }
        return data.constantTimeEquals(unlockedMarker)
    }

    static func writeUnlocked(_ value: Bool) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard value else { return }
        var add = query
        add[kSecValueData as String] = unlockedMarker
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

private extension Data {
    func constantTimeEquals(_ other: Data) -> Bool {
        guard count == other.count else { return false }
        var diff: UInt8 = 0
        for i in indices {
            diff |= self[i] ^ other[i]
        }
        return diff == 0
    }
}

// MARK: - Gate (send, typing, reactions)

private struct VerifyChatWriteGateParams: Encodable {
    let p_attempt: String
}

@MainActor
final class ChatWriteGate: ObservableObject {
    @Published private(set) var isUnlocked: Bool

    @Published private(set) var failedAttempts: Int = 0
    @Published private(set) var lockoutRemainingSeconds: Int = 0
    @Published private(set) var lastVerificationError: String?

    private var lockoutUntil: Date?
    private var lockoutTickTask: Task<Void, Never>?

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private static let maxAttemptsBeforeLockout = 8
    private static let lockoutDurationSeconds = 60

    init() {
        if ChatWriteGateConfig.isEnabled {
            isUnlocked = ChatWriteKeychain.readUnlocked()
        } else {
            isUnlocked = true
        }
    }

    var isInLockout: Bool {
        guard let until = lockoutUntil else { return false }
        return Date() < until
    }

    /// Verifies the passphrase with Supabase (`verify_chat_write_gate` RPC). Returns `true` if accepted.
    func submitPassphrase(_ raw: String) async -> Bool {
        lastVerificationError = nil
        guard ChatWriteGateConfig.isEnabled else { return true }

        if isInLockout {
            return false
        }

        let attempt = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !attempt.isEmpty else { return false }

        do {
            let ok: Bool = try await supabase
                .rpc("verify_chat_write_gate", params: VerifyChatWriteGateParams(p_attempt: attempt))
                .execute()
                .value

            if !ok {
                registerFailedAttempt()
                return false
            }

            failedAttempts = 0
            lockoutUntil = nil
            lockoutRemainingSeconds = 0
            ChatWriteKeychain.writeUnlocked(true)
            isUnlocked = true
            return true
        } catch {
            lastVerificationError = error.localizedDescription
            return false
        }
    }

    /// Clears unlock on this device; user must re-enter the passphrase to send, type, or react.
    func lock() {
        ChatWriteKeychain.writeUnlocked(false)
        isUnlocked = false
    }

    private func registerFailedAttempt() {
        failedAttempts += 1
        if failedAttempts >= Self.maxAttemptsBeforeLockout {
            lockoutUntil = Date().addingTimeInterval(TimeInterval(Self.lockoutDurationSeconds))
            failedAttempts = 0
            startLockoutCountdown()
        }
    }

    private func startLockoutCountdown() {
        lockoutTickTask?.cancel()
        lockoutTickTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let until = lockoutUntil else { break }
                let left = max(0, Int(ceil(until.timeIntervalSinceNow)))
                lockoutRemainingSeconds = left
                if left <= 0 {
                    lockoutUntil = nil
                    lockoutRemainingSeconds = 0
                    break
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
