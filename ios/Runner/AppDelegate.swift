import UIKit
import Flutter
import Foundation

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
    let isOnMacChannel = FlutterMethodChannel(name: "com.moffatman.chan/apple", binaryMessenger: controller.binaryMessenger)
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
      else if (call.method == "isDevelopmentBuild") {
        #if targetEnvironment(simulator)
            result(true)
        #else
        if let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
          if NSData.init(contentsOfFile: path) != nil {
            result(true)
          }
          else {
            result(false)
          }
        }
        else {
          result(false)
        }
        #endif
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    let notificationsChannel = FlutterMethodChannel(name: "com.moffatman.chan/notifications", binaryMessenger: controller.binaryMessenger)
    notificationsChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "clearNotificationsWithProperties") {
        if let args = call.arguments as? Dictionary<String, Any> {
          let nc = UNUserNotificationCenter.current()
          nc.getDeliveredNotifications { (list: [UNNotification]) in
            nc.removeDeliveredNotifications(withIdentifiers: list.filter { item in
              for k in args.keys {
                if (String(describing: item.request.content.userInfo[k] as? AnyHashable) != String(describing: args[k] as? AnyHashable)) {
                  return false
                }
              }
              return true
            }.map({$0.request.identifier}))
            result(nil)
          }
        }
        else {
          result(FlutterError.init(code: "BAD_ARGS", message: "Bad Arguments", details: nil))
        }
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    let clipboardChannel = FlutterMethodChannel(name: "com.moffatman.chan/clipboard", binaryMessenger: controller.binaryMessenger)
    clipboardChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "doesClipboardContainImage") {
        result(UIPasteboard.general.hasImages)
      }
      else if (call.method == "getClipboardImage") {
        // Browsers copy GIF by putting one frame in image variable
        // and putting a link to the full GIF in the html section
        let pattern = #"<img[^<]+src="([^"]+\.gif[^"]*)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let html = String(data: UIPasteboard.general.data(forPasteboardType: "public.html") ?? Data.init(), encoding: .utf8) ?? ""
        let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html))
        if let match = match {
          let url = (html as NSString).substring(with: match.range(at: 1))
          let task = URLSession.shared.dataTask(with: URL(string: url)!) { data, response, error in
            if error != nil {
              result(FlutterError.init(code: "NETWORK", message: "Could not get GIF from URL", details: nil))
              return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
              result(FlutterError.init(code: "NETWORK", message: "Could not get GIF from URL", details: nil))
              return
            }
            result(data)
          }
          task.resume()
        }
        else {
          result(UIPasteboard.general.image?.jpegData(compressionQuality: 0.9))
        }
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
