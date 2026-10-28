//
//  Util.swift
//  Runner
//
//  Created by Callum Moffat on 2026-03-13.
//

import Foundation

class Utils {
    // An iOS app on macOS can outlive its temporary Wrapper/Runner.app path.
    // Flutter's application and scene restoration callbacks assert if they
    // cannot read the executable's modification date.
    static var canAccessRestorationBundle: Bool {
        guard let executableURL = Bundle.main.executableURL else { return false }
        // Use a fresh URL so cached metadata cannot hide a removed executable.
        let url = URL(fileURLWithPath: executableURL.path)
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else { return false }
        return values.contentModificationDate != nil
    }

    private static func computeIsOnMac() -> Bool {
        #if targetEnvironment(macCatalyst)
            return true
        #else
            if #available(iOS 14.0, *) {
                return ProcessInfo.processInfo.isiOSAppOnMac
            } else {
                return false
            }
        #endif
    }
    static let isOnMac = computeIsOnMac()
}
