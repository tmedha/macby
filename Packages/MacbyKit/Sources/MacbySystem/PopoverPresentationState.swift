import Foundation

/// Signals SwiftUI state inside the popover that needs to reset on every open,
/// not just the first — the panel/hosting view is created once and reused
/// (shown via orderFront/orderOut, not recreated), so `.onAppear` inside the
/// popover's content view only ever fires once for the process's lifetime.
/// `AppDelegate` bumps `showCount` from `PopoverPanelController.onWillShow`;
/// views observe it via `.onChange` to redo per-open setup (e.g. refocusing
/// the search field so arrow-key navigation works immediately).
@MainActor
public final class PopoverPresentationState: ObservableObject {
    @Published public private(set) var showCount = 0

    public init() {}

    public func notifyWillShow() {
        showCount += 1
    }
}
