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
    @State private var structure: PDBStructure? = nil
    @State private var isLoading = false
    @State private var loadingProgress: String = ""
    @State private var error: String? = nil
    @State private var showingProteinLibrary: Bool = false
    @State private var currentProteinId: String = ""
    @State private var currentProteinName: String = ""
    @State private var showingSideMenu: Bool = false
    @State private var is3DStructureLoading = false
    @State private var structureLoadingProgress = ""
    
    // iPad 사이드바용 상태
    @State private var selectedMenu: iPadMenuType = .mainView
    
    // Size Class 기반 반응형 레이아웃을 위한 환경 변수
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad/Mac: 사이드바 + 메인 영역
                NavigationView {
                    // 사이드바
                    iPadSidebarView(
                        selectedMenu: $selectedMenu,
                        onMenuSelected: { menu in
                            selectedMenu = menu
                        }
                    )
                    
                    // 메인 콘텐츠 영역
                    iPadMainContentView(
                        selectedMenu: selectedMenu,
                        structure: $structure,
                        currentProteinId: $currentProteinId,
                        currentProteinName: $currentProteinName,
                        isLoading: $isLoading,
                        loadingProgress: $loadingProgress,
                        error: $error,
                        is3DStructureLoading: $is3DStructureLoading,
                        structureLoadingProgress: $structureLoadingProgress,
                        showingProteinLibrary: $showingProteinLibrary,
                        onProteinLibraryTap: {
                            showingProteinLibrary = true
                        },
                        onLoadSelectedProtein: { proteinId in
                            loadSelectedProtein(proteinId)
                        },
                        onLoadDefaultProtein: {
                            loadDefaultProtein()
                        }
                    )
                }
                .navigationViewStyle(.automatic)
                .fullScreenCover(isPresented: $showingProteinLibrary) {
                    // Protein Library 전체 화면
                    NavigationView {
                        ProteinLibraryView { selectedProteinId in
                            showingProteinLibrary = false
                            is3DStructureLoading = true
                            structureLoadingProgress = "Loading 3D structure for \(selectedProteinId)..."
                            loadSelectedProtein(selectedProteinId)
                            
                            Task {
                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                await MainActor.run {
                                    is3DStructureLoading = false
                                    structureLoadingProgress = ""
                                }
                            }
                        }
                    }
                    .navigationViewStyle(.stack)
                }
                #if os(iOS)
                .preferredColorScheme(.light)
                .statusBarHidden(false)
                .supportedOrientations(.all)
                #elseif os(macOS)
                .frame(minWidth: 800, minHeight: 600)
                #endif
            } else {
                // iPhone: 기존 전체 화면 레이아웃
                NavigationView {
                    ZStack {
                        if let structure = structure {
                            ProteinSceneContainer(
                                structure: structure,
                                proteinId: currentProteinId,
                                proteinName: currentProteinName,
                                onProteinLibraryTap: {
                                    showingProteinLibrary = true
                                },
                                externalIsProteinLoading: $isLoading,
                                externalProteinLoadingProgress: $loadingProgress,
                                externalIs3DStructureLoading: $is3DStructureLoading,
                                externalStructureLoadingProgress: $structureLoadingProgress
                            )
                        } else {
                            VStack(spacing: 20) {
                                if isLoading {
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        
                                        Text("Loading protein structure...")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .dynamicTypeSize(.large)
                                        
                                        if !loadingProgress.isEmpty {
                                            Text(loadingProgress)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal)
                                        }
                                    }
                                } else {
                                    VStack(spacing: 16) {
                                        Image(systemName: "atom")
                                            .font(.system(size: 60))
                                            .foregroundColor(.blue)
                                        
                                        Text("Loading...")
                                            .font(.largeTitle.weight(.bold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Loading default protein structure...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                        }
                        
                        // 3D Structure Loading Overlay
                        if is3DStructureLoading {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .overlay(
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        
                                        Text(structureLoadingProgress.isEmpty ? 
                                            "Loading 3D Structure..." : structureLoadingProgress)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                            .dynamicTypeSize(.large)
                                    }
                                )
                        }
                    }
                    .onAppear {
                        loadDefaultProtein()
                    }
                    .alert("Error", isPresented: .constant(error != nil)) {
                        Button("Retry") {
                            loadDefaultProtein()
                        }
                        .accessibilityLabel("Retry loading protein")
                        Button("OK") {
                            error = nil
                        }
                        .accessibilityLabel("Dismiss error message")
                    } message: {
                        Text(error ?? "")
                    }
                }
                .navigationViewStyle(.stack)
                .navigationBarHidden(true)
                .fullScreenCover(isPresented: $showingProteinLibrary) {
                    // Protein Library 전체 화면
                    NavigationView {
                        ProteinLibraryView { selectedProteinId in
                            showingProteinLibrary = false
                            is3DStructureLoading = true
                            structureLoadingProgress = "Loading 3D structure for \(selectedProteinId)..."
                            loadSelectedProtein(selectedProteinId)
                            
                            Task {
                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                await MainActor.run {
                                    is3DStructureLoading = false
                                    structureLoadingProgress = ""
                                }
                            }
                        }
                    }
                    .navigationViewStyle(.stack)
                }
                #if os(iOS)
                .preferredColorScheme(.light)
                .statusBarHidden(false)
                .supportedOrientations(.all)
                #elseif os(macOS)
                .frame(minWidth: 800, minHeight: 600)
                #endif
            }
        }
    }
    
    private func loadDefaultProtein() {
        isLoading = true
        loadingProgress = "Loading default protein..."
        error = nil
        
        Task {
            do {
                let defaultPdbId = "1CRN"
                print("🔍 Loading default PDB structure: \(defaultPdbId)")
                
                let url = URL(string: "https://files.rcsb.org/download/\(defaultPdbId).pdb")!
                print("📡 Requesting PDB from: \(url)")
                
                await MainActor.run {
                    self.loadingProgress = "Downloading PDB file..."
                }
                
                // 네트워크 요청 타임아웃 설정
                var request = URLRequest(url: url)
                request.timeoutInterval = 30.0
                request.setValue("ProteinApp/1.0", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PDBError.invalidResponse
                }
                
                print("📥 HTTP Response: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 404 {
                        throw PDBError.structureNotFound(defaultPdbId)
                    } else {
                        throw PDBError.serverError(httpResponse.statusCode)
                    }
                }
                
                guard !data.isEmpty else {
                    throw PDBError.emptyResponse
                }
                
                print("📦 Downloaded \(data.count) bytes")
                
                await MainActor.run {
                    self.loadingProgress = "Parsing PDB structure..."
                }
                
                let pdbText = String(decoding: data, as: UTF8.self)
                print("📄 PDB text length: \(pdbText.count) characters")
                
                let loadedStructure = try PDBParser.parse(pdbText: pdbText)
                print("✅ Successfully parsed PDB structure with \(loadedStructure.atomCount) atoms")
                
                // Fetch actual protein name from PDB API
                let actualProteinName = await fetchProteinNameFromPDB(pdbId: defaultPdbId)
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.currentProteinId = defaultPdbId
                    self.currentProteinName = actualProteinName
                    self.isLoading = false
                    self.loadingProgress = ""
                    print("Successfully loaded default PDB structure: \(defaultPdbId) with name: \(actualProteinName)")
                }
            } catch let error as PDBError {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("❌ PDB Error: \(error.localizedDescription)")
            } catch let urlError as URLError {
                await MainActor.run {
                    self.error = urlError.userFriendlyMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("🌐 Network Error: \(urlError.localizedDescription)")
            } catch {
                await MainActor.run {
                    self.error = "Failed to load default protein structure: \(error.localizedDescription)"
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("💥 Unexpected Error: \(error)")
            }
        }
    }
    
    private func loadSelectedProtein(_ pdbId: String) {
        isLoading = true
        loadingProgress = "Initializing..."
        error = nil
        
        Task {
            do {
                // PDB ID 유효성 검사
                let formattedPdbId = pdbId.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard formattedPdbId.count == 4 && formattedPdbId.allSatisfy({ $0.isLetter || $0.isNumber }) else {
                    throw PDBError.invalidPDBID(pdbId)
                }
                
                let url = URL(string: "https://files.rcsb.org/download/\(formattedPdbId).pdb")!
                print("🔍 Loading PDB structure for: \(formattedPdbId)")
                print("📡 Requesting PDB from: \(url)")
                
                await MainActor.run {
                    self.loadingProgress = "Downloading PDB file..."
                }
                
                // 네트워크 요청 타임아웃 설정
                var request = URLRequest(url: url)
                request.timeoutInterval = 30.0
                request.setValue("ProteinApp/1.0", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PDBError.invalidResponse
                }
                
                print("📥 HTTP Response: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 404 {
                        throw PDBError.structureNotFound(formattedPdbId)
                    } else {
                        throw PDBError.serverError(httpResponse.statusCode)
                    }
                }
                
                guard !data.isEmpty else {
                    throw PDBError.emptyResponse
                }
                
                print("📦 Downloaded \(data.count) bytes")
                
                await MainActor.run {
                    self.loadingProgress = "Parsing PDB structure..."
                }
                
                let pdbText = String(decoding: data, as: UTF8.self)
                print("📄 PDB text length: \(pdbText.count) characters")
                
                let loadedStructure = try PDBParser.parse(pdbText: pdbText)
                print("✅ Successfully parsed PDB structure with \(loadedStructure.atomCount) atoms")
                
                // Fetch actual protein name from PDB API
                let actualProteinName = await fetchProteinNameFromPDB(pdbId: formattedPdbId)
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.currentProteinId = formattedPdbId
                    self.currentProteinName = actualProteinName
                    self.isLoading = false
                    self.loadingProgress = ""
                    print("Successfully loaded PDB structure: \(formattedPdbId) with name: \(actualProteinName)")
                }
            } catch let error as PDBError {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("❌ PDB Error: \(error.localizedDescription)")
            } catch let urlError as URLError {
                await MainActor.run {
                    self.error = urlError.userFriendlyMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("🌐 Network Error: \(urlError.localizedDescription)")
            } catch {
                await MainActor.run {
                    self.error = "Failed to load protein structure for \(pdbId): \(error.localizedDescription)"
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("💥 Unexpected Error: \(error)")
            }
        }
    }
    
    private func getProteinName(from pdbId: String) -> String {
        // Common protein names mapping (fallback for known proteins)
        let proteinNames: [String: String] = [
            "1CRN": "Crambin",
            "1TUB": "Tubulin",
            "1HHO": "Hemoglobin",
            "1INS": "Insulin",
            "1LYZ": "Lysozyme",
            "1GFL": "Green Fluorescent Protein",
            "1UBQ": "Ubiquitin",
            "1PGA": "Protein G",
            "1TIM": "Triosephosphate Isomerase",
            "1AKE": "Adenylate Kinase"
        ]
        
        return proteinNames[pdbId] ?? "Protein \(pdbId)"
    }
    
    // MARK: - PDB API Integration
    private func fetchProteinNameFromPDB(pdbId: String) async -> String {
        do {
            let name = try await loadProteinNameFromRCSB(pdbId: pdbId)
            return name.isEmpty ? "Protein \(pdbId)" : name
        } catch {
            print("⚠️ Failed to fetch protein name from PDB: \(error.localizedDescription)")
            return "Protein \(pdbId)"
        }
    }
    
    private func loadProteinNameFromRCSB(pdbId: String) async throws -> String {
        let id = pdbId.uppercased()
        guard let url = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(id)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Parse JSON response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Extract title from struct field
        if let structData = json?["struct"] as? [String: Any],
           let title = structData["title"] as? String,
           !title.isEmpty {
            
            // Clean up the title
            let cleanTitle = title
                .replacingOccurrences(of: "CRYSTAL STRUCTURE OF", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "X-RAY STRUCTURE OF", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "NMR STRUCTURE OF", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanTitle.isEmpty ? "Protein \(pdbId)" : cleanTitle
        }
        
        return "Protein \(pdbId)"
    }
}

