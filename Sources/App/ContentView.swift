import SwiftUI

struct ContentView: View {
    @State private var structure: PDBStructure? = nil
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var showingProteinLibrary: Bool = false
    @State private var currentProteinId: String = ""
    @State private var currentProteinName: String = ""
    
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
                        }
                    )
                } else {
                    VStack(spacing: 20) {
                        if isLoading {
                            ProgressView("Loading protein structure...")
                                .font(.headline)
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
            }
            .onAppear {
                loadDefaultProtein()
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("Retry") {
                    loadDefaultProtein()
                }
                Button("OK") {
                    error = nil
                }
            } message: {
                Text(error ?? "")
            }
        }
        .sheet(isPresented: $showingProteinLibrary) {
            ProteinLibraryView { selectedProteinId in
                // Handle protein selection from library
                print("Selected protein ID: \(selectedProteinId)")
                showingProteinLibrary = false
                // Load the selected protein structure
                loadSelectedProtein(selectedProteinId)
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden(false)
        .supportedOrientations(.allButUpsideDown)
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
                let loadedStructure = PDBParser.parse(pdbText: pdbText)
                
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
        error = nil
        
        Task {
            do {
                // Construct PDB download URL using the protein's PDB ID
                let formattedPdbId = pdbId.uppercased()
                let url = URL(string: "https://files.rcsb.org/download/\(formattedPdbId).pdb")!
                
                print("Loading PDB structure for: \(formattedPdbId)")
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                let pdbText = String(decoding: data, as: UTF8.self)
                let loadedStructure = PDBParser.parse(pdbText: pdbText)
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.currentProteinId = formattedPdbId
                    self.currentProteinName = getProteinName(from: formattedPdbId)
                    self.isLoading = false
                    print("Successfully loaded PDB structure: \(formattedPdbId)")
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load protein structure for \(pdbId): \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error loading PDB structure: \(error)")
                }
            }
        }
    }
    
    private func getProteinName(from pdbId: String) -> String {
        // Common protein names mapping
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
        
        return proteinNames[pdbId] ?? "Unknown Protein"
    }
}

extension View {
    func supportedOrientations(_ orientations: UIInterfaceOrientationMask) -> some View {
        self.onAppear {
            AppDelegate.orientationLock = orientations
        }
    }
}

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
