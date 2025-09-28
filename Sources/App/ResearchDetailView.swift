import SwiftUI

// MARK: - Research Detail View

struct ResearchDetailView: View {
    let protein: ProteinInfo
    let researchType: ResearchType
    
    @StateObject private var viewModel = ResearchDetailViewModel.shared
    @Environment(\.dismiss) private var dismiss
    
    enum ResearchType {
        case publications
        case clinicalTrials
        case activeStudies
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading[getCacheKey()] == true {
                    ResearchDetailLoadingView()
                } else if let errorMessage = viewModel.errorMessage[getCacheKey()] {
                    ResearchDetailErrorView(message: errorMessage) {
                        loadData()
                    }
                } else {
                    ResearchDetailContentView(
                        protein: protein,
                        researchType: researchType,
                        viewModel: viewModel
                    )
                }
            }
            .navigationTitle(getTitle())
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // iPad에서도 스택 스타일 강제
        .onAppear {
            loadData()
        }
    }
    
    private func getTitle() -> String {
        switch researchType {
        case .publications:
            return "Publications"
        case .clinicalTrials:
            return "Clinical Trials"
        case .activeStudies:
            return "Active Studies"
        }
    }
    
    private func getCacheKey() -> String {
        return "\(protein.id)_\(researchType)"
    }
    
    private func loadData() {
        Task {
            switch researchType {
            case .publications:
                await viewModel.loadPublications(for: protein.id)
            case .clinicalTrials:
                await viewModel.loadClinicalTrials(for: protein.id)
            case .activeStudies:
                await viewModel.loadActiveStudies(for: protein.id)
            }
        }
    }
}

// MARK: - Research Detail Content View

struct ResearchDetailContentView: View {
    let protein: ProteinInfo
    let researchType: ResearchDetailView.ResearchType
    @ObservedObject var viewModel: ResearchDetailViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with count
            ResearchDetailHeader(
                researchType: researchType,
                count: getCount()
            )
            
            // Content
            if getCount() == 0 {
                ResearchDetailEmptyView(researchType: researchType)
            } else {
                ResearchDetailList(
                    researchType: researchType,
                    viewModel: viewModel,
                    protein: protein
                )
            }
        }
    }
    
    private func getCount() -> Int {
        switch researchType {
        case .publications:
            return viewModel.publications[protein.id]?.count ?? 0
        case .clinicalTrials:
            return viewModel.clinicalTrials[protein.id]?.count ?? 0
        case .activeStudies:
            return viewModel.activeStudies[protein.id]?.count ?? 0
        }
    }
}

// MARK: - Research Detail Header

struct ResearchDetailHeader: View {
    let researchType: ResearchDetailView.ResearchType
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: getIcon())
                    .font(.title2)
                    .foregroundColor(getColor())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(getTitle())
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(count) \(count == 1 ? "item" : "items") found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    private func getTitle() -> String {
        switch researchType {
        case .publications:
            return "Publications"
        case .clinicalTrials:
            return "Clinical Trials"
        case .activeStudies:
            return "Active Studies"
        }
    }
    
    private func getIcon() -> String {
        switch researchType {
        case .publications:
            return "book.fill"
        case .clinicalTrials:
            return "cross.case.fill"
        case .activeStudies:
            return "flask.fill"
        }
    }
    
    private func getColor() -> Color {
        switch researchType {
        case .publications:
            return .purple
        case .clinicalTrials:
            return .blue
        case .activeStudies:
            return .green
        }
    }
}

// MARK: - Research Detail List

struct ResearchDetailList: View {
    let researchType: ResearchDetailView.ResearchType
    @ObservedObject var viewModel: ResearchDetailViewModel
    let protein: ProteinInfo
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                switch researchType {
                case .publications:
                    if let publications = viewModel.publications[protein.id] {
                        ForEach(publications) { publication in
                            PublicationCard(publication: publication)
                        }
                    }
                case .clinicalTrials:
                    if let trials = viewModel.clinicalTrials[protein.id] {
                        ForEach(trials) { trial in
                            ClinicalTrialCard(trial: trial)
                        }
                    }
                case .activeStudies:
                    if let studies = viewModel.activeStudies[protein.id] {
                        ForEach(studies) { study in
                            ActiveStudyCard(study: study)
                        }
                    }
                }
                
