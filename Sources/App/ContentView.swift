import SwiftUI

// iPad 사이드바용 메뉴 타입 정의
enum iPadMenuType: String, CaseIterable {
    case mainView = "Main View"
    case proteinLibrary = "Protein Library"
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
        case .mainView: return "atom"
        case .proteinLibrary: return "books.vertical"
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
        case .mainView: return "Protein Viewer"
        case .proteinLibrary: return "Browse protein library"
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

struct ContentView: View {
    @StateObject private var viewModel = ProteinViewModel()
    
    // Size Class 기반 반응형 레이아웃을 위한 환경 변수
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        Group {
            #if os(iOS)
            if horizontalSizeClass == .regular {
                // iPad: NavigationSplitView 기반 레이아웃
                iPadContentView(viewModel: viewModel)
            } else {
                // iPhone: 기존 전체 화면 레이아웃
                iPhoneContentView(viewModel: viewModel)
            }
            #elseif os(macOS)
            // Mac: iPad와 동일한 사이드바-디테일 패턴
            iPadContentView(viewModel: viewModel)
            #endif
        }
        .onAppear {
            print("🚀 ContentView onAppear - horizontalSizeClass: \(horizontalSizeClass == .regular ? "regular" : "compact")")
            print("🚀 ContentView onAppear - structure: \(viewModel.structure != nil ? "loaded" : "nil"), proteinId: \(viewModel.currentProteinId), proteinName: \(viewModel.currentProteinName)")
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("iPhone 15 Pro")
    }
} 
