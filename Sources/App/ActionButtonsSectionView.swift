import SwiftUI

struct ActionButtonsSectionView: View {
    let protein: ProteinInfo
    var onView3D: () -> Void
    var onFavorite: () -> Void
    var onEnhancedView: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onView3D) {
                HStack(spacing: 12) {
                    Image(systemName: "cube.box.fill")
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text("View 3D Structure")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(protein.category.color)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: protein.category.color.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View 3D structure for \(protein.name)")

            Button(action: onFavorite) {
                HStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text("Add to Favorites")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(protein.category.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(protein.category.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(protein.category.color.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(protein.name) to favorites")
            
            Button(action: onEnhancedView) {
                HStack(spacing: 12) {
                    Image(systemName: "cube.transparent.fill")
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text("Enhanced 3D Viewer")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(protein.category.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(protein.category.color, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View enhanced 3D visualization for \(protein.name)")
        }
        .padding(.top, 8)
    }
}