                // Load More Button
                if shouldShowLoadMore() {
                    LoadMoreButton {
                        loadMore()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func shouldShowLoadMore() -> Bool {
        switch researchType {
        case .publications:
            return viewModel.hasMorePublications[protein.id] == true
        case .clinicalTrials:
            return viewModel.hasMoreClinicalTrials[protein.id] == true
        case .activeStudies:
            return viewModel.hasMoreActiveStudies[protein.id] == true
        }
    }
    
    private func loadMore() {
        Task {
            switch researchType {
            case .publications:
                await viewModel.loadMorePublications(for: protein.id)
            case .clinicalTrials:
                await viewModel.loadMoreClinicalTrials(for: protein.id)
            case .activeStudies:
                await viewModel.loadMoreActiveStudies(for: protein.id)
            }
        }
    }
}

// MARK: - Card Views

struct PublicationCard: View {
    let publication: ResearchPublication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(publication.title)
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(3)
            
            HStack {
                Text(publication.journal)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(publication.year)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let authors = publication.authors.first {
                Text("Authors: \(authors)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if let abstract = publication.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ClinicalTrialCard: View {
    let trial: ClinicalTrial
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trial.title)
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(3)
            
            HStack {
                Text(trial.status)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.green)
                
                Spacer()
                
                if let phase = trial.phase {
                    Text("Phase \(phase)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            Text("Condition: \(trial.condition)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text("Intervention: \(trial.intervention)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ActiveStudyCard: View {
    let study: ActiveStudy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(study.title)
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(3)
            
            HStack {
                Text(study.status)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(study.year)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Institution: \(study.institution)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if let abstract = study.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Load More Button

struct LoadMoreButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("Load More")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.blue)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Loading, Error, and Empty Views

struct ResearchDetailLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading research data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ResearchDetailErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Failed to load data")
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                onRetry()
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ResearchDetailEmptyView: View {
    let researchType: ResearchDetailView.ResearchType
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: getIcon())
                .font(.title)
                .foregroundColor(.gray)
            
            Text("No \(getTitle().lowercased()) found")
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
            
            Text("No \(getTitle().lowercased()) are available for this protein")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func getTitle() -> String {
        switch researchType {
        case .publications:
            return "Publications"
        case .clinicalTrials:
            return "Clinical Trials"
        case .activeStudies:
            return "Active Studies"
        }
    }
    
    private func getIcon() -> String {
        switch researchType {
        case .publications:
            return "book"
        case .clinicalTrials:
            return "cross.case"
        case .activeStudies:
            return "flask"
        }
    }
}

// MARK: - Research Detail View Model

class ResearchDetailViewModel: ObservableObject {
    static let shared = ResearchDetailViewModel()
    
    @Published var publications: [String: [ResearchPublication]] = [:]
    @Published var clinicalTrials: [String: [ClinicalTrial]] = [:]
    @Published var activeStudies: [String: [ActiveStudy]] = [:]
    
    @Published var isLoading: [String: Bool] = [:]
    @Published var errorMessage: [String: String] = [:]
    
    @Published var hasMorePublications: [String: Bool] = [:]
    @Published var hasMoreClinicalTrials: [String: Bool] = [:]
    @Published var hasMoreActiveStudies: [String: Bool] = [:]
    
    private init() {}
    
    func loadPublications(for proteinId: String) async {
        let cacheKey = "\(proteinId)_publications"
        
        await MainActor.run {
            isLoading[cacheKey] = true
            errorMessage[cacheKey] = nil
        }
        
        do {
            let publications = try await ResearchDetailService.shared.fetchPublications(for: proteinId)
            
            await MainActor.run {
                self.publications[proteinId] = publications
                self.isLoading[cacheKey] = false
                self.hasMorePublications[proteinId] = publications.count >= 30
            }
        } catch {
            await MainActor.run {
                self.errorMessage[cacheKey] = error.localizedDescription
                self.isLoading[cacheKey] = false
            }
        }
    }
    
    func loadClinicalTrials(for proteinId: String) async {
        let cacheKey = "\(proteinId)_clinicalTrials"
        
        await MainActor.run {
            isLoading[cacheKey] = true
            errorMessage[cacheKey] = nil
        }
        
        do {
            let trials = try await ResearchDetailService.shared.fetchClinicalTrials(for: proteinId)
            
            await MainActor.run {
                self.clinicalTrials[proteinId] = trials
                self.isLoading[cacheKey] = false
                self.hasMoreClinicalTrials[proteinId] = trials.count >= 30
            }
        } catch {
            await MainActor.run {
                self.errorMessage[cacheKey] = error.localizedDescription
                self.isLoading[cacheKey] = false
            }
        }
    }
    
    func loadActiveStudies(for proteinId: String) async {
        let cacheKey = "\(proteinId)_activeStudies"
        
        await MainActor.run {
            isLoading[cacheKey] = true
            errorMessage[cacheKey] = nil
        }
        
        do {
            let studies = try await ResearchDetailService.shared.fetchActiveStudies(for: proteinId)
            
            await MainActor.run {
                self.activeStudies[proteinId] = studies
                self.isLoading[cacheKey] = false
                self.hasMoreActiveStudies[proteinId] = studies.count >= 30
            }
        } catch {
            await MainActor.run {
                self.errorMessage[cacheKey] = error.localizedDescription
                self.isLoading[cacheKey] = false
            }
        }
    }
    
    func loadMorePublications(for proteinId: String) async {
        // Implementation for loading more publications
        // This would typically load the next page of results
    }
    
    func loadMoreClinicalTrials(for proteinId: String) async {
        // Implementation for loading more clinical trials
    }
    
    func loadMoreActiveStudies(for proteinId: String) async {
        // Implementation for loading more active studies
    }
}
