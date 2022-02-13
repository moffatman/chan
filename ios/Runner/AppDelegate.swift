import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let statusBarChannel = FlutterMethodChannel(name: "com.moffatman.chan/statusBar", binaryMessenger: controller.binaryMessenger)
    statusBarChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "showStatusBar") {
        application.setStatusBarHidden(false, with: UIStatusBarAnimation.fade)
        result(nil)
      }
      else if (call.method == "hideStatusBar") {
        application.setStatusBarHidden(true, with: UIStatusBarAnimation.fade)
        result(nil)
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    let isOnMacChannel = FlutterMethodChannel(name: "com.moffatman.chan/isOnMac", binaryMessenger: controller.binaryMessenger)
    isOnMacChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "isOnMac") {
        #if targetEnvironment(macCatalyst)
            result(true)
        #else
            if #available(iOS 14.0, *) {
                result(ProcessInfo.processInfo.isiOSAppOnMac)
            } else {
                result(false)
            }
        #endif
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
