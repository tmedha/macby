import AppKit
import Combine
import MacbyCore
import MacbyPersistence
import MacbySystem
import MacbyUI
import GRDB

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popoverController: PopoverPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: SettingsWindowController?

    private var dbQueue: DatabaseQueue!
    private var historyStore: HistoryStore!
    private var blobStore: BlobStore!
    private var settingsStore: SettingsStore!
    private var pasteboardMonitor: PasteboardMonitor!
    private var pasteSimulator: PasteSimulator!
    private var permissionsManager: PermissionsManager!
    private var historyViewModel: HistoryViewModel!
    private var settingsCancellable: AnyCancellable?

    private var bookmarkStore: SecurityScopedBookmarkStore!
    private var fileSaveRouter: FileSaveRouter!
    private var hotkeyManager: HotkeyManager!
    private var snipCaptureService: SnipCaptureService!
    private var otpAutoClearService: OTPAutoClearService!
    private var biometricAuthGate: BiometricAuthGate!
    private var popoverHotkeyToken: HotkeyManager.Token?
    private var snipHotkeyToken: HotkeyManager.Token?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            dbQueue = try Database.makeQueue(at: Database.defaultStoreURL)
        } catch {
            fatalError("Macby: failed to open database: \(error)")
        }

        blobStore = BlobStore()
        settingsStore = SettingsStore()
        historyStore = HistoryStore(dbQueue: dbQueue, maxHistoryItemCount: settingsStore.settings.maxHistoryItemCount)
        pasteboardMonitor = PasteboardMonitor(historyStore: historyStore, blobStore: blobStore)
        pasteSimulator = PasteSimulator(blobStore: blobStore)
        permissionsManager = PermissionsManager()
        historyViewModel = HistoryViewModel(historyStore: historyStore, dbQueue: dbQueue)

        bookmarkStore = SecurityScopedBookmarkStore(settingsStore: settingsStore)
        fileSaveRouter = FileSaveRouter(bookmarkStore: bookmarkStore)
        hotkeyManager = HotkeyManager()
        snipCaptureService = SnipCaptureService(
            historyStore: historyStore,
            blobStore: blobStore,
            fileSaveRouter: fileSaveRouter,
            permissionsManager: permissionsManager
        )
        otpAutoClearService = OTPAutoClearService(historyStore: historyStore, hotkeyManager: hotkeyManager)
        pasteboardMonitor.onCapture = { [weak self] item in
            self?.otpAutoClearService.handleCapturedItem(item)
        }
        biometricAuthGate = BiometricAuthGate()

        applySettings(settingsStore.settings)
        observeSettingsChanges()

        pasteboardMonitor.start()

        setUpStatusItem()
        setUpPopover()

        // Calling this on every launch (not just first-run) is intentional and
        // non-annoying: once trusted, it's a no-op; once explicitly denied,
        // macOS doesn't re-show the system dialog on its own — it just keeps
        // returning false, which is what lets the popover's banner and the
        // onboarding window's status both stay accurate without re-nagging.
        permissionsManager.requestAccessibilityIfNeeded()
        hotkeyManager.start()

        // Deferred to the next run-loop tick: showing a window synchronously
        // as the last step of applicationDidFinishLaunching is unreliable for
        // an LSUIElement (accessory) app — it can be created but never
        // actually ordered onto screen. Dispatching async fixes it.
        DispatchQueue.main.async { [weak self] in
            self?.showOnboardingIfNeeded()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        pasteboardMonitor.stop()
        hotkeyManager.stop()
    }

    @objc private func applicationDidBecomeActive() {
        // Retry starting the tap in case the user granted Accessibility in
        // System Settings after launch and returned to Macby.
        if !hotkeyManager.isRunning {
            hotkeyManager.start()
        }
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Macby")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            popoverController?.toggle(relativeTo: statusItem?.button)
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Macby", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let view = SettingsRootView(settingsStore: settingsStore, historyStore: historyStore, bookmarkStore: bookmarkStore)
            settingsWindowController = SettingsWindowController(rootView: view)
        }
        settingsWindowController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Onboarding

    private static let hasCompletedOnboardingKey = "Macby.hasCompletedOnboarding"

    private func showOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey) else { return }

        let view = OnboardingView(
            permissionsManager: permissionsManager,
            onRequestAccessibility: { [weak self] in self?.permissionsManager.requestAccessibilityIfNeeded() },
            onFinish: { [weak self] in self?.onboardingWindowController?.window?.close() }
        )
        let controller = SettingsWindowController(rootView: view, title: "Welcome to Macby")
        onboardingWindowController = controller

        // Finishing onboarding funnels through the window closing — whether via
        // the "Get Started" button or the window's own close button — so there's
        // one source of truth regardless of how the user dismisses it.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onboardingWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: controller.window
        )

        // Briefly become a regular (Dock-visible) app while onboarding is up.
        // As a pure .accessory app, a window shown this early in the launch
        // sequence can be created but never actually get ordered onto screen —
        // temporarily switching activation policy is the standard fix for
        // menu-bar-only apps that need a reliable first-run window.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        controller.show()
    }

    @objc private func onboardingWindowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
        onboardingWindowController = nil
    }

    // MARK: - Popover

    private func setUpPopover() {
        let viewModel = historyViewModel!
        let permissionsManager = permissionsManager!
        let controller = PopoverPanelController { [weak self] in
            PopoverRootView(
                viewModel: viewModel,
                permissionsManager: permissionsManager,
                onPaste: { [weak self] item in self?.paste(item) },
                onClose: { [weak self] in self?.popoverController?.hide() },
                onOpenAccessibilitySettings: { [weak self] in self?.permissionsManager.openAccessibilitySettings() }
            )
        }
        controller.onWillShow = { [weak self] in
            self?.permissionsManager.refresh()
        }
        popoverController = controller
    }

    private func paste(_ item: ClipboardItem) {
        guard item.isSensitive, settingsStore.settings.requireBiometricForSensitivePaste else {
            popoverController?.hide()
            pasteSimulator.paste(item, asPlainText: settingsStore.settings.pasteAsPlainTextDefault)
            return
        }

        // Keep the popover open during authentication so the user can still
        // see/retry if it's cancelled or fails; only hide + paste on success.
        Task { [weak self] in
            guard let self else { return }
            let authorized = await biometricAuthGate.authorize(reason: "paste this item from Macby")
            guard authorized else { return }
            popoverController?.hide()
            pasteSimulator.paste(item, asPlainText: settingsStore.settings.pasteAsPlainTextDefault)
        }
    }

    // MARK: - Settings wiring

    private func applySettings(_ settings: AppSettings) {
        pasteboardMonitor.isPaused = settings.monitoringPaused
        pasteboardMonitor.excludedAppBundleIDs = Set(settings.excludedAppBundleIDs)
        pasteboardMonitor.otpDetectionEnabled = settings.otpDetectionEnabled
        pasteboardMonitor.sensitiveDetectionEnabled = settings.sensitiveDetectionEnabled
        pasteboardMonitor.aggressiveSSNDetectionEnabled = settings.aggressiveSSNDetectionEnabled
        historyStore.maxHistoryItemCount = settings.maxHistoryItemCount
        applyHotkeys(settings)
        otpAutoClearService.updateSettings(
            enabled: settings.otpDetectionEnabled,
            trigger: settings.otpClearTrigger,
            timeoutSeconds: settings.otpClearTimeoutSeconds
        )
    }

    private func applyHotkeys(_ settings: AppSettings) {
        if let popoverHotkeyToken { hotkeyManager.unregister(popoverHotkeyToken) }
        if let snipHotkeyToken { hotkeyManager.unregister(snipHotkeyToken) }
        popoverHotkeyToken = nil
        snipHotkeyToken = nil

        if let combo = settings.popoverHotkey {
            popoverHotkeyToken = hotkeyManager.register(combo) { [weak self] in
                self?.popoverController?.toggle(relativeTo: self?.statusItem?.button)
            }
        }
        if let combo = settings.snipCaptureHotkey {
            snipHotkeyToken = hotkeyManager.register(combo) { [weak self] in
                self?.snipCaptureService.startCapture()
            }
        }
    }

    private func observeSettingsChanges() {
        settingsCancellable = settingsStore.$settings.sink { [weak self] settings in
            self?.applySettings(settings)
        }
    }
}
