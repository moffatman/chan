import UIKit
import AVFAudio
import Flutter
import Foundation
import Vision
import WebKit
import SwiftUI
import Translation
import NaturalLanguage

class MyFolderPickerDelegate : NSObject, UIDocumentPickerDelegate {
  private var onResult: ((Any?) -> Void)
  init(_ onResult: @escaping ((Any) -> Void)) {
    self.onResult = onResult
  }
  
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    do {
      guard let url = urls.first else {
        onResult(nil)
        return
      }
      guard url.startAccessingSecurityScopedResource() else {
        onResult(FlutterError.init(code: "InsufficientPermission", message: "Directory permissions failed", details: nil))
        return
      }
      defer { url.stopAccessingSecurityScopedResource() }
      
      var options: URL.BookmarkCreationOptions = []
      
      #if targetEnvironment(macCatalyst)
        // NSURLBookmarkCreationWithSecurityScope
        options.update(with: URL.BookmarkCreationOptions(rawValue: 1 << 11))
        // NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
        options.update(with: URL.BookmarkCreationOptions(rawValue: 1 << 12))
      #endif
      
      let bookmarkData = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      
      onResult(bookmarkData.base64EncodedString())
    }
    catch {
      onResult(FlutterError.init(code: "OS", message: "Picking folder failed", details: error.localizedDescription))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    onResult(nil)
  }
}

