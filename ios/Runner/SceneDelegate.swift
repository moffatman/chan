import Flutter
import SwiftUI
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private(set) var translationHelper: (any TranslationHelper)?
  private weak var translationHost: UIViewController?

  override func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    guard Utils.canAccessRestorationBundle else { return nil }
    return super.stateRestorationActivity(for: scene)
  }

  override func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
    guard Utils.canAccessRestorationBundle else { return }
    super.scene(scene, restoreInteractionStateWith: stateRestorationActivity)
  }

  #if DEBUG
  private var debugBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func sceneDidEnterBackground(_ scene: UIScene) {
    // Flutter's legacy lifecycle requested this grace period for debugging,
    // but its UIScene path currently skips that request.
    if debugBackgroundTask == .invalid {
      debugBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Flutter debug task") { [weak self] in
        self?.endDebugBackgroundTask()
        NSLog("Flutter debug background time expired; the OS may suspend the VM service connection.")
      }
    }
    super.sceneDidEnterBackground(scene)
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    endDebugBackgroundTask()
    super.sceneWillEnterForeground(scene)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    endDebugBackgroundTask()
    super.sceneDidDisconnect(scene)
  }

  private func endDebugBackgroundTask() {
    guard debugBackgroundTask != .invalid else { return }
    let task = debugBackgroundTask
    debugBackgroundTask = .invalid
    UIApplication.shared.endBackgroundTask(task)
  }
  #endif

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // UIKit has loaded Main.storyboard into this scene's window by this point.
    if let controller = window?.rootViewController as? FlutterViewController {
      configureViewController(controller)
    }
  }

  private func configureViewController(_ controller: FlutterViewController) {
    guard translationHost?.parent !== controller else { return }
    if #available(iOS 18.0, *) {
      let bridge = TranslationBridge()
      translationHelper = RealTranslationHelper(bridge: bridge)
      let hostVC = UIHostingController(rootView: TranslationTaskHost(bridge: bridge))
      controller.addChild(hostVC)
      controller.view.addSubview(hostVC.view)
      hostVC.view.backgroundColor = .clear
      hostVC.view.isUserInteractionEnabled = false
      hostVC.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        hostVC.view.widthAnchor.constraint(equalToConstant: 1),
        hostVC.view.heightAnchor.constraint(equalToConstant: 1),
        hostVC.view.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
        hostVC.view.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
      ])
      hostVC.view.alpha = 0.01
      hostVC.didMove(toParent: controller)
      translationHost = hostVC
    }
  }
}

// Keep trait observation on the actual Flutter controller, whose traits follow
// its scene as the app moves between displays and the device changes pose.
@objc(ChanceFlutterViewController)
class ChanceFlutterViewController: FlutterViewController {
  var duoBarWidth: CGFloat = 85
  var navigationBarHeight: CGFloat = 44
  private var lastDuoLayout: NSDictionary?

  var duoLayout: [String: Any] {
    guard #available(iOS 27.1, *), isViewLoaded else { return ["side": 0] }
    let edge = traitCollection.verticalBarEdge
    if edge == .unspecified {
      let insets = view.edgeInsets(for: .bar(onEdge: UIRectEdge.top, extent: navigationBarHeight))
      // Some configurations put status elements beside top-bar content instead
      // of above it. Only replace the ordinary safe area when UIKit allows this.
      guard insets.top < view.safeAreaInsets.top else { return ["side": 0] }
      return [
        "side": 3,
        "top": max(0, insets.top - additionalSafeAreaInsets.top),
        "left": max(0, insets.left - additionalSafeAreaInsets.left),
        "right": max(0, insets.right - additionalSafeAreaInsets.right),
      ]
    }
    let rtl = traitCollection.layoutDirection == .rightToLeft
    let onLeft = (edge == .leading) != rtl
    let barEdge: UIRectEdge = onLeft ? .left : .right
    let insets = view.edgeInsets(for: .bar(onEdge: barEdge, extent: duoBarWidth))
    let horizontalInsets: UIEdgeInsets
    if #available(iOS 27.2, *) {
      // Align to the system bar's content region, whose default extent can
      // differ from our wider rail. Keep our own extent for vertical clearance.
      horizontalInsets = view.edgeInsets(for: .bar(onEdge: barEdge))
    } else {
      horizontalInsets = insets
    }
    // Convert window-relative insets into padding within the bar. The inner
    // inset includes the rest of the window as well as the bar's own padding.
    let outsideBarWidth = max(0, view.bounds.width - duoBarWidth)
    return [
      "side": onLeft ? 1 : 2,
      // Flutter removes these synthetic insets from its root MediaQuery too.
      "top": max(0, insets.top - additionalSafeAreaInsets.top),
      "bottom": max(0, insets.bottom - additionalSafeAreaInsets.bottom),
      "left": max(0, horizontalInsets.left - (onLeft ? 0 : outsideBarWidth) - additionalSafeAreaInsets.left),
      "right": max(0, horizontalInsets.right - (onLeft ? outsideBarWidth : 0) - additionalSafeAreaInsets.right),
    ]
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    if #available(iOS 27.1, *) {
      // UIKit also invokes these registrations on dynamic snapshot controllers.
      // Do not cast that controller to our subclass or send it our selectors.
      registerForTraitChanges(
        UITraitCollection.systemTraitsAffectingVerticalBarEdge
      ) { [weak self] (_: UIViewController, _: UITraitCollection) in
        self?.pushDuoLayout()
      }
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    pushDuoLayout()
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    pushDuoLayout()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if view.window != nil, !view.bounds.isEmpty,
       let delegate = UIApplication.shared.delegate as? AppDelegate {
      let pending = delegate.pendingDuoLayoutConfigurations
      delegate.pendingDuoLayoutConfigurations.removeAll()
      for configure in pending {
        configure(self)
      }
    }
    pushDuoLayout()
  }

  func pushDuoLayout(force: Bool = false, completion: FlutterResult? = nil) {
    let layout = duoLayout
    let snapshot = layout as NSDictionary
    guard force || snapshot != lastDuoLayout else { return }
    lastDuoLayout = snapshot
    (UIApplication.shared.delegate as? AppDelegate)?.appleChannel?.invokeMethod("duoLayoutChanged", arguments: layout, result: completion)
  }
}
