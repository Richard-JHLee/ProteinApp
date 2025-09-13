import SwiftUI

// MARK: - iPad Content View with Sidebar-Detail Pattern
struct iPadContentView: View {
    @ObservedObject var viewModel: ProteinViewModel
    @StateObject private var navigationState = iPadNavigationState()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: 사이드바-디테일 패턴
            NavigationView {
                // Master: 사이드바
                SidebarView(
                    navigationState: navigationState,
                    viewModel: viewModel
                )
                
                // Detail: 선택에 따라 변하는 화면
                DetailView(
                    navigationState: navigationState,
                    viewModel: viewModel
                )
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
        } else {
            // iPhone: 스택 네비게이션 (fallback)
            NavigationView {
                iPhoneContentView(viewModel: viewModel)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

// MARK: - Navigation State Management
class iPadNavigationState: ObservableObject {
    @Published var selectedMenu: MenuType? = .proteinViewer
    
    func selectMenu(_ menu: MenuType) {
        selectedMenu = menu
    }
}

// MARK: - Menu Types
enum MenuType: String, CaseIterable {
    case proteinViewer = "Protein Viewer"
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
        case .proteinViewer: return "atom"
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
}

// MARK: - Sidebar View (Master)
struct SidebarView: View {
    @ObservedObject var navigationState: iPadNavigationState
    @ObservedObject var viewModel: ProteinViewModel
    
    var body: some View {
        List {
            // App Header
            Section {
                AppHeaderView()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
            
            // Main Navigation
            Section("Main") {
                ForEach(MenuType.allCases.filter { isMainMenu($0) }, id: \.self) { menu in
                    NavigationLink(
                        destination: DetailView(
                            navigationState: navigationState,
                            viewModel: viewModel
                        ),
                        tag: menu,
                        selection: $navigationState.selectedMenu
                    ) {
                        HStack {
                            Image(systemName: menu.icon)
                                .foregroundColor(navigationState.selectedMenu == menu ? .white : .primary)
                            Text(menu.rawValue)
                                .foregroundColor(navigationState.selectedMenu == menu ? .white : .primary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(navigationState.selectedMenu == menu ? Color.blue : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Information Navigation
            Section("Information") {
                ForEach(MenuType.allCases.filter { !isMainMenu($0) }, id: \.self) { menu in
                    NavigationLink(
                        destination: DetailView(
                            navigationState: navigationState,
                            viewModel: viewModel
                        ),
                        tag: menu,
                        selection: $navigationState.selectedMenu
                    ) {
                        HStack {
                            Image(systemName: menu.icon)
                                .foregroundColor(navigationState.selectedMenu == menu ? .white : .primary)
                            Text(menu.rawValue)
                                .foregroundColor(navigationState.selectedMenu == menu ? .white : .primary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(navigationState.selectedMenu == menu ? Color.blue : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Current Protein Info (if loaded)
            if let structure = viewModel.structure {
                Section("Current Protein") {
                    CurrentProteinCard(
                        proteinId: viewModel.currentProteinId,
                        proteinName: viewModel.currentProteinName,
                        atomCount: structure.atoms.count
                    )
                    .listRowInsets(EdgeInsets())
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private func isMainMenu(_ menu: MenuType) -> Bool {
        switch menu {
        case .proteinViewer:
            return true
        case .about, .userGuide, .features, .settings, .help, .privacy, .terms, .license:
            return false
        }
    }
}

// MARK: - Detail View
struct DetailView: View {
    @ObservedObject var navigationState: iPadNavigationState
    @ObservedObject var viewModel: ProteinViewModel
    
    var body: some View {
        Group {
            switch navigationState.selectedMenu {
            case .proteinViewer:
                ProteinViewerDetailView(viewModel: viewModel)
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
            case .none:
                ProteinViewerDetailView(viewModel: viewModel)
            }
        }
        .navigationTitle(navigationState.selectedMenu?.rawValue ?? "ProteinApp")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Simple Protein Scene View for iPad Detail View
struct SimpleProteinSceneView: View {
    let structure: PDBStructure
    let proteinId: String
    let proteinName: String
    
    @State private var selectedStyle: RenderStyle = .spheres
    @State private var selectedColorMode: ColorMode = .element
    @State private var selectedTab: InfoTabType = .overview
    
    // 3D View controls
    @State private var autoRotate: Bool = false
    @State private var zoomLevel: Double = 2.0  // 아이패드용 2배 크기
    @State private var transparency: Double = 1.0
    @State private var atomSize: Double = 1.0
    
    // Highlight and Focus states
    @State private var highlightedChains: Set<String> = []
    @State private var highlightedLigands: Set<String> = []
    @State private var highlightedPockets: Set<String> = []
    @State private var focusedElement: FocusedElement? = nil
    @State private var isFocused: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let screenHeight = geometry.size.height
            
            // 가로/세로 모드에 따른 동적 크기 계산
            let viewerHeight: CGFloat = isLandscape ? screenHeight * 0.6 : screenHeight * 0.4
            let infoHeight: CGFloat = isLandscape ? screenHeight * 0.4 : screenHeight * 0.6
            
            ScrollView {
                VStack(spacing: 0) {
                    // 탭 메뉴
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(InfoTabType.allCases, id: \.self) { tab in
                                    Button(action: {
                                        selectedTab = tab
                                    }) {
                                        VStack(spacing: 4) {
                                            Text(tab.rawValue)
                                                .font(isLandscape ? .headline : .subheadline)
                                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                                .foregroundColor(selectedTab == tab ? .blue : .primary)
                                            
                                            Rectangle()
                                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                                                .frame(height: 2)
                                        }
                                        .padding(.horizontal, isLandscape ? 16 : 12)
                                        .padding(.vertical, isLandscape ? 8 : 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, isLandscape ? 20 : 16)
                        }
                        .padding(.vertical, isLandscape ? 12 : 8)
                        .background(Color(.systemBackground))
                        
                        // Style과 Color Mode 선택기
                        HStack(spacing: 20) {
                            // Render Style 선택
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Style")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("Style", selection: $selectedStyle) {
                                    ForEach(RenderStyle.allCases, id: \.self) { style in
                                        Text(style.rawValue)
                                            .font(.caption)
                                            .tag(style)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 300)
                            }
                            
                            // Color Mode 선택
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Color")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("Color", selection: $selectedColorMode) {
                                    ForEach(ColorMode.allCases, id: \.self) { colorMode in
                                        Text(colorMode.rawValue)
                                            .font(.caption)
                                            .tag(colorMode)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 300)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, isLandscape ? 20 : 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGroupedBackground))
                    }
                    
                    // 3D 뷰어와 정보 영역
                    VStack(spacing: 0) {
                        // 3D 뷰어 (상단)
                        ZStack {
                            // 실제 3D SceneKit 뷰
                            ProteinSceneView(
                                structure: structure,
                                style: selectedStyle,
                                colorMode: selectedColorMode,
                                uniformColor: .blue,
                                autoRotate: autoRotate,
                                isInfoMode: false,
                                showInfoBar: .constant(false),
                                onSelectAtom: nil,
                                highlightedChains: highlightedChains,
                                highlightedLigands: highlightedLigands,
                                highlightedPockets: highlightedPockets,
                                focusedElement: focusedElement,
                                onFocusRequest: { element in
                                    focusedElement = element
                                    isFocused = true
                                },
                                isRendering3D: .constant(false),
                                renderingProgress: .constant(""),
                                zoomLevel: zoomLevel,
                                transparency: transparency,
                                atomSize: atomSize
                            )
                            
                            // 3D View Controls overlay
                            VStack {
                                HStack {
                                    // Highlight/Focus status
                                    if let focusElement = focusedElement {
                                        HStack(spacing: 6) {
                                            Image(systemName: "scope.fill")
                                                .font(.callout)
                                                .foregroundColor(.green)
                                            Text("Focused: \(focusElement.displayName)")
                                                .font(.callout)
                                                .fontWeight(.medium)
                                                .foregroundColor(.green)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(16)
                                    }
                                    
                                    if !highlightedChains.isEmpty || !highlightedLigands.isEmpty || !highlightedPockets.isEmpty || isFocused {
                                        Button(action: {
                                            highlightedChains.removeAll()
                                            highlightedLigands.removeAll()
                                            highlightedPockets.removeAll()
                                            focusedElement = nil
                                            isFocused = false
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.callout)
                                                Text("Clear All")
                                                    .font(.callout)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(16)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // 3D View Controls
                                    HStack(spacing: 12) {
                                        // Auto Rotate Toggle
                                        Button(action: {
                                            autoRotate.toggle()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: autoRotate ? "rotate.3d.fill" : "rotate.3d")
                                                    .font(.callout)
                                                Text("Rotate")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(autoRotate ? .white : .orange)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(autoRotate ? Color.orange : Color.orange.opacity(0.1))
                                            .cornerRadius(12)
                                        }
                                        
                                        // Zoom Reset
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                zoomLevel = 2.0
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "magnifyingglass")
                                                    .font(.callout)
                                                Text("Reset")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                
                                Spacer()
                            }
                        }
                        .frame(height: viewerHeight) // 동적 높이
                        
                        // 선택된 탭에 따른 정보 표시 (하단)
                        VStack(spacing: 16) {
                            switch selectedTab {
                            case .overview:
                                OverviewTabContent(structure: structure)
                            case .chains:
                                ChainsTabContent(
                                    structure: structure,
                                    highlightedChains: $highlightedChains,
                                    focusedElement: $focusedElement,
                                    isFocused: $isFocused
                                )
                            case .residues:
                                ResiduesTabContent(structure: structure)
                            case .ligands:
                                LigandsTabContent(
                                    structure: structure,
                                    highlightedLigands: $highlightedLigands,
                                    focusedElement: $focusedElement,
                                    isFocused: $isFocused
                                )
                            case .pockets:
                                PocketsTabContent(
                                    structure: structure,
                                    highlightedPockets: $highlightedPockets,
                                    focusedElement: $focusedElement,
                                    isFocused: $isFocused
                                )
                            case .sequence:
                                SequenceTabContent(structure: structure)
                            case .annotations:
                                AnnotationsTabContent(structure: structure)
                            }
                        }
                        .padding(isLandscape ? 20 : 16)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: infoHeight) // 동적 최소 높이
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
        }
    }
}


// MARK: - Protein Viewer Detail View
struct ProteinViewerDetailView: View {
    @ObservedObject var viewModel: ProteinViewModel
    @State private var showingProteinLibrary = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더 영역 (타이틀 제거, 버튼만 유지)
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showingProteinLibrary = true
                    }) {
                        Image(systemName: "books.vertical")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemBackground))
            
            // 3D 뷰어 영역
            if let structure = viewModel.structure {
                SimpleProteinSceneView(
                    structure: structure,
                    proteinId: viewModel.currentProteinId,
                    proteinName: viewModel.currentProteinName
                )
            } else if viewModel.isLoading {
                // 로딩 화면
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    
                    Text("Loading protein structure...")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !viewModel.loadingProgress.isEmpty {
                        Text(viewModel.loadingProgress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                // 초기 화면
                VStack(spacing: 16) {
                    Image(systemName: "atom")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to ProteinApp")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("Select a protein from the library to view its 3D structure")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Open Protein Library") {
                        showingProteinLibrary = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
        .onAppear {
            if viewModel.structure == nil && !viewModel.isLoading {
                viewModel.loadDefaultProtein()
            }
        }
        .sheet(isPresented: $showingProteinLibrary) {
            NavigationView {
                ProteinLibraryView { selectedProteinId in
                    viewModel.loadSelectedProtein(selectedProteinId)
                    showingProteinLibrary = false
                }
            }
        }
    }
}

// MARK: - Other Detail Views
struct LibraryDetailView: View {
    @ObservedObject var viewModel: ProteinViewModel
    
    var body: some View {
        ProteinLibraryView { selectedProteinId in
            viewModel.loadSelectedProtein(selectedProteinId)
        }
    }
}

struct AnalysisDetailView: View {
    @ObservedObject var viewModel: ProteinViewModel
    
    var body: some View {
        VStack {
            Text("Analysis Tools")
                .font(.largeTitle)
                .padding()
            
            Text("Protein analysis tools will be available here")
                .foregroundColor(.secondary)
        }
    }
}

struct SettingsDetailView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()
            
            Text("App settings will be available here")
                .foregroundColor(.secondary)
        }
    }
}

struct AboutDetailView: View {
    var body: some View {
        VStack {
            Text("About ProteinApp")
                .font(.largeTitle)
                .padding()
            
            Text("Protein structure visualization and analysis app")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Views

struct AppHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "atom")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 4) {
                Text("ProteinApp")
                    .font(.title.weight(.bold))
                
                Text("Structure Analysis & Visualization")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

struct CurrentProteinCard: View {
    let proteinId: String
    let proteinName: String
    let atomCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "atom")
                    .foregroundColor(.blue)
                
                Text(proteinId)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(proteinName)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text("\(atomCount) atoms")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Tab Content Views
struct OverviewTabContent: View {
    let structure: PDBStructure
    
    var body: some View {
        VStack(spacing: 16) {
            // Basic statistics with enhanced information
            HStack(spacing: 16) {
                StatCard(title: "Atoms", value: "\(structure.atoms.count)", color: .blue)
                StatCard(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", color: .green)
                StatCard(title: "Residues", value: "\(Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count)", color: .orange)
            }
            
            // Structure Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Structure Information")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    InfoRow(title: "PDB ID", value: "1CRN", description: "Protein Data Bank identifier - unique code for this structure")
                    InfoRow(title: "Total Atoms", value: "\(structure.atoms.count)", description: "All atoms in the structure including protein and ligands")
                    InfoRow(title: "Total Bonds", value: "\(structure.bonds.count)", description: "Chemical bonds connecting atoms in the structure")
                    InfoRow(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", description: "Number of polypeptide chains in the protein")
                    
                    let uniqueElements = Set(structure.atoms.map { $0.element })
                    InfoRow(title: "Elements", value: "\(uniqueElements.count)", description: "Number of different chemical elements present")
                    
                    let elementTypes = Array(uniqueElements).sorted().joined(separator: ", ")
                    InfoRow(title: "Element Types", value: elementTypes, description: "Chemical elements found in this structure")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            
            // Chemical Composition
            VStack(alignment: .leading, spacing: 12) {
                Text("Chemical Composition")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    let uniqueResidues = Set(structure.atoms.map { $0.residueName })
                    InfoRow(title: "Residue Types", value: "\(uniqueResidues.count)", description: "Number of different amino acid types present")
                    
                    let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
                    InfoRow(title: "Total Residues", value: "\(totalResidues)", description: "Total number of amino acid residues across all chains")
                    
                    let chainList = Array(Set(structure.atoms.map { $0.chain })).sorted()
                    InfoRow(title: "Chain IDs", value: chainList.joined(separator: ", "), description: "Identifiers for all polypeptide chains")
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct ChainsTabContent: View {
    let structure: PDBStructure
    @Binding var highlightedChains: Set<String>
    @Binding var focusedElement: FocusedElement?
    @Binding var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            let chains = Set(structure.atoms.map { $0.chain })
            
            ForEach(Array(chains).sorted(), id: \.self) { chain in
                let chainAtoms = structure.atoms.filter { $0.chain == chain }
                let residues = Set(chainAtoms.map { "\($0.chain):\($0.residueNumber)" })
                let uniqueResidues = Set(chainAtoms.map { $0.residueName })
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chain \(chain)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Chain overview
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Length")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(residues.count) residues")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(chainAtoms.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Residue Types")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(uniqueResidues.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    
                    // Sequence information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sequence Information")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        let sortedResidues = chainAtoms
                            .sorted { $0.residueNumber < $1.residueNumber }
                            .map { $0.residueName }
                        
                        Text(sortedResidues.joined(separator: "-"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Highlight and Focus buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            if highlightedChains.contains(chain) {
                                highlightedChains.remove(chain)
                            } else {
                                highlightedChains.insert(chain)
                            }
                            // 3D 뷰어는 자동으로 업데이트되므로 강제 렌더링 불필요
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: highlightedChains.contains(chain) ? "pencil.and.outline" : "pencil")
                                Text(highlightedChains.contains(chain) ? "Unhighlight" : "Highlight")
                            }
                            .font(.caption)
                            .foregroundColor(highlightedChains.contains(chain) ? .white : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(highlightedChains.contains(chain) ? Color.blue : Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Button(action: {
                            if let currentFocus = focusedElement,
                               case .chain(let currentChain) = currentFocus,
                               currentChain == chain {
                                focusedElement = nil
                                isFocused = false
                            } else {
                                focusedElement = .chain(chain)
                                isFocused = true
                            }
                            // 3D 뷰어는 자동으로 업데이트되므로 강제 렌더링 불필요
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: {
                                    if let currentFocus = focusedElement,
                                       case .chain(let currentChain) = currentFocus {
                                        return currentChain == chain ? "scope.fill" : "scope"
                                    }
                                    return "scope"
                                }())
                                Text({
                                    if let currentFocus = focusedElement,
                                       case .chain(let currentChain) = currentFocus {
                                        return currentChain == chain ? "Unfocus" : "Focus"
                                    }
                                    return "Focus"
                                }())
                            }
                            .font(.caption)
                            .foregroundColor({
                                if let currentFocus = focusedElement,
                                   case .chain(let currentChain) = currentFocus {
                                    return currentChain == chain ? .white : .green
                                }
                                return .green
                            }())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background({
                                if let currentFocus = focusedElement,
                                   case .chain(let currentChain) = currentFocus {
                                    return currentChain == chain ? Color.green : Color.green.opacity(0.1)
                                }
                                return Color.green.opacity(0.1)
                            }())
                            .cornerRadius(16)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
    }
}

struct ResiduesTabContent: View {
    let structure: PDBStructure
    
    var body: some View {
        VStack(spacing: 16) {
            // Residue composition overview with bar charts
            VStack(alignment: .leading, spacing: 12) {
                Text("Residue Composition")
                    .font(.headline)
                
                let residueCounts = Dictionary(grouping: structure.atoms, by: { $0.residueName })
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }
                
                let totalResidues = residueCounts.map { $0.value }.reduce(0, +)
                
                VStack(spacing: 8) {
                    ForEach(Array(residueCounts.prefix(15)), id: \.key) { residue, count in
                        HStack {
                            Text(residue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .leading)
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            Spacer()
                            
                            let percentage = Double(count) / Double(totalResidues) * 100
                            Rectangle()
                                .fill(residueColor(residue))
                                .frame(width: CGFloat(percentage) * 3, height: 20)
                                .cornerRadius(4)
                            
                            Text("\(String(format: "%.1f", percentage))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Physical-chemical properties
            VStack(alignment: .leading, spacing: 12) {
                Text("Physical-Chemical Properties")
                    .font(.headline)
                
                let hydrophobicResidues = ["ALA", "VAL", "ILE", "LEU", "MET", "PHE", "TRP", "PRO"]
                let polarResidues = ["SER", "THR", "ASN", "GLN", "TYR", "CYS"]
                let chargedResidues = ["LYS", "ARG", "HIS", "ASP", "GLU"]
                
                let hydrophobicCount = structure.atoms.filter { hydrophobicResidues.contains($0.residueName) }.count
                let polarCount = structure.atoms.filter { polarResidues.contains($0.residueName) }.count
                let chargedCount = structure.atoms.filter { chargedResidues.contains($0.residueName) }.count
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Hydrophobic")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(hydrophobicCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Polar")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(polarCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Charged")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(chargedCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Structural roles
            VStack(alignment: .leading, spacing: 12) {
                Text("Structural Roles")
                    .font(.headline)
                
                let helixResidues = ["ALA", "GLU", "LEU", "MET"]
                let sheetResidues = ["VAL", "ILE", "TYR", "PHE", "TRP"]
                let turnResidues = ["PRO", "GLY", "SER", "ASN"]
                
                let helixCount = structure.atoms.filter { helixResidues.contains($0.residueName) }.count
                let sheetCount = structure.atoms.filter { sheetResidues.contains($0.residueName) }.count
                let turnCount = structure.atoms.filter { turnResidues.contains($0.residueName) }.count
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Helix-forming")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                        Spacer()
                        Text("\(helixCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Sheet-forming")
                            .font(.subheadline)
                            .foregroundColor(.brown)
                        Spacer()
                        Text("\(sheetCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Turn-forming")
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("\(turnCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func residueColor(_ residue: String) -> Color {
        let hydrophobicResidues = ["ALA", "VAL", "ILE", "LEU", "MET", "PHE", "TRP", "PRO"]
        let polarResidues = ["SER", "THR", "ASN", "GLN", "TYR", "CYS"]
        let chargedResidues = ["LYS", "ARG", "HIS", "ASP", "GLU"]
        
        if hydrophobicResidues.contains(residue) {
            return .orange
        } else if polarResidues.contains(residue) {
            return .blue
        } else if chargedResidues.contains(residue) {
            return .red
        } else {
            return .gray
        }
    }
}

struct LigandsTabContent: View {
    let structure: PDBStructure
    @Binding var highlightedLigands: Set<String>
    @Binding var focusedElement: FocusedElement?
    @Binding var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            let ligands = structure.atoms.filter { $0.isLigand }
            let ligandGroups = Dictionary(grouping: ligands, by: { $0.residueName })
            
            if ligands.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "molecule")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Ligands Detected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This structure does not contain any small molecules or ions bound to the protein.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Ligand overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ligand Overview")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Ligands")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(ligandGroups.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(ligands.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Individual ligands
                ForEach(Array(ligandGroups.keys).sorted(), id: \.self) { ligandName in
                    let ligandAtoms = ligandGroups[ligandName] ?? []
                    let uniqueChains = Set(ligandAtoms.map { $0.chain })
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ligandName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Ligand information
                        VStack(spacing: 8) {
                            HStack {
                                Text("Atoms")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(ligandAtoms.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Chains")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Array(uniqueChains).sorted().joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // Element composition
                            let elementCounts = Dictionary(grouping: ligandAtoms, by: { $0.element })
                                .mapValues { $0.count }
                                .sorted { $0.value > $1.value }
                            
                            HStack {
                                Text("Elements")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(elementCounts.map { "\($0.key)\($0.value)" }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Highlight button
                        Button(action: {
                            if highlightedLigands.contains(ligandName) {
                                highlightedLigands.remove(ligandName)
                            } else {
                                highlightedLigands.insert(ligandName)
                            }
                            // 3D 뷰어는 자동으로 업데이트되므로 강제 렌더링 불필요
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: highlightedLigands.contains(ligandName) ? "highlighter.fill" : "highlighter")
                                Text(highlightedLigands.contains(ligandName) ? "Unhighlight" : "Highlight")
                            }
                            .font(.caption)
                            .foregroundColor(highlightedLigands.contains(ligandName) ? .white : .orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(highlightedLigands.contains(ligandName) ? Color.orange : Color.orange.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
        }
    }
}

struct PocketsTabContent: View {
    let structure: PDBStructure
    @Binding var highlightedPockets: Set<String>
    @Binding var focusedElement: FocusedElement?
    @Binding var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            let pockets = structure.atoms.filter { $0.isPocket }
            let pocketGroups = Dictionary(grouping: pockets, by: { $0.residueName })
            
            if pockets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Binding Pockets Detected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This structure does not contain any identified binding pockets or active sites.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Pocket overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Binding Pocket Overview")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Pockets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pocketGroups.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pockets.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
                
                // Individual pockets
                ForEach(Array(pocketGroups.keys).sorted(), id: \.self) { pocketName in
                    let pocketAtoms = pocketGroups[pocketName] ?? []
                    let uniqueChains = Set(pocketAtoms.map { $0.chain })
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(pocketName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Pocket information
                        VStack(spacing: 8) {
                            HStack {
                                Text("Atoms")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(pocketAtoms.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Chains")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Array(uniqueChains).sorted().joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // Element composition
                            let elementCounts = Dictionary(grouping: pocketAtoms, by: { $0.element })
                                .mapValues { $0.count }
                                .sorted { $0.value > $1.value }
                            
                            HStack {
                                Text("Elements")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(elementCounts.map { "\($0.key)\($0.value)" }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Highlight and Focus buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                if highlightedPockets.contains(pocketName) {
                                    highlightedPockets.remove(pocketName)
                                } else {
                                    highlightedPockets.insert(pocketName)
                                }
                                // 3D 뷰어는 자동으로 업데이트되므로 강제 렌더링 불필요
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: highlightedPockets.contains(pocketName) ? "circle.dotted.fill" : "circle.dotted")
                                    Text(highlightedPockets.contains(pocketName) ? "Unhighlight" : "Highlight")
                                }
                                .font(.caption)
                                .foregroundColor(highlightedPockets.contains(pocketName) ? .white : .purple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(highlightedPockets.contains(pocketName) ? Color.purple : Color.purple.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                if let currentFocus = focusedElement,
                                   case .pocket(let currentPocket) = currentFocus,
                                   currentPocket == pocketName {
                                    focusedElement = nil
                                    isFocused = false
                                } else {
                                    focusedElement = .pocket(pocketName)
                                    isFocused = true
                                }
                                // 3D 뷰어는 자동으로 업데이트되므로 강제 렌더링 불필요
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: {
                                        if let currentFocus = focusedElement,
                                           case .pocket(let currentPocket) = currentFocus {
                                            return currentPocket == pocketName ? "scope.fill" : "scope"
                                        }
                                        return "scope"
                                    }())
                                    Text({
                                        if let currentFocus = focusedElement,
                                           case .pocket(let currentPocket) = currentFocus {
                                            return currentPocket == pocketName ? "Unfocus" : "Focus"
                                        }
                                        return "Focus"
                                    }())
                                }
                                .font(.caption)
                                .foregroundColor({
                                    if let currentFocus = focusedElement,
                                       case .pocket(let currentPocket) = currentFocus {
                                        return currentPocket == pocketName ? .white : .green
                                    }
                                    return .green
                                }())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background({
                                    if let currentFocus = focusedElement,
                                       case .pocket(let currentPocket) = currentFocus {
                                        return currentPocket == pocketName ? Color.green : Color.green.opacity(0.1)
                                    }
                                    return Color.green.opacity(0.1)
                                }())
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
        }
    }
}

struct SequenceTabContent: View {
    let structure: PDBStructure
    
    var body: some View {
        let chains = Set(structure.atoms.map { $0.chain })
        let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
        
        return VStack(spacing: 16) {
            // Sequence overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Sequence Overview")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chains")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(chains.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Residues")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalResidues)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Individual chain sequences
            ForEach(Array(chains).sorted(), id: \.self) { chain in
                let chainAtoms = structure.atoms
                    .filter { $0.chain == chain }
                    .sorted { $0.residueNumber < $1.residueNumber }
                
                let uniqueResidues = Array(Set(chainAtoms.map { $0.residueNumber })).sorted()
                let sequence = uniqueResidues.map { resNum in
                    let resName = chainAtoms.first { $0.residueNumber == resNum }?.residueName ?? "X"
                    return residue3to1(resName)
                }.joined()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chain \(chain) Sequence")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Sequence information
                    HStack {
                        Text("Length: \(sequence.count) amino acids")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Residues: \(uniqueResidues.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Full sequence display
                    ScrollView {
                        Text(sequence)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                    
                    // Sequence composition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sequence Composition")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        let chainResidues = chainAtoms.map { $0.residueName }
                        let composition = Dictionary(grouping: chainResidues, by: { $0 })
                            .mapValues { $0.count }
                            .sorted { $0.value > $1.value }
                        
                        ForEach(Array(composition.prefix(10)), id: \.key) { residue, count in
                            HStack {
                                Text(residue)
                                    .font(.caption)
                                    .frame(width: 50, alignment: .leading)
                                
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                Spacer()
                                
                                // Visual bar
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: CGFloat(count) * 2, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
        }
    }
    
    private func residue3to1(_ code: String) -> String {
        switch code.uppercased() {
        case "ALA": return "A"
        case "ARG": return "R"
        case "ASN": return "N"
        case "ASP": return "D"
        case "CYS": return "C"
        case "GLN": return "Q"
        case "GLU": return "E"
        case "GLY": return "G"
        case "HIS": return "H"
        case "ILE": return "I"
        case "LEU": return "L"
        case "LYS": return "K"
        case "MET": return "M"
        case "PHE": return "F"
        case "PRO": return "P"
        case "SER": return "S"
        case "THR": return "T"
        case "TRP": return "W"
        case "TYR": return "Y"
        case "VAL": return "V"
        default: return "X"
        }
    }
}

struct AnnotationsTabContent: View {
    let structure: PDBStructure
    
    var body: some View {
        VStack(spacing: 16) {
            // Structure Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Structure Information")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "PDB ID", value: "1CRN", description: "Protein Data Bank identifier - unique code for this structure")
                    InfoRow(title: "Total Atoms", value: "\(structure.atoms.count)", description: "All atoms in the structure including protein and ligands")
                    InfoRow(title: "Total Bonds", value: "\(structure.bonds.count)", description: "Chemical bonds connecting atoms in the structure")
                    InfoRow(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", description: "Number of polypeptide chains in the protein")
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // Chemical Composition
            VStack(alignment: .leading, spacing: 12) {
                Text("Chemical Composition")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueElements = Set(structure.atoms.map { $0.element })
                    InfoRow(title: "Elements", value: "\(uniqueElements.count)", description: "Number of different chemical elements present")
                    
                    let elementList = Array(uniqueElements).sorted().joined(separator: ", ")
                    InfoRow(title: "Element Types", value: elementList, description: "Chemical elements found in this structure")
                    
                    let chainList = Array(Set(structure.atoms.map { $0.chain })).sorted()
                    InfoRow(title: "Chain IDs", value: chainList.joined(separator: ", "), description: "Identifiers for each polypeptide chain")
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // Protein Classification
            VStack(alignment: .leading, spacing: 12) {
                Text("Protein Classification")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueResidues = Set(structure.atoms.map { $0.residueName })
                    InfoRow(title: "Residue Types", value: "\(uniqueResidues.count)", description: "Number of different amino acid types present")
                    
                    let residueList = Array(uniqueResidues).sorted().joined(separator: ", ")
                    InfoRow(title: "Residue Names", value: residueList, description: "Three-letter codes of amino acids in this protein")
                    
                    let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
                    InfoRow(title: "Total Residues", value: "\(totalResidues)", description: "Total number of amino acid residues across all chains")
                }
            }
            .padding()
            .background(Color.cyan.opacity(0.1))
            .cornerRadius(12)
            
            // Biological Context
            VStack(alignment: .leading, spacing: 12) {
                Text("Biological Context")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "Structure Type", value: "Protein", description: "This is a protein structure determined by experimental methods")
                    InfoRow(title: "Data Source", value: "PDB", description: "Protein Data Bank - worldwide repository of 3D structure data")
                    InfoRow(title: "Quality", value: "Experimental", description: "Structure determined through experimental techniques like X-ray crystallography")
                    
                    let hasLigands = structure.atoms.contains { $0.isLigand }
                    InfoRow(title: "Ligands", value: hasLigands ? "Present" : "None", description: hasLigands ? "Small molecules or ions bound to the protein" : "No small molecules detected in this structure")
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Show original annotations if available
            if !structure.annotations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.title2)
                            .foregroundColor(.indigo)
                        
                        Text("Additional Annotations")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(structure.annotations.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(structure.annotations, id: \.type) { annotation in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(annotation.type.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(annotation.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
    }
}




