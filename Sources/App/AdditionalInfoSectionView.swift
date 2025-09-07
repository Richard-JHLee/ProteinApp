import SwiftUI

struct AdditionalInfoSectionView: View {
    let protein: ProteinInfo
    var onRelatedTapped: (String) -> Void
    let onStructureLevelTap: (Int) -> Void // 1,2,3,4 단계 탭 핸들러 추가

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InfoCard(icon: "key.fill", title: "Keywords & Tags", tint: protein.category.color) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(protein.keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(protein.category.color.opacity(0.1))
                            .foregroundColor(protein.category.color)
                            .cornerRadius(16)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Related Proteins")
                        .font(.subheadline.weight(.semibold))
                    
                    Spacer()
                    
                    Button(action: {
                        // Related 상세 화면으로 이동
                    }) {
                        HStack {
                            Text("View All")
                                .font(.caption.weight(.medium))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                        }
                        .foregroundColor(protein.category.color)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        relatedProteinChip(id: "1CAT", name: "Catalase")
                        relatedProteinChip(id: "1TIM", name: "Triose Phosphate Isomerase")
                        relatedProteinChip(id: "1HRP", name: "Horseradish Peroxidase")
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // 1,2,3,4 단계 구조 정보 추가
            structureLevelsView
        }
    }

    private func relatedProteinChip(id: String, name: String) -> some View {
        Button { onRelatedTapped(id) } label: {
            VStack(spacing: 4) {
                Text(id)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Text(name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Structure Levels View
    private var structureLevelsView: some View {
        InfoCard(icon: "cube.box", title: "Protein Structure Levels", tint: .cyan) {
            VStack(spacing: 16) {
                structureLevel(number: "1", title: "Primary Structure", 
                              description: "Amino acid sequence", 
                              color: .blue)
                
                structureLevel(number: "2", title: "Secondary Structure", 
                              description: "Alpha helix, beta sheet, turns", 
                              color: .green)
                
                structureLevel(number: "3", title: "Tertiary Structure", 
                              description: "3D folding and domains", 
                              color: .orange)
                
                structureLevel(number: "4", title: "Quaternary Structure", 
                              description: "Subunit assembly", 
                              color: .purple)
            }
        }
    }
    
    // 구조 단계 카드 생성 함수
    private func structureLevel(number: String, title: String, description: String, color: Color) -> some View {
        Button(action: {
            onStructureLevelTap(Int(number) ?? 0)
        }) {
            HStack(spacing: 12) {
                // 단계 번호
                Text(number)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(color, in: Circle())
                
                // 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 화살표
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}