#if os(iOS)
extension View {
    func supportedOrientations(_ orientations: UIInterfaceOrientationMask) -> some View {
        self.onAppear {
            AppDelegate.orientationLock = orientations
        }
    }
}
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.allButUpsideDown
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

// MARK: - iPad Sidebar View
struct iPadSidebarView: View {
    @Binding var selectedMenu: iPadMenuType
    let onMenuSelected: (iPadMenuType) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            sidebarHeader
            
            // 메뉴 아이템 리스트
            List(iPadMenuType.allCases, id: \.self) { menuItem in
                iPadMenuItemRow(
                    item: menuItem,
                    isSelected: selectedMenu == menuItem
                ) {
                    onMenuSelected(menuItem)
                }
            }
            .listStyle(SidebarListStyle())
        }
        .frame(minWidth: 250)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Header
    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "atom")
                .font(.system(size: 32))
                .foregroundColor(.blue)
            
            Text("ProteinApp")
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            
            Text("Protein Structure Viewer")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

struct iPadMenuItemRow: View {
    let item: iPadMenuType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 아이콘
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 24, height: 24)
                
                // 텍스트
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iPad Main Content View
struct iPadMainContentView: View {
    let selectedMenu: iPadMenuType
    @Binding var structure: PDBStructure?
    @Binding var currentProteinId: String
    @Binding var currentProteinName: String
    @Binding var isLoading: Bool
    @Binding var loadingProgress: String
    @Binding var error: String?
    @Binding var is3DStructureLoading: Bool
    @Binding var structureLoadingProgress: String
    @Binding var showingProteinLibrary: Bool
    
