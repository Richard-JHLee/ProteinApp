import SwiftUI

// MARK: - Research Status View

struct ResearchStatusView: View {
    let protein: ProteinInfo
    @StateObject private var viewModel = ResearchStatusViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ResearchLoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                ResearchErrorView(message: errorMessage) {
                    viewModel.loadResearchStatus(for: protein.id)
                }
            } else if let summary = viewModel.summary {
                ResearchSummaryCards(summary: summary, protein: protein)
            } else {
                ResearchEmptyView()
            }
        }
        .onAppear {
            viewModel.loadResearchStatus(for: protein.id)
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

// MARK: - Loading, Error, and Empty Views

struct ResearchLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3) { _ in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 30, height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
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
