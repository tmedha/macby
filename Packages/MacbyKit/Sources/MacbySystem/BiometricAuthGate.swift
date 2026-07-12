import Foundation
import LocalAuthentication

/// Gates pasting a sensitive (credit card / SSN) item selected from Macby's
/// own popover behind Touch ID — or the user's login password if biometrics
/// aren't available/enrolled, via `.deviceOwnerAuthentication`'s automatic
/// fallback. Deliberately scoped to Macby-initiated pastes only: macOS has no
/// way to intercept a raw system-wide Cmd+V for content copied outside Macby.
@MainActor
public final class BiometricAuthGate {
    public init() {}

    public func authorize(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics and no device password set up at all — fail closed
            // rather than silently letting a sensitive paste through unguarded.
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
