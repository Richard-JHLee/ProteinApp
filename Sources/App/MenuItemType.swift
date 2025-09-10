import SwiftUI

enum MenuItemType: String, CaseIterable {
    case about = "About"
    case userGuide = "User Guide"
    case features = "Features"
    case settings = "Settings"
    case help = "Help"
    case privacy = "Privacy Policy"
    case terms = "Terms of Service"
    case license = "License"
    
    var icon: String {
        switch self {
        case .about: return "info.circle"
        case .userGuide: return "book"
        case .features: return "star"
        case .settings: return "gear"
        case .help: return "questionmark.circle"
        case .privacy: return "hand.raised"
        case .terms: return "doc.text"
        case .license: return "doc.plaintext"
        }
    }
    
    var description: String {
        switch self {
        case .about: return LanguageHelper.localizedText(
            korean: "앱 정보 및 버전",
            english: "App information and version"
        )
        case .userGuide: return LanguageHelper.localizedText(
            korean: "사용자 가이드",
            english: "User guide"
        )
        case .features: return LanguageHelper.localizedText(
            korean: "주요 기능",
            english: "Key features"
        )
        case .settings: return LanguageHelper.localizedText(
            korean: "앱 설정",
            english: "App settings"
        )
        case .help: return LanguageHelper.localizedText(
            korean: "도움말 및 FAQ",
            english: "Help and FAQ"
        )
        case .privacy: return LanguageHelper.localizedText(
            korean: "개인정보 처리방침",
            english: "Privacy Policy"
        )
        case .terms: return LanguageHelper.localizedText(
            korean: "이용약관",
            english: "Terms of Service"
        )
        case .license: return LanguageHelper.localizedText(
            korean: "라이선스 정보",
            english: "License information"
        )
        }
    }
}
