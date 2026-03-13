//
//  Util.swift
//  Runner
//
//  Created by Callum Moffat on 2026-03-13.
//

class Utils {
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
