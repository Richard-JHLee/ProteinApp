import SwiftUI

struct AdditionalInfoSectionView: View {
    let protein: ProteinInfo
    var onRelatedTapped: (String) -> Void

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
}