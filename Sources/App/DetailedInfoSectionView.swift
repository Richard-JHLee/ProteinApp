import SwiftUI

struct DetailedInfoSectionView: View {
    let protein: ProteinInfo

    var body: some View {
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
}