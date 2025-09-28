import SwiftUI

// MARK: - Disease Association View

struct DiseaseAssociationView: View {
    let protein: ProteinInfo
    @State private var diseases: [DiseaseAssociation] = []
    @State private var summary: DiseaseAssociationSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAllDiseases = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Summary cards (without section title since it's handled by InfoCard)
            DiseaseSummaryHeader(summary: summary)
            
            if isLoading {
                DiseaseLoadingView()
            } else if let errorMessage = errorMessage {
                if errorMessage.contains("plant protein") {
                    DiseasePlantProteinView()
                } else {
                    DiseaseErrorView(message: errorMessage) {
                        loadDiseaseAssociations()
                    }
                }
            } else if diseases.isEmpty {
                DiseaseEmptyView()
            } else {
                // Disease list
                VStack(spacing: 12) {
                    ForEach(Array(diseases.prefix(showingAllDiseases ? diseases.count : 3))) { disease in
                        DiseaseCard(disease: disease)
                    }
                    
                    // Show more/less button
                    if diseases.count > 3 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingAllDiseases.toggle()
                            }
                        }) {
                            HStack {
                                Text(showingAllDiseases ? "Show Less" : "Show All (\(diseases.count))")
                                    .font(.caption.weight(.medium))
                                Image(systemName: showingAllDiseases ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            print("🔍 DiseaseAssociationView: onAppear - isLoading: \(isLoading), diseases.count: \(diseases.count), errorMessage: \(errorMessage ?? "nil")")
            loadDiseaseAssociations()
        }
    }
    
    private func loadDiseaseAssociations() {
        print("🔍 DiseaseAssociationView: Starting to load disease associations for protein: \(protein.id)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("🔍 DiseaseAssociationView: Converting PDB ID \(protein.id) to UniProt ID...")
                // Convert PDB ID to UniProt ID using the service
                let uniprotId = try await DiseaseAssociationService.shared.fetchUniProtIdFromPDB(pdbId: protein.id)
                print("🔍 DiseaseAssociationView: Got UniProt ID: \(uniprotId)")
                
                print("🔍 DiseaseAssociationView: Fetching disease associations for UniProt ID: \(uniprotId)")
                let fetchedDiseases = try await DiseaseAssociationService.shared.fetchDiseaseAssociations(uniprotId: uniprotId)
                print("🔍 DiseaseAssociationView: Fetched \(fetchedDiseases.count) disease associations")
                
                await MainActor.run {
                    self.diseases = fetchedDiseases
                    self.summary = DiseaseAssociationService.shared.createDiseaseSummary(from: fetchedDiseases)
                    self.isLoading = false
                    print("🔍 DiseaseAssociationView: Successfully loaded disease associations")
                }
            } catch {
                print("❌ DiseaseAssociationView: Error loading disease associations: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Disease Summary Header

struct DiseaseSummaryHeader: View {
    let summary: DiseaseAssociationSummary?
    
    var body: some View {
        HStack(spacing: 16) {
            // Total diseases
            DiseaseMetric(
                title: "Total",
                value: "\(summary?.totalDiseases ?? 0)",
                icon: "cross.case.fill",
                color: .red
            )
            
            // Known diseases
            DiseaseMetric(
                title: "Known",
                value: "\(summary?.knownDiseases ?? 0)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            // Predicted diseases
            DiseaseMetric(
                title: "Predicted",
                value: "\(summary?.predictedDiseases ?? 0)",
                icon: "questionmark.circle.fill",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
}

struct DiseaseMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Disease Card

struct DiseaseCard: View {
    let disease: DiseaseAssociation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Disease header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(disease.diseaseName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let diseaseType = disease.diseaseType {
                        Text(diseaseType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Evidence level indicator
                EvidenceLevelIndicator(level: disease.evidenceLevel)
            }
            
            // Association score
            if let score = disease.associationScore {
                HStack {
                    Text("Association Score:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f", score))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    // Score bar
                    ProgressView(value: score, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: scoreColor(score)))
                        .frame(width: 60, height: 4)
                }
            }
            
            // Clinical features (if expanded)
            if isExpanded {
                if let clinicalFeatures = disease.clinicalFeatures, !clinicalFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clinical Features")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        ForEach(clinicalFeatures, id: \.self) { feature in
                            Text("• \(feature)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.top, 8)
                }
                
                // References
                if let references = disease.references, !references.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("References")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        ForEach(references.prefix(3)) { reference in
                            Text(reference.displayTitle)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            
            // Expand/collapse button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(.caption.weight(.medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(evidenceLevelColor(disease.evidenceLevel).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        else if score >= 0.6 { return .orange }
        else { return .red }
    }
    
    private func evidenceLevelColor(_ level: EvidenceLevel) -> Color {
        switch level {
        case .known: return .green
        case .predicted: return .orange
        case .inferred: return .blue
        case .uncertain: return .gray
        }
    }
}

// MARK: - Evidence Level Indicator

struct EvidenceLevelIndicator: View {
    let level: EvidenceLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(.caption)
                .foregroundColor(evidenceLevelColor(level))
            
            Text(level.rawValue)
                .font(.caption.weight(.medium))
                .foregroundColor(evidenceLevelColor(level))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(evidenceLevelColor(level).opacity(0.1))
        .cornerRadius(6)
    }
    
    private func evidenceLevelColor(_ level: EvidenceLevel) -> Color {
        switch level {
        case .known: return .green
        case .predicted: return .orange
        case .inferred: return .blue
        case .uncertain: return .gray
        }
    }
}

// MARK: - Loading, Error, and Empty Views

struct DiseaseLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            Text("Loading disease associations...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
}

struct DiseaseErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Failed to load disease associations")
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
        .padding(.vertical, 40)
    }
}

struct DiseaseEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cross.case")
                .font(.title)
                .foregroundColor(.gray)
            
            Text("No disease associations found")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Text("This protein is not associated with known human diseases")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

struct DiseasePlantProteinView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundColor(.green)
            
            Text("Plant Protein")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Text("This is a plant protein and is not typically associated with human diseases")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}
