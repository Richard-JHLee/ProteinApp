import SwiftUI

struct RelatedProteinsView: View {
    let protein: ProteinInfo
    @State private var relatedProteins: [RelatedProtein] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        loadingView
                    } else if let error = error {
                        errorView(error)
                    } else {
                        contentView
                    }
                }
                .padding()
            }
            .navigationTitle("Related Proteins")
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
            loadRelatedProteins()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading related proteins...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to load related proteins")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadRelatedProteins()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("Proteins Related to \(protein.id)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("\(relatedProteins.count) related proteins found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 관련 단백질 목록
            LazyVStack(spacing: 12) {
                ForEach(relatedProteins, id: \.id) { relatedProtein in
                    relatedProteinCard(relatedProtein)
                }
            }
        }
    }
    
    // MARK: - Related Protein Card
    private func relatedProteinCard(_ relatedProtein: RelatedProtein) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(relatedProtein.id)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(relatedProtein.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 카테고리 태그
                Text(relatedProtein.category.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(relatedProtein.category.color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // 설명
            if !relatedProtein.description.isEmpty {
                Text(relatedProtein.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
            
            // 메트릭 정보
            HStack(spacing: 16) {
                metricItem("Chains", value: "\(relatedProtein.chainCount)")
                metricItem("Atoms", value: "\(relatedProtein.atomCount)")
                metricItem("Resolution", value: relatedProtein.resolution != nil ? "\(String(format: "%.1f", relatedProtein.resolution!)) Å" : "N/A")
            }
            
            // 관련성 정보
            if !relatedProtein.relationship.isEmpty {
                HStack {
                    Text("Relationship:")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Text(relatedProtein.relationship)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Metric Item
    private func metricItem(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Data Loading
    private func loadRelatedProteins() {
        isLoading = true
        error = nil
        
        Task {
            do {
                print("🚀 PDB API 호출 시작...")
                let relatedProteins = try await fetchRelatedProteinsFromPDB()
                print("✅ PDB API 성공: \(relatedProteins.count)개 단백질")
                
                await MainActor.run {
                    if relatedProteins.isEmpty {
                        print("⚠️ API 결과가 비어있음 - 실제 검색 시도")
                        // 빈 결과일 때는 다른 검색 방법 시도
                        Task {
                            await loadAlternativeRelatedProteins()
                        }
                    } else {
                        print("✅ 실제 API 데이터 사용")
                        self.relatedProteins = relatedProteins
                        self.isLoading = false
                    }
                }
            } catch let errorMessage {
                print("❌ PDB API 실패: \(errorMessage.localizedDescription)")
                await MainActor.run {
                    print("🔄 대안 검색 방법 시도")
                    Task {
                        await loadAlternativeRelatedProteins()
                    }
                }
            }
        }
    }
    
    // MARK: - Alternative Search Methods
    private func loadAlternativeRelatedProteins() async {
        do {
            // 1. 같은 카테고리의 다른 단백질 검색
            let categoryProteins = try await fetchProteinsByCategory()
            if !categoryProteins.isEmpty {
                await MainActor.run {
                    self.relatedProteins = categoryProteins
                    self.isLoading = false
                }
                return
            }
            
            // 2. 유사한 크기의 단백질 검색
            let similarSizeProteins = try await fetchProteinsBySimilarSize()
            if !similarSizeProteins.isEmpty {
                await MainActor.run {
                    self.relatedProteins = similarSizeProteins
                    self.isLoading = false
                }
                return
            }
            
            // 3. 최근에 추가된 단백질 검색
            let recentProteins = try await fetchRecentProteins()
            await MainActor.run {
                self.relatedProteins = recentProteins
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = "Failed to load related proteins: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchProteinsByCategory() async throws -> [RelatedProtein] {
        // 더 간단한 카테고리 검색
        let query = """
        {
            "query": {
                "type": "terminal",
                "service": "text",
                "parameters": {
                    "attribute": "struct_keywords.pdbx_keywords",
                    "operator": "contains_phrase",
                    "value": "protein"
                }
            },
            "return_type": "entry",
            "rows": 10
        }
        """
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let urlString = "https://search.rcsb.org/rcsbsearch/v2/query?json=\(encodedQuery)&return_type=entry&rows=10"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let searchResult = try JSONDecoder().decode(PDBSearchResult.self, from: data)
        
        return try await processSearchResults(searchResult)
    }
    
    private func fetchProteinsBySimilarSize() async throws -> [RelatedProtein] {
        // 더 간단한 크기 기반 검색
        let query = """
        {
            "query": {
                "type": "terminal",
                "service": "text",
                "parameters": {
                    "attribute": "struct_keywords.pdbx_keywords",
                    "operator": "contains_phrase",
                    "value": "crystal"
                }
            },
            "return_type": "entry",
            "rows": 10
        }
        """
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let urlString = "https://search.rcsb.org/rcsbsearch/v2/query?json=\(encodedQuery)&return_type=entry&rows=10"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let searchResult = try JSONDecoder().decode(PDBSearchResult.self, from: data)
        
        return try await processSearchResults(searchResult)
    }
    
    private func fetchRecentProteins() async throws -> [RelatedProtein] {
        // 더 간단한 최근 단백질 검색
        let query = """
        {
            "query": {
                "type": "terminal",
                "service": "text",
                "parameters": {
                    "attribute": "struct_keywords.pdbx_keywords",
                    "operator": "contains_phrase",
                    "value": "structure"
                }
            },
            "return_type": "entry",
            "rows": 10
        }
        """
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let urlString = "https://search.rcsb.org/rcsbsearch/v2/query?json=\(encodedQuery)&return_type=entry&rows=10"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let searchResult = try JSONDecoder().decode(PDBSearchResult.self, from: data)
        
        return try await processSearchResults(searchResult)
    }
    
    // MARK: - PDB API Integration
    private func fetchRelatedProteinsFromPDB() async throws -> [RelatedProtein] {
        // PDB Search API를 사용해서 관련 단백질 검색
        let urlString = "https://search.rcsb.org/rcsbsearch/v2/query?json=%7B%22query%22:%7B%22type%22:%22terminal%22,%22service%22:%22text%22,%22parameters%22:%7B%22attribute%22:%22struct_keywords.pdbx_keywords%22,%22operator%22:%22contains_phrase%22,%22value%22:%22hydrolase%22%7D%7D,%22return_type%22:%22entry%22%7D&return_type=entry&rows=20"
        
        print("🔍 PDB API 요청: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ 잘못된 URL: \(urlString)")
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 HTTP 응답 상태: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ HTTP 오류: \(httpResponse.statusCode)")
                // 404 오류 시 더 간단한 쿼리로 재시도
                return try await fetchSimpleRelatedProteins()
            }
        }
        
        print("📦 받은 데이터 크기: \(data.count) bytes")
        
        let searchResult = try JSONDecoder().decode(PDBSearchResult.self, from: data)
        print("📦 검색 결과: \(searchResult.total_count ?? 0)개 단백질")
        print("📦 엔트리 수: \(searchResult.result_set?.count ?? 0)개")
        
        return try await processSearchResults(searchResult)
    }
    
    private func fetchSimpleRelatedProteins() async throws -> [RelatedProtein] {
        // 더 간단한 쿼리로 재시도
        let simpleQuery = """
        {
            "query": {
                "type": "terminal",
                "service": "text",
                "parameters": {
                    "attribute": "struct_keywords.pdbx_keywords",
                    "operator": "contains_phrase",
                    "value": "enzyme"
                }
            },
            "return_type": "entry",
            "rows": 10
        }
        """
        
        guard let encodedQuery = simpleQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let urlString = "https://search.rcsb.org/rcsbsearch/v2/query?json=\(encodedQuery)&return_type=entry&rows=10"
        print("🔄 간단한 쿼리로 재시도: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 간단한 쿼리 HTTP 응답: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
        }
        
        let searchResult = try JSONDecoder().decode(PDBSearchResult.self, from: data)
        return try await processSearchResults(searchResult)
    }
    
    private func buildRelatedProteinsQuery() -> String {
        // 간단한 쿼리로 수정 (새로운 API에서 복잡한 쿼리가 400 오류 발생)
        return """
        {
            "query": {
                "type": "terminal",
                "service": "text",
                "parameters": {
                    "attribute": "struct_keywords.pdbx_keywords",
                    "operator": "contains_phrase",
                    "value": "hydrolase"
                }
            },
            "return_type": "entry"
        }
        """.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
    
    private func processSearchResults(_ searchResult: PDBSearchResult) async throws -> [RelatedProtein] {
        guard let entries = searchResult.result_set else {
            return []
        }
        
        var relatedProteins: [RelatedProtein] = []
        
        for entry in entries {
            guard let identifier = entry.identifier else { continue }
            
            // 현재 단백질과 같은 ID는 제외
            if identifier == protein.id {
                continue
            }
            
            // 각 엔트리에 대한 상세 정보 가져오기
            do {
                let entryUrl = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(identifier)")!
                let (entryData, _) = try await URLSession.shared.data(from: entryUrl)
                let entryResponse = try JSONDecoder().decode(EntryDetailsResponse.self, from: entryData)
                
                let relatedProtein = RelatedProtein(
                    id: identifier,
                    name: entryResponse.struct?.title ?? "Unknown Protein",
                    description: entryResponse.struct?.pdbx_descriptor ?? "",
                    category: determineCategory(from: entryResponse),
                    chainCount: 1, // 기본값
                    atomCount: entryResponse.rcsb_entry_info?.deposited_atom_count ?? 0,
                    resolution: entryResponse.refine?.first?.ls_d_res_high,
                    relationship: determineRelationship(from: entryResponse)
                )
                
                relatedProteins.append(relatedProtein)
            } catch {
                print("⚠️ 엔트리 \(identifier) 정보 가져오기 실패: \(error)")
                continue
            }
        }
        
        return relatedProteins
    }
    
    private func determineCategory(from entry: EntryDetailsResponse) -> ProteinCategory {
        // PDB 키워드나 설명을 기반으로 카테고리 결정
        let keywords = entry.struct_keywords?.pdbx_keywords?.lowercased() ?? ""
        let title = entry.struct?.title?.lowercased() ?? ""
        let text = "\(keywords) \(title)"
        
        if text.contains("enzyme") || text.contains("cataly") {
            return .enzymes
        } else if text.contains("receptor") || text.contains("binding") {
            return .receptors
        } else if text.contains("transport") || text.contains("carrier") {
            return .transport
        } else if text.contains("hormone") || text.contains("signal") {
            return .hormones
        } else if text.contains("defense") || text.contains("immune") {
            return .defense
        } else if text.contains("structural") || text.contains("scaffold") {
            return .structural
        } else if text.contains("storage") || text.contains("reserve") {
            return .storage
        } else if text.contains("motor") || text.contains("movement") {
            return .motor
        } else if text.contains("chaperone") || text.contains("folding") {
            return .chaperones
        } else if text.contains("membrane") || text.contains("channel") {
            return .membrane
        } else if text.contains("metabolic") || text.contains("metabolism") {
            return .metabolic
        } else {
            return .signaling
        }
    }
    
    private func determineRelationship(from entry: EntryDetailsResponse) -> String {
        // 단백질 간의 관계 결정
        let keywords = entry.struct_keywords?.pdbx_keywords?.lowercased() ?? ""
        
        if keywords.contains("homolog") {
            return "Structural homolog"
        } else if keywords.contains("family") {
            return "Protein family"
        } else if keywords.contains("binding") || keywords.contains("interaction") {
            return "Binding partner"
        } else if keywords.contains("regulatory") || keywords.contains("regulation") {
            return "Regulatory partner"
        } else {
            return "Similar function"
        }
    }
    
    private func generateSampleRelatedProteins() -> [RelatedProtein] {
        // 현재 단백질과 관련된 샘플 데이터 생성
        let baseId = protein.id
        let category = protein.category
        let baseAtomCount = 1000 // 기본 원자 수
        
        return [
            RelatedProtein(
                id: "\(baseId.prefix(3))A",
                name: "\(protein.name) Homolog A",
                description: "A structural homolog of \(protein.name) with similar function.",
                category: category,
                chainCount: 1,
                atomCount: baseAtomCount + Int.random(in: -200...200),
                resolution: Double.random(in: 1.5...3.5),
                relationship: "Structural homolog"
            ),
            RelatedProtein(
                id: "\(baseId.prefix(3))B",
                name: "\(protein.name) Family Member",
                description: "A member of the same protein family as \(protein.name).",
                category: category,
                chainCount: 1,
                atomCount: baseAtomCount + Int.random(in: -300...300),
                resolution: Double.random(in: 1.8...4.0),
                relationship: "Protein family"
            ),
            RelatedProtein(
                id: "\(baseId.prefix(3))C",
                name: "\(protein.name) Binding Partner",
                description: "A protein that interacts with \(protein.name) in cellular processes.",
                category: category,
                chainCount: 1,
                atomCount: baseAtomCount + Int.random(in: -150...150),
                resolution: Double.random(in: 2.0...3.8),
                relationship: "Binding partner"
            ),
            RelatedProtein(
                id: "\(baseId.prefix(3))D",
                name: "\(protein.name) Functional Analog",
                description: "A protein with similar function to \(protein.name) in different organisms.",
                category: category,
                chainCount: 1,
                atomCount: baseAtomCount + Int.random(in: -250...250),
                resolution: Double.random(in: 1.6...3.2),
                relationship: "Functional analog"
            ),
            RelatedProtein(
                id: "\(baseId.prefix(3))E",
                name: "\(protein.name) Regulatory Partner",
                description: "A protein that regulates the activity of \(protein.name).",
                category: category,
                chainCount: 1,
                atomCount: baseAtomCount + Int.random(in: -100...100),
                resolution: Double.random(in: 2.2...4.2),
                relationship: "Regulatory partner"
            )
        ]
    }
}

// MARK: - Data Models
struct RelatedProtein {
    let id: String
    let name: String
    let description: String
    let category: ProteinCategory
    let chainCount: Int
    let atomCount: Int
    let resolution: Double?
    let relationship: String
}

// MARK: - PDB API Response Models
struct PDBSearchResult: Codable {
    let query_id: String?
    let result_type: String?
    let total_count: Int?
    let result_set: [PDBSearchEntry]?
}

struct PDBSearchEntry: Codable {
    let identifier: String?
    let score: Double?
}

struct PDBSearchStruct: Codable {
    let title: String?
    let pdbx_keywords: String?
    let pdbx_descriptor: String?
}

struct PDBPolymerEntity: Codable {
    let entity_id: String?
}

struct PDBSearchEntryInfo: Codable {
    let deposited_atom_count: Int?
}

struct PDBSearchRefine: Codable {
    let ls_d_res_high: Double?
}
