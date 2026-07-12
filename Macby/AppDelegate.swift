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

        applySettings(settingsStore.settings)
        observeSettingsChanges()

        pasteboardMonitor.start()

        setUpStatusItem()
        setUpPopover()

        permissionsManager.requestAccessibilityIfNeeded()
        hotkeyManager.start()

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

    // MARK: - Popover

    private func setUpPopover() {
        let viewModel = historyViewModel!
        popoverController = PopoverPanelController { [weak self] in
            PopoverRootView(
                viewModel: viewModel,
                onPaste: { [weak self] item in self?.paste(item) },
                onClose: { [weak self] in self?.popoverController?.hide() }
            )
        }
    }

    private func paste(_ item: ClipboardItem) {
        popoverController?.hide()
        pasteSimulator.paste(item, asPlainText: settingsStore.settings.pasteAsPlainTextDefault)
    }

    // MARK: - Settings wiring

    private func applySettings(_ settings: AppSettings) {
        pasteboardMonitor.isPaused = settings.monitoringPaused
        pasteboardMonitor.excludedAppBundleIDs = Set(settings.excludedAppBundleIDs)
        historyStore.maxHistoryItemCount = settings.maxHistoryItemCount
        applyHotkeys(settings)
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
