import SwiftUI

struct AdditionalInfoSectionView: View {
    let protein: ProteinInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InfoCard(icon: "key.fill", title: "Keywords & Tags", tint: protein.category.color) {
                VStack(alignment: .leading, spacing: 12) {
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
            }
        }
    }

}