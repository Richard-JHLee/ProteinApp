import SwiftUI

// MARK: - Research Detail Views

struct ResearchDetailView: View {
    let protein: ProteinInfo
    let researchType: ResearchType
    @State private var publications: [ResearchPublication] = []
    @State private var clinicalTrials: [ClinicalTrial] = []
    @State private var activeStudies: [ActiveStudy] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var hasMoreData = true
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    
    // ResearchStatusViewModel을 통해 캐시된 데이터 접근
    @StateObject private var researchViewModel = ResearchStatusViewModel.shared
    
    enum ResearchType: Identifiable {
        case publications
        case clinicalTrials
        case activeStudies
        
        var id: String {
            switch self {
            case .publications:
                return "publications"
            case .clinicalTrials:
                return "clinicalTrials"
            case .activeStudies:
                return "activeStudies"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading research data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        
                        Text("Failed to load data")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            loadData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        switch researchType {
                        case .publications:
                            ForEach(publications) { publication in
                                PublicationCard(publication: publication)
                            }
                        case .clinicalTrials:
                            ForEach(clinicalTrials) { trial in
                                ClinicalTrialCard(trial: trial)
                            }
                        case .activeStudies:
                            ForEach(activeStudies) { study in
                                ActiveStudyCard(study: study)
                            }
                        }
                        
                        // More 버튼
                        if hasMoreData {
                            HStack {
                                Spacer()
                                Button(action: loadMoreData) {
                                    HStack {
                                        if isLoadingMore {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                        Text(isLoadingMore ? "Loading..." : "Load More")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                }
                                .disabled(isLoadingMore)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    private var title: String {
        switch researchType {
        case .publications:
            return "Publications (\(publications.count))"
        case .clinicalTrials:
            return "Clinical Trials (\(clinicalTrials.count))"
        case .activeStudies:
            return "Active Studies (\(activeStudies.count))"
        }
    }
    
    private func loadData() {
        print("🔍 ResearchDetailView: Loading data for \(protein.id), type: \(researchType)")
        
        // 먼저 캐시된 데이터 확인
        switch researchType {
        case .publications:
            if let cachedPublications = researchViewModel.getCachedPublications(for: protein.id) {
                print("📚 Found cached publications: \(cachedPublications.count)")
                self.publications = cachedPublications
                return
            } else {
                print("📚 No cached publications found")
            }
        case .clinicalTrials:
            if let cachedTrials = researchViewModel.getCachedClinicalTrials(for: protein.id) {
                print("🏥 Found cached clinical trials: \(cachedTrials.count)")
                self.clinicalTrials = cachedTrials
                return
            } else {
                print("🏥 No cached clinical trials found")
            }
        case .activeStudies:
            if let cachedStudies = researchViewModel.getCachedActiveStudies(for: protein.id) {
                print("🔬 Found cached active studies: \(cachedStudies.count)")
                self.activeStudies = cachedStudies
                return
            } else {
                print("🔬 No cached active studies found")
            }
        }
        
        // 캐시된 데이터가 없으면 로드
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                switch researchType {
                case .publications:
                    let fetchedPublications = try await ResearchDetailService.shared.fetchPublications(for: protein.id)
                    await MainActor.run {
                        self.publications = fetchedPublications
                        self.researchViewModel.cachePublications(fetchedPublications, for: protein.id)
                        self.isLoading = false
                    }
                case .clinicalTrials:
                    let fetchedTrials = try await ResearchDetailService.shared.fetchClinicalTrials(for: protein.id)
                    await MainActor.run {
                        self.clinicalTrials = fetchedTrials
                        self.researchViewModel.cacheClinicalTrials(fetchedTrials, for: protein.id)
                        self.isLoading = false
                    }
                case .activeStudies:
                    let fetchedStudies = try await ResearchDetailService.shared.fetchActiveStudies(for: protein.id)
                    await MainActor.run {
                        self.activeStudies = fetchedStudies
                        self.researchViewModel.cacheActiveStudies(fetchedStudies, for: protein.id)
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadMoreData() {
        guard !isLoadingMore && hasMoreData else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            do {
                switch researchType {
                case .publications:
                    let newPublications = try await ResearchDetailService.shared.fetchPublicationsPage(for: protein.id, page: currentPage)
                    await MainActor.run {
                        if newPublications.isEmpty {
                            self.hasMoreData = false
                        } else {
                            self.publications.append(contentsOf: newPublications)
                            // 캐시 업데이트
                            let allPublications = self.publications
                            self.researchViewModel.cachePublications(allPublications, for: protein.id)
                        }
                        self.isLoadingMore = false
                    }
                case .clinicalTrials:
                    let newTrials = try await ResearchDetailService.shared.fetchClinicalTrialsPage(for: protein.id, page: currentPage)
                    await MainActor.run {
                        if newTrials.isEmpty {
                            self.hasMoreData = false
                        } else {
                            self.clinicalTrials.append(contentsOf: newTrials)
                            let allTrials = self.clinicalTrials
                            self.researchViewModel.cacheClinicalTrials(allTrials, for: protein.id)
                        }
                        self.isLoadingMore = false
                    }
                case .activeStudies:
                    let newStudies = try await ResearchDetailService.shared.fetchActiveStudiesPage(for: protein.id, page: currentPage)
                    await MainActor.run {
                        if newStudies.isEmpty {
                            self.hasMoreData = false
                        } else {
                            self.activeStudies.append(contentsOf: newStudies)
                            let allStudies = self.activeStudies
                            self.researchViewModel.cacheActiveStudies(allStudies, for: protein.id)
                        }
                        self.isLoadingMore = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoadingMore = false
                }
            }
        }
    }
}

// MARK: - Publication Card

struct PublicationCard: View {
    let publication: ResearchPublication
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(publication.title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.9)
            
            // Authors and Journal
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(publication.authors.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(publication.journal), \(publication.year)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("PMID: \(publication.pmid)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Abstract (expandable)
            if let abstract = publication.abstract {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("Abstract")
                            .font(.caption.weight(.medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    Text(abstract)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            // DOI
            if let doi = publication.doi {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.purple)
                        .font(.caption)
                    Text("DOI: \(doi)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Clinical Trial Card

struct ClinicalTrialCard: View {
    let trial: ClinicalTrial
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(trial.title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Status and Phase
            HStack {
                StatusBadge(status: trial.status)
                if let phase = trial.phase {
                    PhaseBadge(phase: phase)
                }
            }
            
            // Trial Details
            VStack(alignment: .leading, spacing: 4) {
                DetailRow(icon: "cross.case.fill", iconColor: .red, text: trial.condition)
                DetailRow(icon: "pills.fill", iconColor: .blue, text: trial.intervention)
                DetailRow(icon: "building.2.fill", iconColor: .green, text: trial.sponsor)
                DetailRow(icon: "location.fill", iconColor: .orange, text: trial.location)
                DetailRow(icon: "doc.text.fill", iconColor: .purple, text: "NCT ID: \(trial.nctId)")
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Active Study Card

struct ActiveStudyCard: View {
    let study: ActiveStudy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(study.title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Study Type and Status
            HStack {
                TypeBadge(type: study.type)
                StatusBadge(status: study.status)
            }
            
            // Study Details
            VStack(alignment: .leading, spacing: 4) {
                DetailRow(icon: "building.2.fill", iconColor: .blue, text: study.institution)
                DetailRow(icon: "calendar.fill", iconColor: .green, text: study.year)
                DetailRow(icon: "doc.text.fill", iconColor: .orange, text: study.description)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.caption)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status)
            .font(.caption2.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.8))
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "recruiting", "active", "ongoing":
            return .green
        case "completed":
            return .blue
        case "planning":
            return .orange
        case "terminated", "suspended":
            return .red
        default:
            return .gray
        }
    }
}

struct PhaseBadge: View {
    let phase: String
    
    var body: some View {
        Text(phase)
            .font(.caption2.weight(.medium))
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
    }
}

struct TypeBadge: View {
    let type: String
    
    var body: some View {
        Text(type)
            .font(.caption2.weight(.medium))
            .foregroundColor(.purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(6)
    }
}
