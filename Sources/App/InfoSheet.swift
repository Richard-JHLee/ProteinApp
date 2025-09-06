import SwiftUI

struct InfoSheet: View {
    let protein: ProteinInfo
    let onProteinSelected: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingProteinView = false
    @State private var showingPDBWebsite = false
    @State private var proteinStructure: PDBStructure? = nil
    @State private var isLoadingStructure = false
    @State private var structureError: String? = nil
    @State private var showingSideMenu: Bool = false
    @State private var isProteinLoading = false
    @State private var proteinLoadingProgress = ""
    @State private var is3DStructureLoading = false
    @State private var structureLoadingProgress = ""

    init(protein: ProteinInfo, onProteinSelected: ((String) -> Void)? = nil) {
        self.protein = protein
        self.onProteinSelected = onProteinSelected
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    HeaderSectionView(protein: protein)

                    MainInfoSectionView(
                        protein: protein,
                        showingPDBWebsite: $showingPDBWebsite
                    )

                    DetailedInfoSectionView(protein: protein)

                    AdditionalInfoSectionView(
                        protein: protein,
                        onRelatedTapped: { id in
                            // 관련 단백질 선택 시 동일 동작
                            if let onProteinSelected {
                                onProteinSelected(id)
                                dismiss()
                            } else {
                                showingProteinView = true
                            }
                        }
                    )

                    ActionButtonsSectionView(
                        protein: protein,
                        onView3D: {
                            // 3D 구조 로딩 시작
                            is3DStructureLoading = true
                            structureLoadingProgress = "Loading 3D structure for \(protein.id)..."
                            
                            if let onProteinSelected {
                                onProteinSelected(protein.id)
                                dismiss()
                            } else {
                                showingProteinView = true
                                
                                // 3D 구조 로딩 시뮬레이션 (실제로는 구조 데이터 로드 완료 시)
                                Task {
                                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2초
                                    await MainActor.run {
                                        is3DStructureLoading = false
                                        structureLoadingProgress = ""
                                    }
                                }
                            }
                        },
                        onFavorite: {
                            // TODO: 즐겨찾기 토글
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Protein Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay {
            // 3D Structure Loading Overlay
            if is3DStructureLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text(structureLoadingProgress.isEmpty ? "Loading 3D Structure..." : structureLoadingProgress)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    )
            }
        }
        .sheet(isPresented: $showingProteinView) {
            if let structure = proteinStructure {
                ProteinSceneContainer(
                    structure: structure,
                    proteinId: protein.id,
                    proteinName: protein.name,
                    onProteinLibraryTap: nil, // InfoSheet에서는 Protein Library 기능 불필요
                    externalIsProteinLoading: $isProteinLoading,
                    externalProteinLoadingProgress: $proteinLoadingProgress,
                    externalIs3DStructureLoading: $is3DStructureLoading,
                    externalStructureLoadingProgress: $structureLoadingProgress
                )
                .onAppear {
                    // 단백질 로딩 시작
                    isProteinLoading = true
                    proteinLoadingProgress = "Loading \(protein.id)..."
                    
                    // 로딩 완료 시뮬레이션 (실제로는 단백질 데이터 로드 완료 시)
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초
                        await MainActor.run {
                            isProteinLoading = false
                            proteinLoadingProgress = ""
                        }
                    }
                }
            } else if isLoadingStructure {
                VStack(spacing: 20) {
                    ProgressView("Loading protein structure...")
                        .font(.headline)
                    Text("Please wait while we load the 3D structure")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                VStack(spacing: 20) {
                    if let error = structureError {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            
                            Text("Failed to load structure")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "atom")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            Text("3D Protein Viewer")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Tap to load protein structure")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Load Structure") {
                        loadProteinStructure()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoadingStructure)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingSideMenu = true }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showingSideMenu) {
            SideMenuView()
        }
        .onChange(of: showingProteinView) { newValue in
            if newValue && proteinStructure == nil {
                loadProteinStructure()
            }
        }
    }
    
    private func loadProteinStructure() {
        isLoadingStructure = true
        structureError = nil
        
        Task {
            do {
                let url = URL(string: "https://files.rcsb.org/download/\(protein.id).pdb")!
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                let pdbText = String(decoding: data, as: UTF8.self)
                let loadedStructure = try PDBParser.parse(pdbText: pdbText)
                
                await MainActor.run {
                    self.proteinStructure = loadedStructure
                    self.isLoadingStructure = false
                }
            } catch {
                await MainActor.run {
                    self.structureError = "Failed to load \(protein.id): \(error.localizedDescription)"
                    self.isLoadingStructure = false
                }
            }
        }
    }
}