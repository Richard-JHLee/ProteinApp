import SwiftUI

struct InfoSheet: View {
    let protein: ProteinInfo
    let onProteinSelected: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingProteinView = false
    @State private var showingPDBWebsite = false

    init(protein: ProteinInfo, onProteinSelected: ((String) -> Void)? = nil) {
        self.protein = protein
        self.onProteinSelected = onProteinSelected
    }

    var body: some View {
        NavigationView {
            ScrollView {
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Protein Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingProteinView) {
            ProteinViewSheet(proteinId: protein.id)
        }
        .sheet(isPresented: $showingPDBWebsite) {
            PDBWebsiteSheet(proteinId: protein.id)
        }
    }
}