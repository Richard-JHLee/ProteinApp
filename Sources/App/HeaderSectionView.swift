import SwiftUI

struct HeaderSectionView: View {
    let protein: ProteinInfo

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                // 상단: 아이콘과 단백질 이름
                HStack(alignment: .center, spacing: 16) {
                    GradientIcon(systemName: protein.dynamicIcon,
                                 base: protein.category.color)
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(protein.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(protein.name.count > 50 ? 1 : 2)  // 동적 길이 조정
                            .truncationMode(.tail)                       // "..." 표시
                            .minimumScaleFactor(0.8)                     // 필요시 텍스트 크기 축소
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)
                }
                
                // 하단: PDB ID와 카테고리 태그 (전체 너비 사용)
                HStack(spacing: 8) {
                    CapsuleTag(text: "PDB \(protein.id)",
                               foreground: protein.category.color,
                               background: protein.category.color.opacity(0.12),
                               icon: "barcode.viewfinder")
                    
                    CapsuleTag(text: protein.category.rawValue,
                               foreground: .white,
                               background: protein.category.color.opacity(0.9),
                               icon: "tag.fill")
                    
                    Spacer() // 남은 공간 차지
                }
            }
            .padding(16)
        }
        .padding(.top, 6)
    }
}