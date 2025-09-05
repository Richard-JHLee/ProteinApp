import SwiftUI

enum MenuItemType: String, CaseIterable {
    case about = "About"
    case userGuide = "User Guide"
    case features = "Features"
    case settings = "Settings"
    case help = "Help"
    case contact = "Contact"
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
        case .contact: return "envelope"
        case .privacy: return "hand.raised"
        case .terms: return "doc.text"
        case .license: return "doc.plaintext"
        }
    }
    
    var description: String {
        switch self {
        case .about: return "앱 정보 및 버전"
        case .userGuide: return "사용 방법 안내"
        case .features: return "주요 기능 소개"
        case .settings: return "앱 설정"
        case .help: return "도움말 및 FAQ"
        case .contact: return "문의하기"
        case .privacy: return "개인정보 처리방침"
        case .terms: return "이용약관"
        case .license: return "라이센스 정보"
        }
    }
}
