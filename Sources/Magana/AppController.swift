// AppController.swift
// Where the tap, the switcher and the settings meet. Holds no judgement of its
// own: the rules live in MaganaCore, the OS calls live in the services.

import AppKit
import Combine
import MaganaCore

@MainActor
final class AppController: ObservableObject {
  /// A line the menu shows above the actions when something needs attention.
  ///
  /// Which ones apply is `AppCondition.warnings`; this only carries the wording,
  /// which is the view's business. Each one says what happened and what to do
  /// about it.
  struct Warning: Identifiable {
    let kind: AppWarning

    var id: String { message }

    var message: String {
      switch kind {
      case .permissionMissing:
        return "アクセシビリティが許可されていません。許可の手順を開く…"
      case .noJapaneseInputSource:
        return "日本語入力ソースが有効になっていません。システム設定 › キーボード › 入力ソース で追加してください"
      case .jisKeyboardConnected:
        return "JIS キーボードが接続されているため切り替えを止めています。設定で「JIS キーボードでは無効にする」をオフにすると動きます"
      }
    }
  }

  /// How long after an app comes forward its default input source is applied.
  ///
  /// A frontmost app that has just been activated is still setting up its own
  /// input context; posting immediately can land before it is listening. 100ms
  /// is the starting value, well inside F-17's 300ms budget.
  private static let activationDelay: Duration = .milliseconds(100)

  @Published private(set) var inputSource: InputSourceKind = .eisuu
  @Published private(set) var isTrusted = false
  @Published private(set) var hasJapaneseSource = true
  @Published private(set) var hasJISKeyboard = false

  @Published var settings: Settings {
    didSet {
      guard settings != oldValue else { return }
      store.save(settings)
      detector.configuration = DetectorConfiguration(settings: settings)
      // A rule may have been added to the app that is frontmost right now, and
      // the user should not have to switch away and back for it to take.
      activationPolicy.reset()
    }
  }

  /// Set by the menu bar label once SwiftUI can open windows.
  var openWindow: ((String) -> Void)?

  private let store: SettingsStore
  private let tap = EventTap()
  private let switcher = Switcher()
  private let inputSources = InputSourceService()
  private let permission = PermissionService()
  private let keyboards = KeyboardRegistry()
  private let appRules = AppRuleService()

  /// Owned here so there is one checker for the app, but observed directly by
  /// the views that show it: a nested ObservableObject does not republish
  /// through its owner.
  let updater = UpdateController()
  /// The lit state of the ⌘ caps in the settings window.
  let commandKeys = CommandKeyMonitor()

  private var detector: AloneDetector
  private var activationPolicy = ActivationPolicy()
  private var hasStarted = false
  /// Read before anything is saved, so `start()` can tell a first launch from
  /// a launch where the user has turned the login item off.
  private let hadStoredSettings: Bool

  init(store: SettingsStore = SettingsStore()) {
    self.store = store
    self.hadStoredSettings = store.hasStoredSettings
    let settings = store.load()
    self.settings = settings
    self.detector = AloneDetector(configuration: DetectorConfiguration(settings: settings))
  }

  // MARK: - Lifecycle

  func start() {
    // The menu bar label's onAppear is the only caller, but SwiftUI makes no
    // promise about how often a view appears; starting twice would leave two
    // timers and two sets of notification observers running.
    guard !hasStarted else { return }
    hasStarted = true

    tap.onEvent = { [weak self] event in self?.handle(event) }
    tap.onSystemDisable = { [weak self] in self?.detector.reset() }

    inputSources.onChange = { [weak self] in self?.syncInputSource() }
    inputSources.start()
    syncInputSource()

    keyboards.onChange = { [weak self] in
      guard let self else { return }
      self.hasJISKeyboard = self.keyboards.hasJISKeyboard
    }
    keyboards.start()
    hasJISKeyboard = keyboards.hasJISKeyboard

    appRules.onActivate = { [weak self] bundleID in self?.handleActivation(bundleID) }
    appRules.start()

    permission.onChange = { [weak self] trusted in self?.applyPermission(trusted) }
    permission.start()
    applyPermission(permission.isTrusted)

    // The stored toggle and what macOS actually has registered can disagree —
    // the user may have switched the login item off in System Settings — and
    // the truth is macOS's. On a first launch there is nothing registered and
    // nothing stored, so the default (on) is written to macOS instead of being
    // read back off it.
    if hadStoredSettings {
      settings.launchAtLogin = LoginItem.isEnabled
    } else if settings.launchAtLogin {
      setLaunchAtLogin(true)
    }

    updater.isAutoCheckEnabled = { [weak self] in self?.settings.autoCheckUpdates ?? true }
    updater.start()
  }

  // MARK: - Derived state

  /// Everything the status line and the warnings are decided from, gathered so
  /// the deciding happens in `MaganaCore` where a test can reach it.
  var condition: AppCondition {
    AppCondition(
      isTrusted: isTrusted,
      paused: settings.paused,
      disableOnJIS: settings.disableOnJIS,
      hasJISKeyboard: hasJISKeyboard,
      hasJapaneseSource: hasJapaneseSource
    )
  }

