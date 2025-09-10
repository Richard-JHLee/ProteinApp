import SwiftUI

struct ActionButtonsSectionView: View {
    let protein: ProteinInfo
    var onView3D: () -> Void
    var onFavorite: () -> Void
    @State private var is3DButtonPressed = false

    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                // 즉시 버튼 상태 변경
                withAnimation(.easeInOut(duration: 0.2)) {
                    is3DButtonPressed = true
                }
                
                // Haptic feedback
                provideHapticFeedback(style: .medium)
                
                // 3D 구조 로딩 시작
                onView3D()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: is3DButtonPressed ? "cube.box" : "cube.box.fill")
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(is3DButtonPressed ? 
                        "Loading..." : 
                        "View 3D Structure")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(is3DButtonPressed ? protein.category.color.opacity(0.7) : protein.category.color)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: protein.category.color.opacity(0.3), radius: 4, x: 0, y: 2)
                .scaleEffect(is3DButtonPressed ? 0.95 : 1.0)
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
        }
        .padding(.top, 8)
    }
}