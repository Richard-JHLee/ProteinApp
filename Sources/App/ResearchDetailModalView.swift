import SwiftUI

// MARK: - Research Detail Modal View (iPad 전체 화면용)

struct ResearchDetailModalView: View {
    let protein: ProteinInfo
    let researchType: ResearchDetailView.ResearchType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ResearchDetailView(protein: protein, researchType: researchType)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Research Detail Modal Presenter

struct ResearchDetailModalPresenter: View {
    let protein: ProteinInfo
    let researchType: ResearchDetailView.ResearchType
    @State private var isPresented = false
    
    var body: some View {
        Button(action: {
            isPresented = true
        }) {
            EmptyView()
        }
        .sheet(isPresented: $isPresented) {
            ResearchDetailModalView(protein: protein, researchType: researchType)
        }
    }
}

// MARK: - Research Metric with Modal

struct ResearchMetricModal: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let protein: ProteinInfo
    let researchType: ResearchDetailView.ResearchType
    @State private var isPresented = false
    
    var body: some View {
        Button(action: {
            isPresented = true
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $isPresented) {
            ResearchDetailModalView(protein: protein, researchType: researchType)
        }
    }
}
