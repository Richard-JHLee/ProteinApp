import SwiftUI

struct ActionButtonsSectionView: View {
    let protein: ProteinInfo
    var onView3D: () -> Void
    var onFavorite: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onView3D) {
                HStack(spacing: 12) {
                    Image(systemName: "cube.box.fill").font(.title2)
                    Text("View 3D Structure").font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(protein.category.color)
                .cornerRadius(16)
            }

            Button(action: onFavorite) {
                HStack(spacing: 12) {
                    Image(systemName: "heart").font(.title2)
                    Text("Add to Favorites").font(.headline.weight(.semibold))
                }
                .foregroundColor(protein.category.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(protein.category.color.opacity(0.1))
                .cornerRadius(16)
            }
        }
        .padding(.top, 8)
    }
}