import SwiftUI

// MARK: - iPhone Content View
struct iPhoneContentView: View {
    @ObservedObject var viewModel: ProteinViewModel
    @State private var showingProteinLibrary: Bool = false
    @State private var is3DStructureLoading = false
    @State private var structureLoadingProgress = ""
    
    var body: some View {
        NavigationView {
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
                } else {
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
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
                if viewModel.structure == nil {
                    viewModel.loadDefaultProtein()
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("Retry") {
                    viewModel.loadDefaultProtein()
                }
                .accessibilityLabel("Retry loading protein")
                Button("OK") {
                    viewModel.error = nil
                }
                .accessibilityLabel("Dismiss error message")
            } message: {
                Text(viewModel.error ?? "")
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
        #if os(iOS)
        .preferredColorScheme(.light)
        .statusBarHidden(false)
        .supportedOrientations(.all)
        #elseif os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
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
struct iPhoneContentView_Previews: PreviewProvider {
    static var previews: some View {
        iPhoneContentView(viewModel: ProteinViewModel())
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("iPhone 15 Pro")
    }
}