class MyFileExportDelegate : NSObject, UIDocumentPickerDelegate {
  private var onResult: ((Any?) -> Void)
  init(_ onResult: @escaping ((Any) -> Void)) {
    self.onResult = onResult
  }
  
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    onResult(urls.first?.path)
  }
  
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
    onResult(url.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    onResult(nil)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  var appleChannel: FlutterMethodChannel?
  var garbageKeepAlive: [any NSObjectProtocol] = []
  private var translationHelper: any TranslationHelper = DummyTranslationHelper()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    if #available(iOS 18.0, *) {
      let myBridge = TranslationBridge()
      let myTranslationHelper = RealTranslationHelper(bridge: myBridge)
      translationHelper = myTranslationHelper
      let hostVC = UIHostingController(rootView: TranslationTaskHost(bridge: myBridge))
      controller.addChild(hostVC)
      controller.view.addSubview(hostVC.view)
      hostVC.didMove(toParent: controller)
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
    }
    var currentActivity: NSUserActivity?
    appleChannel = FlutterMethodChannel(name: "com.moffatman.chan/apple", binaryMessenger: controller.binaryMessenger)
    appleChannel!.setMethodCallHandler({
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
      else if (call.method == "setHandoffUrl") {
        if let args = call.arguments as? Dictionary<String, Any> {
          let newUrl = URL.init(string: ((args["url"] as? String?) ?? nil) ?? "")
          if newUrl == nil {
            currentActivity?.resignCurrent()
            currentActivity = nil
          }
          else if currentActivity?.webpageURL != newUrl  {
            currentActivity?.resignCurrent()
            currentActivity = NSUserActivity(activityType:"com.moffatman.chan.thread")
            currentActivity!.webpageURL = newUrl
            currentActivity!.becomeCurrent()
          }
        }
        result(nil)
      }
      else if (call.method == "setAdditionalSafeAreaInsets") {
        if let fvc = application.keyWindow?.rootViewController as? FlutterViewController,
           let args = call.arguments as? Dictionary<String, Any>,
           let top = args["top"] as? NSNumber,
           let left = args["left"] as? NSNumber,
           let right = args["right"] as? NSNumber,
           let bottom = args["bottom"] as? NSNumber {
          fvc.additionalSafeAreaInsets = UIEdgeInsets.init(
            top: CGFloat(truncating: top),
            left: CGFloat(truncating: left),
            bottom: CGFloat(truncating: bottom),
            right: CGFloat(truncating: right)
          )
        }
        result(nil)
      }
      else if (call.method == "getUIFontFamilyNames") {
        result(UIFont.familyNames)
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
      else if (call.method == "updateBadge") {
        let nc = UNUserNotificationCenter.current()
        nc.getDeliveredNotifications { (list: [UNNotification]) in
          DispatchQueue.main.async {
            application.applicationIconBadgeNumber = list.count
          }
        }
        result(nil)
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
        if (UIPasteboard.general.hasImages) {
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
          result(UIPasteboard.general.string)
        }
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    let textRecognitionChannel = FlutterMethodChannel(name: "com.moffatman.chan/textRecognition", binaryMessenger: controller.binaryMessenger)
    textRecognitionChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "recognizeText") {
        if #available(iOS 13.0, *) {
          guard let args = call.arguments as? Dictionary<String, Any>,
                let path = args["path"] as? String,
                let recognitionLanguages = args["languages"] as? [String],
                let automaticallyDetectsLanguage = args["autoDetectLanguage"] as? Bool else {
            result(FlutterError.init(code: "ARGUMENTS", message: "Invalid arguments format", details: nil))
            return
          }
          guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
            result(FlutterError.init(code: "IMAGE", message: "Could not load image from provided path", details: nil))
            return
          }
          let requestHandler = VNImageRequestHandler(cgImage: cgImage)
          let request = VNRecognizeTextRequest(completionHandler: { (req: VNRequest, err: Error?) -> Void in
            guard let observations = req.results as? [VNRecognizedTextObservation] else {
              result(FlutterError.init(code: "PROCESSING", message: err?.localizedDescription, details: nil))
              return
            }
            let results: [Dictionary<String, Any>] = observations.compactMap { observation in
              guard let candidate = observation.topCandidates(1).first else { return nil }
              let stringRange = candidate.string.startIndex..<candidate.string.endIndex
              let boxObservation = try? candidate.boundingBox(for: stringRange)
              let boundingBox = boxObservation?.boundingBox ?? .zero
              let normalized = VNImageRectForNormalizedRect(boundingBox, Int(image.size.width), Int(image.size.height))
              return ["s": candidate.string, "l": normalized.origin.x, "t": image.size.height - (normalized.origin.y + normalized.size.height), "w": normalized.size.width, "h": normalized.size.height]
            }
            result(results)
          })
          request.recognitionLanguages = recognitionLanguages
          if #available(iOS 16.0, *) {
            request.automaticallyDetectsLanguage = automaticallyDetectsLanguage
          }
          do {
            try requestHandler.perform([request])
          }
          catch {
            result(FlutterError.init(code: "PROCESSING", message: error.localizedDescription, details: nil))
          }
        }
        else {
          result(FlutterError.init(code: "OS", message: "iOS version too low to support text recognition", details: nil))
        }
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    let audioChannel = FlutterMethodChannel(name: "com.moffatman.chan/audio", binaryMessenger: controller.binaryMessenger)
    audioChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "areHeadphonesPluggedIn") {
        result(AVAudioSession.sharedInstance().currentRoute.outputs.contains(where: {$0.portType == .headphones || $0.portType == .bluetoothLE || $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP}))
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    let userAgentChannel = FlutterMethodChannel(name: "com.moffatman.chan/userAgent", binaryMessenger: controller.binaryMessenger)
    userAgentChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "getDefaultUserAgent") {
        result(WKWebView().value(forKey: "userAgent"))
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    let storageChannel = FlutterMethodChannel(name: "com.moffatman.chan/storage", binaryMessenger: controller.binaryMessenger)
    storageChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "pickDirectory") {
        if #available(iOS 14.0, *) {
          let folderPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
          folderPicker.shouldShowFileExtensions = true
          let delegate = MyFolderPickerDelegate() { (value: Any) in
            result(value)
            self.garbageKeepAlive.removeAll(where: { $0.isEqual(folderPicker.delegate) })
            self.garbageKeepAlive.removeAll(where: { $0.isEqual(folderPicker) })
          }
          folderPicker.delegate = delegate
          self.garbageKeepAlive.append(delegate)
          self.garbageKeepAlive.append(folderPicker)
          controller.present(folderPicker, animated: true, completion: nil)
        } else {
          result(FlutterError.init(code: "OS", message: "iOS version too low to support picking directory", details: nil))
        }
      }
      else if (call.method == "saveFile") {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let sourcePath = args["sourcePath"] as? String,
              let destinationDir = args["destinationDir"] as? String,
              let destinationSubfolders = args["destinationSubfolders"] as? [String],
              let destinationName = args["destinationName"] as? String else {
          result(FlutterError.init(code: "ARGUMENTS", message: "Invalid arguments format", details: nil))
          return
        }
        
        do {
          guard let bookmarkData = Data(base64Encoded: destinationDir) else {
            result(FlutterError.init(code: "InsufficientPermission", message: "Directory permissions invalid", details: nil))
            return
          }
          var isStale = false
          var options: URL.BookmarkResolutionOptions = []
          #if targetEnvironment(macCatalyst)
            // NSURLBookmarkResolutionWithSecurityScope
            options.update(with: URL.BookmarkResolutionOptions(rawValue: 1 << 10))
          #endif
          let url = try URL(resolvingBookmarkData: bookmarkData, options: options, bookmarkDataIsStale: &isStale)

          guard !isStale else {
            result(FlutterError.init(code: "InsufficientPermission", message: "Directory permissions expired", details: nil))
            return
          }
          
          guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError.init(code: "InsufficientPermission", message: "Directory permissions failed", details: nil))
            return
          }
          
          defer { url.stopAccessingSecurityScopedResource() }
          
          var error: NSError? = nil
          NSFileCoordinator().coordinate(readingItemAt: url, error: &error) { (url) in
            do {
              var folderUrl = url
              for subfolder in destinationSubfolders {
                folderUrl = folderUrl.appendingPathComponent(subfolder)
              }
              try FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true)
              var fileUrl = folderUrl.appendingPathComponent(destinationName)
              
              if (FileManager.default.fileExists(atPath: fileUrl.path)) {
                var i = 0
                repeat {
                  i += 1
                  fileUrl = folderUrl.appendingPathComponent("\((destinationName as NSString).deletingPathExtension) (\(i)).\((destinationName as NSString).pathExtension)")
                } while (FileManager.default.fileExists(atPath: fileUrl.path))
              }
              
              let contents = FileManager.default.contents(atPath: sourcePath)
              
              guard FileManager.default.createFile(atPath: fileUrl.path, contents: contents) else {
                result(FlutterError.init(code: "OS", message: "Failed to create file", details: fileUrl.path))
                return
              }
              result(fileUrl.lastPathComponent)
            }
            catch {
              result(FlutterError.init(code: "OS", message: "Problem accessing filesystem", details: error.localizedDescription))
            }
          }
          
          if let error {
            result(FlutterError.init(code: "OS", message: "Problem opening directory", details: error.localizedDescription))
          }
        }
        catch {
          result(FlutterError.init(code: "OS", message: "Saving file failed", details: error.localizedDescription))
        }
      }
      else if (call.method == "saveFileAs") {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let sourcePath = args["sourcePath"] as? String,
              let destinationName = args["destinationName"] as? String else {
          result(FlutterError.init(code: "ARGUMENTS", message: "Invalid arguments format", details: nil))
          return
        }
        let sourceUrl = URL(fileURLWithPath: sourcePath)
        if #available(iOS 14.0, *) {
          let filePicker = UIDocumentPickerViewController(forExporting: [sourceUrl], asCopy: false)
          filePicker.shouldShowFileExtensions = true
          let delegate = MyFileExportDelegate() { (value: Any) in
            result(value)
            self.garbageKeepAlive.removeAll(where: { $0.isEqual(filePicker.delegate) })
            self.garbageKeepAlive.removeAll(where: { $0.isEqual(filePicker) })
          }
          filePicker.delegate = delegate
          self.garbageKeepAlive.append(delegate)
          self.garbageKeepAlive.append(filePicker)
          controller.present(filePicker, animated: true, completion: nil)
        }
        else {
          result(FlutterError.init(code: "OS", message: "iOS version too low to support saving file", details: nil))
        }
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    let translationChannel = FlutterMethodChannel(name: "com.moffatman.chan/translation", binaryMessenger: controller.binaryMessenger)
    translationChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "isSupported") {
        if #available(iOS 18.0, *) {
          result(true)
        }
        result(false)
      }
      else if (call.method == "translate") {
        guard let args = call.arguments as? Dictionary<String, Any>,
              let text = args["text"] as? String,
              let to = args["to"] as? String,
              let interactive = args["interactive"] as? Bool else {
          result(FlutterError.init(code: "ARGUMENTS", message: "Invalid arguments format", details: nil))
          return
        }
        if #available(iOS 18.0, *) {
          let toLanguage = Locale.Language(languageCode: Locale.LanguageCode(to))
          let recognizer = NLLanguageRecognizer()
          // This seems to get confused with the HTML tags. So detect language without them
          let htmlPattern = /<\/?[a-z0-9]+\/?>/
          let strippedText = text.replacing(htmlPattern, with: "")
          recognizer.processString(strippedText)
          guard let dominantLanguage = recognizer.dominantLanguage?.rawValue else {
            result(nil)
            return
          }
          let simpleLanguage = detectLanguageSimple(strippedText)
          if dominantLanguage == toLanguage.languageCode?.identifier && dominantLanguage == simpleLanguage {
            result(text)
            return
          }
          let topLanguages = recognizer.languageHypotheses(withMaximum: 3)
          var fromLanguageCodes =
            ((topLanguages.values.max() ?? 1) > 0.6)
                ? [dominantLanguage]
          : topLanguages.filter{ $0.value > 0.15 }.sorted { $0.value > $1.value }.map { $0.key.rawValue }
          if let simpleLanguage {
            if !fromLanguageCodes.contains(where: { $0 == simpleLanguage }) {
              fromLanguageCodes.insert(simpleLanguage, at: 0)
            }
          }
          Task {
            var firstError: FlutterError?
            for fromLanguageCode in fromLanguageCodes {
              let fromLanguage = Locale.Language(languageCode: Locale.LanguageCode(fromLanguageCode))
              let la = LanguageAvailability()
              let status = await la.status(from: fromLanguage, to: toLanguage)
              if status == .unsupported {
                // Maybe try other language
                continue
              }
              if #available(iOS 26.0, *), status == .installed {
                let session = TranslationSession(installedSource: fromLanguage, target: toLanguage)
                do {
                  let translated = try await session.translate(text)
                  result(translated.targetText)
                  return
                } catch TranslationError.notInstalled, TranslationError.unsupportedLanguagePairing, TranslationError.unsupportedSourceLanguage, TranslationError.unsupportedTargetLanguage {
                  continue
                } catch {
                  result(FlutterError.init(code: "OS", message: "Translation failed", details: error.localizedDescription))
                  return
                }
              }
              if !interactive {
                firstError = firstError ?? FlutterError.init(code: "INTERACTION_NEEDED", message: "Language download required", details: fromLanguage.languageCode?.identifier)
                continue
              }
              let translationResult = await self.translationHelper.translate(text: text, source: fromLanguage, target: .init(identifier: to))
              switch translationResult {
              case .success(let translated):
                result(translated)
                return
              case .failure (let error as NSError) where error.code == 3072:
                // TODO: Test on iOS
                firstError = firstError ?? FlutterError.init(code: "CANCELLED", message: "Translation cancelled", details: nil)
                continue
              case .failure(let error):
                result(FlutterError.init(code: "OS", message: "Translation failed", details: error.localizedDescription))
                return
              }
            }
            result(firstError)
          }
        }
        else {
          result(nil)
        }
      }
      else {
        result(FlutterMethodNotImplemented)
      }
    })
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    if let fvc = application.keyWindow?.rootViewController as? FlutterViewController {
      restorationHandler([fvc])
      if userActivity.activityType == "com.moffatman.chan.thread" {
        appleChannel?.invokeMethod("receivedHandoffUrl", arguments: [
          "url": userActivity.webpageURL?.absoluteString
        ])
      }
      else {
        NSLog("Unknown activity type: \(userActivity.activityType)")
      }
      return true
    }
    else {
      return false
    }
  }
}
