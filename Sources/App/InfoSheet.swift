import SwiftUI

struct InfoSheet: View {
    let protein: ProteinInfo
    let onProteinSelected: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingProteinView = false
    @State private var showingPDBWebsite = false
    @State private var showingEnhancedViewer = false

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
                            if let onProteinSelected {
                                onProteinSelected(protein.id)
                                dismiss()
                            } else {
                                showingProteinView = true
                            }
                        },
                        onFavorite: {
                            // TODO: 즐겨찾기 토글
                        }
                    )
                    
                    // Enhanced Viewer Button
                    Button(action: {
                        showingEnhancedViewer = true
                    }) {
                        HStack {
                            Image(systemName: "cube.transparent")
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enhanced 3D Viewer")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Advanced analysis with chains, ligands, pockets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Protein Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingProteinView) {
            ProteinSceneContainer(selectedProteinId: protein.id)
        }
        .fullScreenCover(isPresented: $showingEnhancedViewer) {
            EnhancedProteinViewerView(protein: protein)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}