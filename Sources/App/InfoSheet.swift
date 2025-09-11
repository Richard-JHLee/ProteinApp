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
    
    // 1,2,3,4 단계 팝업 상태 변수들
    @State private var showingPrimaryStructure = false
    @State private var showingSecondaryStructure = false
    @State private var showingTertiaryStructure = false
    @State private var showingQuaternaryStructure = false

    init(protein: ProteinInfo, onProteinSelected: ((String) -> Void)? = nil) {
        self.protein = protein
        self.onProteinSelected = onProteinSelected
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1단계: Overview Section
                        HeaderSectionView(protein: protein, 
                                        onScrollToSection: { section in
                                            withAnimation(.easeInOut(duration: 0.5)) {
                                                proxy.scrollTo(section, anchor: .top)
                                            }
                                        })
                        .id("overview")

                        // 2단계: Function Section
                        MainInfoSectionView(
                            protein: protein,
                            showingPDBWebsite: $showingPDBWebsite
                        )
                        .id("function")

                        // 3단계: Structure Section
                        DetailedInfoSectionView(protein: protein)
                            .id("structure")

                        // 4단계: Additional Information Section
                        AdditionalInfoSectionView(protein: protein)
                        .id("additional")

                        // Action Buttons
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
                // 1,2,3,4 단계 팝업 화면들 (임시로 주석 처리)
                // .sheet(isPresented: $showingPrimaryStructure) {
                //     PrimaryStructureView(protein: protein)
                // }
                // .sheet(isPresented: $showingSecondaryStructure) {
                //     SecondaryStructureView(protein: protein)
                // }
                // .sheet(isPresented: $showingTertiaryStructure) {
                //     TertiaryStructureView(protein: protein)
                // }
                // .sheet(isPresented: $showingQuaternaryStructure) {
                //     QuaternaryStructureView(protein: protein)
                // }
            }
        }
        .navigationViewStyle(.stack)
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
    
    // MARK: - Structure Level Popup
    private func showStructureLevelPopup(_ level: Int) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            switch level {
            case 1: showingPrimaryStructure = true
            case 2: showingSecondaryStructure = true
            case 3: showingTertiaryStructure = true
            case 4: showingQuaternaryStructure = true
            default: break
            }
        }
    }
}