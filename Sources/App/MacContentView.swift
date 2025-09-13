import SwiftUI

#if os(macOS)
// MARK: - Mac Content View
struct MacContentView: View {
    @ObservedObject var viewModel: ProteinViewModel
    @State private var selectedMenu: iPadMenuType = .mainView
    @State private var showingProteinLibrary: Bool = false
    @State private var is3DStructureLoading = false
    @State private var structureLoadingProgress = ""
    
    var body: some View {
        NavigationView {
            // 사이드바 (마스터)
            MacSidebarView(
                selectedMenu: $selectedMenu,
                onMenuSelected: { menu in
                    print("🔄 Mac Menu selected: \(menu.rawValue)")
                    selectedMenu = menu
                }
            )
            .navigationBarHidden(true)
            
            // 메인 콘텐츠 영역 (디테일)
            MacMainContentView(
                selectedMenu: selectedMenu,
                viewModel: viewModel,
                showingProteinLibrary: $showingProteinLibrary,
                is3DStructureLoading: $is3DStructureLoading,
                structureLoadingProgress: $structureLoadingProgress
            )
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.automatic)
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            print("🚀 MacContentView onAppear - selectedMenu: \(selectedMenu.rawValue)")
            // Mac에서 앱 시작 시 기본 단백질 로딩 보장
            if viewModel.structure == nil {
                print("🚀 Mac detected, loading default protein on startup")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.loadDefaultProtein()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Load Protein") {
                    showingProteinLibrary = true
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Protein Library") {
                    selectedMenu = .proteinLibrary
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("Settings") {
                    selectedMenu = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .menuBarExtra("ProteinApp", systemImage: "atom") {
            VStack(alignment: .leading, spacing: 8) {
                Text("ProteinApp")
                    .font(.headline)
                
                Divider()
                
                Button("Load Protein") {
                    showingProteinLibrary = true
                }
                
                Button("Protein Library") {
                    selectedMenu = .proteinLibrary
                }
                
                Button("Settings") {
                    selectedMenu = .settings
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showingProteinLibrary) {
            // Protein Library 전체 화면
            NavigationView {
                ProteinLibraryView { selectedProteinId in
                    showingProteinLibrary = false
                    is3DStructureLoading = true
                    structureLoadingProgress = "Loading 3D structure for \(selectedProteinId)..."
                    viewModel.loadSelectedProtein(selectedProteinId)
                    
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
    }
}

// MARK: - Mac Sidebar View
struct MacSidebarView: View {
    @Binding var selectedMenu: iPadMenuType
    let onMenuSelected: (iPadMenuType) -> Void

    var body: some View {
        List {
            Section {
                ForEach(iPadMenuType.allCases, id: \.self) { menu in
                    Button(action: {
                        onMenuSelected(menu)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: menu.icon)
                                .font(.title3)
                                .foregroundColor(selectedMenu == menu ? .white : .blue)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(menu.rawValue)
                                    .font(.headline)
                                    .foregroundColor(selectedMenu == menu ? .white : .primary)
                                
                                Text(menu.description)
                                    .font(.caption)
                                    .foregroundColor(selectedMenu == menu ? .white.opacity(0.8) : .secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedMenu == menu ? Color.blue : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
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
            }
        }
        .navigationTitle("ProteinApp")
        .navigationBarTitleDisplayMode(.large)
        .frame(minWidth: 200)
    }
}

// MARK: - Mac Main Content View
struct MacMainContentView: View {
    let selectedMenu: iPadMenuType
    @ObservedObject var viewModel: ProteinViewModel
    @Binding var showingProteinLibrary: Bool
    @Binding var is3DStructureLoading: Bool
    @Binding var structureLoadingProgress: String
    
    var body: some View {
        Group {
            switch selectedMenu {
            case .mainView:
                mainViewContent
            case .proteinLibrary:
                // Protein Library 화면
                ProteinLibraryView { selectedProteinId in
                    viewModel.loadSelectedProtein(selectedProteinId)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDroppedFiles(providers)
        }
    }
    
    // MARK: - Main View Content
    private var mainViewContent: some View {
        ZStack {
            if let structure = viewModel.structure {
                ProteinSceneContainer(
                    structure: structure,
                    proteinId: viewModel.currentProteinId,
                    proteinName: viewModel.currentProteinName,
                    onProteinLibraryTap: {
                        showingProteinLibrary = true
                    },
                    externalIsProteinLoading: $viewModel.isLoading,
                    externalProteinLoadingProgress: $viewModel.loadingProgress,
                    externalIs3DStructureLoading: $is3DStructureLoading,
                    externalStructureLoadingProgress: $structureLoadingProgress
                )
                .onAppear {
                    print("✅ Mac Structure loaded: \(structure.atoms.count) atoms, proteinId: \(viewModel.currentProteinId), proteinName: \(viewModel.currentProteinName)")
                }
            } else if viewModel.isLoading {
                loadingView
                    .onAppear {
                        print("⚠️ Mac No structure loaded, showing loading UI - proteinId: \(viewModel.currentProteinId), proteinName: \(viewModel.currentProteinName), isLoading: \(viewModel.isLoading)")
                    }
            } else {
                // Mac에서 Main View 선택 시 로딩 첫 화면을 전체에 표시
                initialLoadingView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .onAppear {
                        print("⚠️ Mac No structure loaded, showing initial loading view")
                    }
            }
        }
        .onAppear {
            print("🔄 Mac MainView onAppear - structure: \(viewModel.structure != nil ? "loaded" : "nil")")
            if viewModel.structure == nil {
                print("🔄 Mac Triggering default protein load from onAppear")
                viewModel.loadDefaultProtein()
            }
        }
        .onChange(of: selectedMenu) { newMenu in
            print("🔄 Mac selectedMenu changed to: \(newMenu.rawValue)")
            // Main View 선택 시 항상 기본 단백질 로딩
            if newMenu == .mainView {
                print("🔄 Mac Main View selected, triggering protein load")
                // 즉시 로딩 시작
                DispatchQueue.main.async {
                    viewModel.loadDefaultProtein()
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("Retry") {
                viewModel.loadDefaultProtein()
            }
            .accessibilityLabel("Retry loading protein")
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading {
                loadingProgressView
            } else {
                initialLoadingView
            }
        }
    }
    
    private var loadingProgressView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text("Loading protein structure...")
                .font(.headline)
                .foregroundColor(.primary)
                .dynamicTypeSize(.large)
            
            if !viewModel.loadingProgress.isEmpty {
                Text(viewModel.loadingProgress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // Mac 로딩 첫 화면 뷰
    private var initialLoadingView: some View {
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
    
    // MARK: - Drag and Drop Support
    private func handleDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            // PDB 파일 처리 로직
                            print("📁 Dropped file: \(url.lastPathComponent)")
                            // TODO: PDB 파일 파싱 및 로딩 구현
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Preview
struct MacContentView_Previews: PreviewProvider {
    static var previews: some View {
        MacContentView(viewModel: ProteinViewModel())
            .previewDevice("Mac")
            .previewDisplayName("Mac")
    }
}
#endif