    let onProteinLibraryTap: () -> Void
    let onLoadSelectedProtein: (String) -> Void
    let onLoadDefaultProtein: () -> Void
    
    var body: some View {
        Group {
            switch selectedMenu {
            case .mainView:
                // 메인 Protein Viewer 화면
                mainProteinView
            case .proteinLibrary:
                // Protein Library 화면
                ProteinLibraryView { selectedProteinId in
                    onLoadSelectedProtein(selectedProteinId)
                }
            case .about:
                AboutView()
            case .userGuide:
                UserGuideView()
            case .features:
                FeaturesView()
            case .settings:
                SettingsView()
            case .help:
                HelpView()
            case .privacy:
                PrivacyView()
            case .terms:
                TermsView()
            case .license:
                LicenseView()
            }
        }
        .navigationTitle(selectedMenu.rawValue)
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Main Protein View
    private var mainProteinView: some View {
        ZStack {
            if let structure = structure {
                ProteinSceneContainer(
                    structure: structure,
                    proteinId: currentProteinId,
                    proteinName: currentProteinName,
                    onProteinLibraryTap: onProteinLibraryTap,
                    externalIsProteinLoading: $isLoading,
                    externalProteinLoadingProgress: $loadingProgress,
                    externalIs3DStructureLoading: $is3DStructureLoading,
                    externalStructureLoadingProgress: $structureLoadingProgress
                )
            } else {
                VStack(spacing: 20) {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            
                            Text("Loading protein structure...")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .dynamicTypeSize(.large)
                            
                            if !loadingProgress.isEmpty {
                                Text(loadingProgress)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "atom")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Loading...")
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.primary)
                            
                            Text("Loading default protein structure...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
            
            // 3D Structure Loading Overlay
            if is3DStructureLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text(structureLoadingProgress.isEmpty ? 
                                "Loading 3D Structure..." : structureLoadingProgress)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .dynamicTypeSize(.large)
                        }
                    )
            }
        }
        .onAppear {
            if structure == nil {
                onLoadDefaultProtein()
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("Retry") {
                onLoadDefaultProtein()
            }
            .accessibilityLabel("Retry loading protein")
            Button("OK") {
                error = nil
            }
            .accessibilityLabel("Dismiss error message")
        } message: {
            Text(error ?? "")
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
