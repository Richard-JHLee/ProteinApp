import SwiftUI

struct DetailedInfoSectionView: View {
    let protein: ProteinInfo
    let onStructureLevelTap: (Int) -> Void // 1,2,3,4 단계 탭 핸들러 추가

    var body: some View {
        VStack(spacing: 16) {
            // 기존 Additional Information
            InfoCard(icon: "info.circle",
                     title: "Additional Information",
                     tint: .gray) {
                VStack(spacing: 12) {
                    infoRow(title: "Structure Type", value: "X-ray Crystallography", icon: "cube.box")
                    infoRow(title: "Resolution",     value: "2.5 Å",    icon: "scope")
                    infoRow(title: "Organism",       value: "Homo sapiens",      icon: "person")
                    infoRow(title: "Expression",     value: "E. coli",    icon: "leaf")
                    
                    Button(action: {
                        // Structure 상세 화면으로 이동
                    }) {
                        HStack {
                            Text("View Details")
                                .font(.caption.weight(.medium))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            
            // 1,2,3,4 단계 구조 정보 추가
            structureLevelsView
        }
    }

    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(protein.category.color)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(value)
                .font(.subheadline)
                .modifier(ConditionalFontWeight(weight: .medium, fallbackFont: .subheadline))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .cornerRadius(12)
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