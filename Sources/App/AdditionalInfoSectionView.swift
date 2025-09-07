import SwiftUI

struct AdditionalInfoSectionView: View {
    let protein: ProteinInfo
    var onRelatedTapped: (String) -> Void
    @State private var showingRelatedProteins = false

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

            InfoCard(icon: "link", title: "Related Proteins", tint: protein.category.color) {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            relatedProteinChip(id: "1CAT", name: "Catalase")
                            relatedProteinChip(id: "1TIM", name: "Triose Phosphate Isomerase")
                            relatedProteinChip(id: "1HRP", name: "Horseradish Peroxidase")
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // View Details 버튼을 InfoCard 안으로 이동
                    HStack {
                        Text("View Details")
                            .font(.caption.weight(.medium))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.red)
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 onTapGesture 실행!")
                        showingRelatedProteins = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingRelatedProteins) {
            VStack {
                Text("테스트 팝업")
                    .font(.title)
                Text("View Details 버튼이 작동합니다!")
                    .font(.body)
                Button("닫기") {
                    showingRelatedProteins = false
                }
            }
            .padding()
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