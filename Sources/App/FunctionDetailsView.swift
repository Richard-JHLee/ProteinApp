import SwiftUI

struct FunctionDetailsView: View {
    let protein: ProteinInfo
    @State private var functionDetails: FunctionDetails?
    @State private var isLoadingFunction = false
    @State private var functionError: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingFunction {
                        functionLoadingView
                    } else if let error = functionError {
                        functionErrorView(error)
                    } else if let details = functionDetails {
                        functionContentView(details)
                    } else {
                        Text("No function data available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Function Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadFunctionDetails()
        }
    }
    
    // MARK: - Loading View
    private var functionLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading function details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func functionErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to load function details")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadFunctionDetails()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Content View
    private func functionContentView(_ details: FunctionDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("Protein Function Information")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Molecular Function
            InfoCard(icon: "function", title: "Molecular Function", tint: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(details.molecularFunction)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Biological Process
            InfoCard(icon: "arrow.triangle.branch", title: "Biological Process", tint: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(details.biologicalProcess)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Cellular Component
            InfoCard(icon: "building.2", title: "Cellular Component", tint: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(details.cellularComponent)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // GO Terms
            if !details.goTerms.isEmpty {
                InfoCard(icon: "tag", title: "GO Terms", tint: .purple) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(details.goTerms, id: \.id) { term in
                            HStack {
                                Text(term.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text(term.category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(term.categoryColor.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
            
            // EC Numbers
            if !details.ecNumbers.isEmpty {
                InfoCard(icon: "number", title: "EC Numbers", tint: .red) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(details.ecNumbers, id: \.self) { ecNumber in
                            Text(ecNumber)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            
            // Catalytic Activity
            if !details.catalyticActivity.isEmpty {
                InfoCard(icon: "flask", title: "Catalytic Activity", tint: .cyan) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(details.catalyticActivity)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            // Structure Information
            InfoCard(icon: "cube", title: "Structure Information", tint: .indigo) {
                VStack(alignment: .leading, spacing: 8) {
                    if let resolution = details.resolution {
                        HStack {
                            Text("Resolution:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(String(format: "%.2f", resolution)) Å")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let method = details.method {
                        HStack {
                            Text("Method:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(method)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadFunctionDetails() {
        isLoadingFunction = true
        functionError = nil
        
        Task {
            do {
                // 실제 API 호출
                let details = try await fetchFunctionDetails(pdbId: protein.id)
                
                await MainActor.run {
                    functionDetails = details
                    isLoadingFunction = false
                }
            } catch {
                await MainActor.run {
                    functionError = "Failed to load function details: \(error.localizedDescription)"
                    isLoadingFunction = false
                }
            }
        }
    }
    
    // MARK: - API Function
    private func fetchFunctionDetails(pdbId: String) async throws -> FunctionDetails {
        // PDB REST API에서 기능 정보 가져오기
        let entryUrl = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(pdbId.uppercased())")!
        let (entryData, _) = try await URLSession.shared.data(from: entryUrl)
        let entryResponse = try JSONDecoder().decode(EntryDetailsResponse.self, from: entryData)
        
        // 각 polymer entity에서 기능 정보 가져오기
        var molecularFunction = "Function information not available"
        let biologicalProcess = "Biological process information not available"
        let cellularComponent = "Cellular component information not available"
        var goTerms: [GOTerm] = []
        var ecNumbers: [String] = []
        var catalyticActivity = "Catalytic activity information not available"
        
        if let polymerEntityIds = entryResponse.rcsb_entry_container_identifiers?.polymer_entity_ids {
            for entityId in polymerEntityIds {
                let entityUrl = URL(string: "https://data.rcsb.org/rest/v1/core/polymer_entity/\(pdbId.uppercased())/\(entityId)")!
                let (entityData, _) = try await URLSession.shared.data(from: entityUrl)
                let entityResponse = try JSONDecoder().decode(PolymerEntityDetailsResponse.self, from: entityData)
                
                if entityResponse.entity_poly != nil {
                    // UniProt 정보에서 기능 정보 추출
                    if let uniprotAccession = entityResponse.rcsb_polymer_entity?.rcsb_polymer_entity_container_identifiers?.uniprot_accession?.first {
                        // UniProt API에서 상세 정보 가져오기
                        let uniprotUrl = URL(string: "https://rest.uniprot.org/uniprotkb/\(uniprotAccession).json")!
                        do {
                            let (uniprotData, _) = try await URLSession.shared.data(from: uniprotUrl)
                            let uniprotResponse = try JSONDecoder().decode(UniProtResponse.self, from: uniprotData)
                            
                            // GO terms 추출
                            if let comments = uniprotResponse.comments {
                                for comment in comments {
                                    if comment.commentType == "FUNCTION" {
                                        molecularFunction = comment.texts?.first?.value ?? molecularFunction
                                    } else if comment.commentType == "CATALYTIC_ACTIVITY" {
                                        catalyticActivity = comment.texts?.first?.value ?? catalyticActivity
                                    }
                                }
                            }
                            
                            // GO annotations 추출
                            if let features = uniprotResponse.features {
                                for feature in features {
                                    if feature.type == "GO" {
                                        if let goId = feature.properties?.goId,
                                           let goName = feature.properties?.goName,
                                           let goCategory = feature.properties?.goCategory {
                                            goTerms.append(GOTerm(id: goId, name: goName, category: goCategory))
                                        }
                                    }
                                }
                            }
                            
                            // EC numbers 추출
                            if let proteinDescription = uniprotResponse.proteinDescription {
                                if let recommendedName = proteinDescription.recommendedName {
                                    if let uniprotEcNumbers = recommendedName.ecNumbers {
                                        for ecNumber in uniprotEcNumbers {
                                            if let value = ecNumber.value {
                                                ecNumbers.append(value)
                                            }
                                        }
                                    }
                                }
                            }
                        } catch {
                            // UniProt API 실패 시 기본 정보 사용
                            print("Failed to fetch UniProt data: \(error)")
                        }
                    }
                }
            }
        }
        
        // 기본 정보 설정
        if molecularFunction == "Function information not available" {
            molecularFunction = protein.description
        }
        
        return FunctionDetails(
            molecularFunction: molecularFunction,
            biologicalProcess: biologicalProcess,
            cellularComponent: cellularComponent,
            goTerms: goTerms,
            ecNumbers: ecNumbers,
            catalyticActivity: catalyticActivity,
            resolution: entryResponse.refine?.first?.ls_d_res_high ?? 0.0,
            method: "X-RAY DIFFRACTION" // 기본값으로 설정
        )
    }
}

// MARK: - Data Models
struct FunctionDetails {
    let molecularFunction: String
    let biologicalProcess: String
    let cellularComponent: String
    let goTerms: [GOTerm]
    let ecNumbers: [String]
    let catalyticActivity: String
    let resolution: Double?
    let method: String?
}

struct GOTerm {
    let id: String
    let name: String
    let category: String
    
    var categoryColor: Color {
        switch category {
        case "MF": return .blue      // Molecular Function
        case "BP": return .green     // Biological Process
        case "CC": return .orange    // Cellular Component
        default: return .gray
        }
    }
}

// MARK: - UniProt API Models
struct UniProtResponse: Codable {
    let comments: [UniProtComment]?
    let features: [UniProtFeature]?
    let proteinDescription: UniProtProteinDescription?
}

struct UniProtComment: Codable {
    let commentType: String?
    let texts: [UniProtText]?
    
    enum CodingKeys: String, CodingKey {
        case commentType = "commentType"
        case texts = "texts"
    }
}

struct UniProtText: Codable {
    let value: String?
}

struct UniProtFeature: Codable {
    let type: String?
    let properties: UniProtFeatureProperties?
}

struct UniProtFeatureProperties: Codable {
    let goId: String?
    let goName: String?
    let goCategory: String?
    
    enum CodingKeys: String, CodingKey {
        case goId = "goId"
        case goName = "goName"
        case goCategory = "goCategory"
    }
}

struct UniProtProteinDescription: Codable {
    let recommendedName: UniProtRecommendedName?
}

struct UniProtRecommendedName: Codable {
    let ecNumbers: [UniProtECNumber]?
}

struct UniProtECNumber: Codable {
    let value: String?
}
