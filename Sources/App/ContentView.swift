import SwiftUI

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
    
    // Size Class 기반 반응형 레이아웃을 위한 환경 변수
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
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
                                    .scaleEffect(horizontalSizeClass == .regular ? 1.5 : 1.2)
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
        .navigationViewStyle(.automatic)
        .sheet(isPresented: $showingProteinLibrary) {
            // iPhone에서 Sheet로 표시 (조건부 처리)
            if horizontalSizeClass == .compact {
                ProteinLibraryView { selectedProteinId in
                    // Handle protein selection from library
                    print("Selected protein ID: \(selectedProteinId)")
                    showingProteinLibrary = false
                    
                    // 3D 구조 로딩 시작
                    is3DStructureLoading = true
                    structureLoadingProgress = "Loading 3D structure for \(selectedProteinId)..."
                    
                    // Load the selected protein structure
                    loadSelectedProtein(selectedProteinId)
                    
                    // 3D 구조 로딩 완료 시뮬레이션 (실제로는 구조 데이터 로드 완료 시)
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3초
                        await MainActor.run {
                            is3DStructureLoading = false
                            structureLoadingProgress = ""
                        }
                    }
                }
            }
        }
        .popover(isPresented: $showingProteinLibrary) {
            // iPad에서 Popover로 표시 (조건부 처리)
            if horizontalSizeClass == .regular {
                ProteinLibraryView { selectedProteinId in
                    // Handle protein selection from library
                    print("Selected protein ID: \(selectedProteinId)")
                    showingProteinLibrary = false
                    
                    // 3D 구조 로딩 시작
                    is3DStructureLoading = true
                    structureLoadingProgress = "Loading 3D structure for \(selectedProteinId)..."
                    
                    // Load the selected protein structure
                    loadSelectedProtein(selectedProteinId)
                    
                    // 3D 구조 로딩 완료 시뮬레이션 (실제로는 구조 데이터 로드 완료 시)
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3초
                        await MainActor.run {
                            is3DStructureLoading = false
                            structureLoadingProgress = ""
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSideMenu) {
            // iPhone에서 Sheet로 표시 (조건부 처리)
            if horizontalSizeClass == .compact {
                Text("Side Menu - Coming Soon")
                    .font(.title)
                    .padding()
            }
        }
        .popover(isPresented: $showingSideMenu) {
            // iPad에서 Popover로 표시 (조건부 처리)
            if horizontalSizeClass == .regular {
                Text("Side Menu - Coming Soon")
                    .font(.title)
                    .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingSideMenu = true }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("Open side menu")
                .accessibilityHint("Tap to open navigation menu")
            }
        }
        .preferredColorScheme(.light)
        #if os(iOS)
        .statusBarHidden(false)
        .supportedOrientations(.all)
        #elseif os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }
    
    private func loadDefaultProtein() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let url = URL(string: "https://files.rcsb.org/download/1CRN.pdb")!
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                let pdbText = String(decoding: data, as: UTF8.self)
                let loadedStructure = try PDBParser.parse(pdbText: pdbText)
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.currentProteinId = "1CRN"
                    self.currentProteinName = "Crambin"
                    self.isLoading = false
                    print("Successfully loaded default PDB structure: 1CRN")
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load default protein structure: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error loading default PDB structure: \(error)")
                }
            }
        }
    }
    
    private func loadSelectedProtein(_ pdbId: String) {
        isLoading = true
        loadingProgress = "Initializing..."
        error = nil
        
        Task {
            do {
                // Construct PDB download URL using the protein's PDB ID
                let formattedPdbId = pdbId.uppercased()
                let url = URL(string: "https://files.rcsb.org/download/\(formattedPdbId).pdb")!
                
                print("Loading PDB structure for: \(formattedPdbId)")
                
                await MainActor.run {
                    self.loadingProgress = "Downloading PDB file..."
                }
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.loadingProgress = "Parsing PDB structure..."
                }
                
                let pdbText = String(decoding: data, as: UTF8.self)
                let loadedStructure = try PDBParser.parse(pdbText: pdbText)
                
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
            } catch {
                await MainActor.run {
                    let errorMessage = "Failed to load protein structure for \(pdbId): \(error.localizedDescription)"
                    self.error = errorMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                    print("Error loading PDB structure: \(error)")
                }
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

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("iPhone 15 Pro")
    }
} 
