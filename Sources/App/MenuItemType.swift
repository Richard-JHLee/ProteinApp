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
        case .about: return "App information and version"
        case .userGuide: return "User guide"
        case .features: return "Key features"
        case .settings: return "App settings"
        case .help: return "Help and FAQ"
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms of Service"
        case .license: return "License information"
        }
    }
}
