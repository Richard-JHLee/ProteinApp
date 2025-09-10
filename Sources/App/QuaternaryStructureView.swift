import SwiftUI

struct QuaternaryStructureView: View {
    let protein: ProteinInfo
    @State private var quaternaryStructure: QuaternaryStructure?
    @State private var isLoadingStructure = false
    @State private var structureError: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingStructure {
                        structureLoadingView
                    } else if let error = structureError {
                        structureErrorView(error)
                    } else {
                        structureContentView
                    }
                }
                .padding()
            }
            .navigationTitle("Quaternary Structure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadQuaternaryStructure()
        }
    }
    
    // MARK: - Loading View
    private var structureLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(LanguageHelper.localizedText(
                korean: "4차 구조 로딩 중...",
                english: "Loading quaternary structure..."
            ))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func structureErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(LanguageHelper.localizedText(
                korean: "구조 로드 실패",
                english: "Failed to load structure"
            ))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(LanguageHelper.localizedText(
                korean: "다시 시도",
                english: "Retry"
            )) {
                loadQuaternaryStructure()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Content View
    private var structureContentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("Subunit Assembly")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let structure = quaternaryStructure {
                // 서브유닛 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Protein Subunits")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.subunits.enumerated()), id: \.offset) { index, subunit in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Subunit \(subunit.id)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(protein.category.color)
                                
                                Spacer()
                                
                                Text("\(subunit.residueCount) residues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(subunit.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(protein.category.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 조립 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Assembly Information")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Assembly Type:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(structure.assembly.type)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Symmetry:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(structure.assembly.symmetry)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Total Mass:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(structure.assembly.totalMass) kDa")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // 상호작용 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Subunit Interactions")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.interactions.enumerated()), id: \.offset) { index, interaction in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(interaction.subunit1) ↔ \(interaction.subunit2)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                Text("\(interaction.contactCount) contacts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(interaction.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No quaternary structure data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadQuaternaryStructure() {
        isLoadingStructure = true
        structureError = nil
        
        Task {
            do {
                // 실제 API 호출 대신 샘플 데이터 사용
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 지연
                
                await MainActor.run {
                    // 샘플 4차 구조 데이터
                    quaternaryStructure = QuaternaryStructure(
                        subunits: [
                            Subunit(id: "A", residueCount: 300, description: "Catalytic subunit with primary enzymatic activity"),
                            Subunit(id: "B", residueCount: 250, description: "Regulatory subunit involved in allosteric control"),
                            Subunit(id: "C", residueCount: 200, description: "Structural subunit providing stability")
                        ],
                        assembly: Assembly(
                            type: "Heterotrimer",
                            symmetry: "C3",
                            totalMass: 75.5
                        ),
                        interactions: [
                            Interaction(subunit1: "A", subunit2: "B", contactCount: 45, description: "Catalytic-regulatory interface with strong binding"),
                            Interaction(subunit1: "B", subunit2: "C", contactCount: 32, description: "Regulatory-structural interface"),
                            Interaction(subunit1: "A", subunit2: "C", contactCount: 28, description: "Catalytic-structural interface")
                        ]
                    )
                    isLoadingStructure = false
                }
            } catch {
                await MainActor.run {
                    structureError = error.localizedDescription
                    isLoadingStructure = false
                }
            }
        }
    }
}

// MARK: - Data Models
struct QuaternaryStructure {
    let subunits: [Subunit]
    let assembly: Assembly
    let interactions: [Interaction]
}

struct Subunit {
    let id: String
    let residueCount: Int
    let description: String
}

struct Assembly {
    let type: String
    let symmetry: String
    let totalMass: Double
}

struct Interaction {
    let subunit1: String
    let subunit2: String
    let contactCount: Int
    let description: String
}
