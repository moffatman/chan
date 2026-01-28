private enum SimpleLanguage: String, CaseIterable, Hashable {
    // Semitic / Indic / SE Asian
    case arabic              = "ar"
    case hindi               = "hi"
    case thai                = "th"
    // CJK
    case cjk                 = "zh-Hans" // Just default to chinese (simplified)
    case japanese            = "ja"
    case korean              = "ko"
    // Cyrillic (Unicode cannot disambiguate ru vs uk)
    case russian             = "ru"
    case ukrainian           = "uk"
    // Latin-script bucket (covers en/fr/de/…)
    case latin               = "en"
}

private func languageForBMPScalar(_ v: UInt32) -> SimpleLanguage? {
    switch v {
    // Arabic
    case 0x0600...0x06FF, 0x0750...0x077F:
        return .arabic

    // Devanagari (Hindi)
    case 0x0900...0x097F:
        return .hindi

    // Thai
    case 0x0E00...0x0E7F:
        return .thai

    // Japanese (kana)
    case 0x3040...0x309F, 0x30A0...0x30FF:
        return .japanese

    // Korean (Hangul)
    case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F:
        return .korean

    // Han ideographs
    // Unicode does not encode simplified vs traditional;
    // we choose Simplified as the canonical bucket.
    case 0x4E00...0x9FFF, 0xF900...0xFAFF:
        return .cjk

    // Cyrillic (ru / uk indistinguishable by Unicode)
    case 0x0400...0x052F:
        return .russian

    // Latin (all Latin-script languages)
    case 0x0000...0x024F, 0x1E00...0x1EFF:
        return .latin

    default:
        return nil
    }
}

private struct UnicodeSanityCounts {
    var asciiAll: Int            // 0x00...0x7F
    var asciiPrintable: Int      // 0x20...0x7E
    var bmpTotal: Int

    var byLanguage: [SimpleLanguage: Int]
    
    var languageCode: String? {
        var map = byLanguage
        if (map.isEmpty) {
            return nil
        }
        if (map.count == 1) {
            return map.first?.key.rawValue
        }
        map.removeValue(forKey: .latin)
        if (map.count == 1) {
            return map.first?.key.rawValue
        }
        map.removeValue(forKey: .cjk)
        if (map.count == 1) {
            return map.first?.key.rawValue
        }
        NSLog("Could not resolve, original=\(byLanguage), final=\(map)")
        return nil
    }
}



private func countUnicodeSanityBMP(_ s: String) -> UnicodeSanityCounts {
    var asciiAll = 0
    var asciiPrintable = 0
    var bmpTotal = 0

    var byLanguage: [SimpleLanguage: Int] = [:]

    for scalar in s.unicodeScalars {
        let v = scalar.value
        guard v <= 0xFFFF else { continue }   // BMP only

        bmpTotal += 1

        if v <= 0x7F {
            asciiAll += 1
            if v >= 0x20 && v <= 0x7E {
                asciiPrintable += 1
            }
        }

        if let lang = languageForBMPScalar(v) {
            byLanguage[lang, default: 0] += 1
        }
    }

    return UnicodeSanityCounts(
        asciiAll: asciiAll,
        asciiPrintable: asciiPrintable,
        bmpTotal: bmpTotal,
        byLanguage: byLanguage
    )
}

public func detectLanguageSimple(_ s: String) -> String? {
    return countUnicodeSanityBMP(s).languageCode
}
