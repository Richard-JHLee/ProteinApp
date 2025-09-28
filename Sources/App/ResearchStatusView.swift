import SwiftUI

// MARK: - Research Status View

struct ResearchStatusView: View {
    let protein: ProteinInfo
    @StateObject private var viewModel = ResearchStatusViewModel.shared
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading[protein.id] == true {
                ResearchLoadingView()
            } else if let errorMessage = viewModel.errorMessage[protein.id] {
                ResearchErrorView(message: errorMessage) {
                    viewModel.loadResearchStatus(for: protein.id)
                }
            } else if let summary = viewModel.summary[protein.id] {
                ResearchSummaryCards(summary: summary, protein: protein)
            } else {
                ResearchEmptyView()
            }
        }
        .onAppear {
            // 이미 데이터가 있으면 다시 로드하지 않음
            if viewModel.summary[protein.id] == nil && viewModel.isLoading[protein.id] != true {
                viewModel.loadResearchStatus(for: protein.id)
            }
        }
    }
}

// MARK: - Research Summary Cards

struct ResearchSummaryCards: View {
    let summary: ResearchStatusSummary
    let protein: ProteinInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Active Studies
            ResearchMetric(
                title: "Active Studies",
                value: "\(summary.totalStudies)",
                icon: "flask.fill",
                color: .green,
                protein: protein,
                researchType: .activeStudies
            )
            
            // Clinical Trials
            ResearchMetric(
                title: "Clinical Trials",
                value: "\(summary.totalTrials)",
                icon: "cross.case.fill",
                color: .blue,
                protein: protein,
                researchType: .clinicalTrials
            )
            
            // Publications
            ResearchMetric(
                title: "Publications",
                value: "\(summary.totalPublications)",
                icon: "book.fill",
                color: .purple,
                protein: protein,
                researchType: .publications
            )
        }
    }
}

struct ResearchMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let protein: ProteinInfo
    let researchType: ResearchDetailView.ResearchType
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: 모달로 표시
                ResearchMetricModal(
                    title: title,
                    value: value,
                    icon: icon,
                    color: color,
                    protein: protein,
                    researchType: researchType
                )
            } else {
                // iPhone: NavigationLink로 표시
                NavigationLink(destination: ResearchDetailView(protein: protein, researchType: researchType)) {
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
            }
        }
    }
}

// MARK: - Loading, Error, and Empty Views

struct ResearchLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3) { index in
                VStack(spacing: 4) {
                    // 아이콘 로딩 애니메이션
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .opacity(isAnimating ? 0.3 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                    
                    // 숫자 로딩 애니메이션
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 30, height: 16)
                        .opacity(isAnimating ? 0.3 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2 + 0.1),
                            value: isAnimating
                        )
                    
                    // 제목 로딩 애니메이션
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 12)
                        .opacity(isAnimating ? 0.3 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2 + 0.2),
                            value: isAnimating
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ResearchErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Failed to load research data")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                onRetry()
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.blue)
        }
        .padding(.vertical, 20)
    }
}

struct ResearchEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flask")
                .font(.title)
                .foregroundColor(.gray)
            
            Text("No research data available")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Text("Research information for this protein is not available")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Research Metric Modal (iPad용)

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
            NavigationView {
                ResearchDetailView(protein: protein, researchType: researchType)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