  var status: AppStatus { condition.status }

  var statusText: String {
    switch status {
    case .active: return "有効"
    case .paused: return "一時停止中"
    case .noPermission: return "無効（権限なし）"
    case .disabledByJISKeyboard: return "無効"
    }
  }

  var inputSourceText: String {
    inputSource == .kana ? "かな" : "英数 (ABC)"
  }

  var warnings: [Warning] {
    condition.warnings.map(Warning.init(kind:))
  }

  // MARK: - Actions

  func togglePause() {
    settings.paused.toggle()
    // A ⌘ that went down while paused must not complete into a switch when the
    // app comes back.
    detector.reset()
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    let status = LoginItem.setEnabled(enabled)
    settings.launchAtLogin = status == .enabled
  }

  func openAccessibilitySettings() {
    permission.requestAndOpenSettings()
  }

  func openSettingsWindow() {
    open(WindowID.settings)
  }

  func openPermissionWindow() {
    open(WindowID.permission)
  }

  func openUpdateWindow() {
    open(WindowID.update)
  }

  func runningApplications() -> [RunningApp] {
    let existing = Set(settings.appRules.map(\.bundleID))
    return AppRuleService.runningApplications().filter { !existing.contains($0.bundleID) }
  }

  func addRule(for app: RunningApp) {
    guard !settings.appRules.contains(where: { $0.bundleID == app.bundleID }) else { return }
    settings.appRules.append(
      AppRule(bundleID: app.bundleID, displayName: app.name, action: .noSwitch))
  }

  func removeRule(_ rule: AppRule) {
    settings.appRules.removeAll { $0.bundleID == rule.bundleID }
  }

  func setRuleAction(_ action: AppRuleAction, for rule: AppRule) {
    guard let index = settings.appRules.firstIndex(where: { $0.bundleID == rule.bundleID }) else {
      return
    }
    settings.appRules[index].action = action
  }

  func quit() {
    NSApp.terminate(nil)
  }

  // MARK: - Wiring

  private func applyPermission(_ trusted: Bool) {
    guard trusted else {
      isTrusted = false
      tap.stop()
      commandKeys.reset()
      openPermissionWindow()
      return
    }

    detector.reset()
    // Creating the tap is the real test. AXIsProcessTrusted() can still say yes
    // for a moment after the grant is revoked, and a tap that failed to be
    // created is indistinguishable from one that never sees a key — so the
    // app reports "no permission" and the one-second poll retries.
    guard tap.start() else {
      isTrusted = false
      openPermissionWindow()
      return
    }
    isTrusted = true
  }

  private func syncInputSource() {
    inputSource = inputSources.current
    hasJapaneseSource = inputSources.hasJapaneseSource
    Diagnostics.trace(
      "input source is now \(inputSource.rawValue) (japanese available=\(hasJapaneseSource))")
  }

  private func handle(_ event: DetectorEvent) {
    // Before the judgement, and regardless of its outcome: the caps light for
    // the key being held, not for a press that turned out to switch something.
    commandKeys.handle(event)

    guard let action = detector.handle(event), let target = action.targetInputSource else { return }
    Diagnostics.trace(
      "alone press -> \(target.rawValue) (status=\(status) excluded=\(isFrontmostAppExcluded))")
    guard canSwitch, !isFrontmostAppExcluded else { return }
    // Posting is deferred so the tap callback returns immediately; a tap that
    // overruns its deadline is one macOS switches off.
    Task { @MainActor [weak self] in self?.apply(target) }
  }

  private func handleActivation(_ bundleID: String?) {
    guard canSwitch else { return }
    guard
      let target = activationPolicy.inputSourceOnActivation(of: bundleID, settings: settings)
    else { return }
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: Self.activationDelay)
      self?.apply(target)
    }
  }

  private var canSwitch: Bool {
    condition.canSwitch
  }

  private var isFrontmostAppExcluded: Bool {
    settings.rule(forBundleID: appRules.frontmostBundleID)?.action == .noSwitch
  }

  private func apply(_ target: InputSourceKind) {
    // Read the live state rather than the cached one: the notification that
    // keeps `inputSource` current is asynchronous, and posting a key that
    // changes nothing is the failure F-1 / F-2 call out by name.
    inputSources.refresh()
    switch SwitchDecision.outcome(
      target: target,
      current: inputSources.current,
      hasJapaneseSource: inputSources.hasJapaneseSource)
    {
    case .alreadyThere:
      Diagnostics.trace("apply \(target.rawValue): already there, not posting")
    case .noJapaneseInputSource:
      Diagnostics.trace("apply kana: no Japanese input source enabled")
    case .post:
      Diagnostics.trace("posting \(target.rawValue) key (was \(inputSources.current.rawValue))")
      switcher.send(target)
    }
  }

  private func open(_ id: String) {
    openWindow?(id)
    NSApp.activate(ignoringOtherApps: true)
  }
}

enum WindowID {
  static let settings = "settings"
  static let permission = "permission"
  static let update = "update"
}
