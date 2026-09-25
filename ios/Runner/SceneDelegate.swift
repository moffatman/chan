import Flutter
import SwiftUI
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private(set) var translationHelper: (any TranslationHelper)?
  private weak var translationHost: UIViewController?

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
