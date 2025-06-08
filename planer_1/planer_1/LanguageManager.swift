import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    init() {
        if let languageCode = Locale.current.language.languageCode?.identifier {
            self.currentLanguage = languageCode
        } else {
            self.currentLanguage = "en"
        }
    }
    
    func toggleLanguage() {
        currentLanguage = currentLanguage == "ru" ? "en" : "ru"
    }
    
    func setLanguage(_ language: String) {
        currentLanguage = language
    }
}

class BundleEx: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = Bundle.main.path(forResource: LanguageManager().currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension String {
    var localized: String {
        let lang = LanguageManager.shared.currentLanguage
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
    }
} 