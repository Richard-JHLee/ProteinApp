import SwiftUI

struct ContentView: View {
    @State private var structure: PDBStructure? = nil
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var showingProteinLibrary: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if let structure = structure {
                    ZStack {
                        ProteinSceneContainer(structure: structure)
                        
                        // Top navigation buttons
                        VStack {
                            HStack {
                                Button("Protein Library") {
                                    showingProteinLibrary = true
                                }
                                .font(.body.weight(.medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                
                                Spacer()
                                
                                Button("Info") {
                                    // Show app info or settings
                                }
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            Spacer()
                        }
                    }
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
            ProteinLibraryView { selectedProtein in
                // Handle protein selection from library
                print("Selected protein: \(selectedProtein)")
                showingProteinLibrary = false
                // TODO: Load the selected protein structure
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
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load protein structure: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
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
