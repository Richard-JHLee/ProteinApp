import SwiftUI

struct HeaderSectionView: View {
    let protein: ProteinInfo

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 16) {
                GradientIcon(systemName: protein.category.icon,
                             base: protein.category.color)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text(protein.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        CapsuleTag(text: "PDB \(protein.id)",
                                   foreground: protein.category.color,
                                   background: protein.category.color.opacity(0.12),
                                   icon: "barcode.viewfinder")
                        CapsuleTag(text: protein.category.rawValue,
                                   foreground: .white,
                                   background: protein.category.color.opacity(0.9),
                                   icon: "tag.fill")
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 8)
            }
            .padding(16)
        }
        .padding(.top, 6)
    }
}