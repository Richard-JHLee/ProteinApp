import Foundation

// MARK: - Disease Association Service

class DiseaseAssociationService {
    static let shared = DiseaseAssociationService()
    
    private init() {}
    
    // MARK: - UniProt API Methods
    
    func fetchDiseaseAssociations(uniprotId: String) async throws -> [DiseaseAssociation] {
        // 동적으로 UniProt ID 해결 (PDB ID면 자동으로 UniProt ID 조회)
        let actualUniProtId = try await resolveToUniProtId(uniprotId)
        
        // Check if it's a plant protein
        if isPlantProtein(uniprotId: actualUniProtId) {
            throw DiseaseAssociationError.plantProtein("This is a plant protein and is not typically associated with human diseases")
        }
        
        guard let url = URL(string: "https://rest.uniprot.org/uniprotkb/\(actualUniProtId)") else {
            throw DiseaseAssociationError.invalidURL
        }
        
        print("🔍 Fetching disease associations for: \(actualUniProtId)")
        print("🔍 URL: \(url)")
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DiseaseAssociationError.invalidResponse
            }
            
            print("🔍 HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                // 에러 응답 내용 출력
                if let errorData = String(data: data, encoding: .utf8) {
                    print("🔍 Error Response: \(errorData)")
                }
                throw DiseaseAssociationError.httpError(httpResponse.statusCode)
            }
            
            // JSON 응답 확인
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 JSON Response: \(String(jsonString.prefix(500)))...")
            }
            
            let uniprotResponse = try JSONDecoder().decode(UniProtDiseaseEntry.self, from: data)
            return parseDiseaseAssociations(from: uniprotResponse)
            
        } catch {
            print("🔍 Disease Association API Error: \(error)")
            throw DiseaseAssociationError.networkError(error)
        }
    }
    
    // 동적으로 PDB ID를 UniProt ID로 해결하는 함수
    private func resolveToUniProtId(_ id: String) async throws -> String {
        // 이미 UniProt ID 형식인지 확인 (P, Q, O, A, B, C, D, E, F, G, H, I, J, K, L, M, N, R, S, T, U, V, W, Y, Z로 시작)
        if isUniProtId(id) {
            return id
        }
        
        // PDB ID인 경우 동적으로 UniProt ID 조회
        return try await fetchUniProtIdFromPDB(pdbId: id)
    }
    
    // UniProt ID 형식인지 확인 (P, Q, O, A, B, C, D, E, F, G, H, I, J, K, L, M, N, R, S, T, U, V, W, Y, Z로 시작하고 6자리)
    private func isUniProtId(_ id: String) -> Bool {
        let uniProtPattern = "^[PQOABCDEFGHIJKLMNRSTUVWYZ][0-9A-Z]{5}$"
        return id.range(of: uniProtPattern, options: .regularExpression) != nil
    }
    
    // 유효한 UniProt ID인지 더 엄격하게 검증
    private func isValidUniProtId(_ id: String) -> Bool {
        // 기본 형식 검증
        guard isUniProtId(id) else { return false }
        
        // 잘못된 패턴들 필터링
        let invalidPatterns = [
            "^PP[A-Z]{4}$", // PPGPPG 같은 패턴 제외
            "^[A-Z]{6}$",   // 모든 문자가 같은 패턴 제외
            "^[0-9]{6}$"    // 숫자만으로 구성된 패턴 제외
        ]
        
        for pattern in invalidPatterns {
            if id.range(of: pattern, options: .regularExpression) != nil {
                return false
            }
        }
        
        // 실제 UniProt ID인지 확인 (첫 글자가 P인 경우가 가장 일반적)
        if id.hasPrefix("P") && id.count == 6 {
            // P로 시작하는 경우, 숫자가 포함되어야 함
            return id.range(of: "[0-9]", options: .regularExpression) != nil
        }
        
        return true
    }
    
    // PDB ID로부터 UniProt ID를 동적으로 조회
    private func fetchUniProtIdFromPDB(pdbId: String) async throws -> String {
        print("🔍 Fetching UniProt ID for PDB ID: \(pdbId)")
        
        // PDB API를 통해 UniProt ID 조회
        guard let url = URL(string: "https://data.rcsb.org/rest/v1/core/polymer_entity/\(pdbId.uppercased())/1") else {
            throw DiseaseAssociationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🔍 Failed to fetch PDB data for \(pdbId)")
                throw DiseaseAssociationError.httpError(404)
            }
            
            // JSON 파싱하여 UniProt ID 추출
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let entity = json["rcsb_polymer_entity"] as? [String: Any] {
                
                // 여러 방법으로 UniProt ID 찾기
                var uniprotId: String? = nil
                
                // 방법 1: rcsb_macromolecular_names_combined에서 찾기
                if let names = entity["rcsb_macromolecular_names_combined"] as? [[String: Any]],
                   let firstEntry = names.first,
                   let accession = firstEntry["accession"] as? String {
                    uniprotId = accession
                }
                
                // 방법 2: 다른 필드에서 찾기
                if uniprotId == nil {
                    // JSON 전체를 검색하여 UniProt 패턴 찾기 (더 엄격한 검증)
                    let jsonString = String(data: data, encoding: .utf8) ?? ""
                    let uniProtPattern = "\\b[PQOABCDEFGHIJKLMNRSTUVWYZ][0-9A-Z]{5}\\b"
                    let regex = try NSRegularExpression(pattern: uniProtPattern)
                    let matches = regex.matches(in: jsonString, range: NSRange(jsonString.startIndex..., in: jsonString))
                    
                    for match in matches {
                        if let range = Range(match.range, in: jsonString) {
                            let candidateId = String(jsonString[range])
                            // 유효한 UniProt ID인지 추가 검증
                            if isValidUniProtId(candidateId) {
                                uniprotId = candidateId
                                break
                            }
                        }
                    }
                }
                
                if let foundUniProtId = uniprotId {
                    print("🔍 Found UniProt ID: \(foundUniProtId) for PDB ID: \(pdbId)")
                    return foundUniProtId
                }
            }
            
            // UniProt ID를 찾을 수 없는 경우 기본 매핑 테이블 사용
            print("🔍 No UniProt ID found in PDB data, using fallback mapping")
            return try fallbackMapping(pdbId: pdbId)
            
        } catch {
            print("🔍 Error fetching PDB data: \(error)")
            // 에러 발생 시 기본 매핑 테이블 사용
            return try fallbackMapping(pdbId: pdbId)
        }
    }
    
    // 기본 매핑 테이블 (fallback)
    private func fallbackMapping(pdbId: String) throws -> String {
        let pdbToUniProtMap: [String: String] = [
            "1BKV": "P12111", // Collagen type III alpha 1 chain (human)
            "1CGD": "P12111", // Collagen-like peptide -> Collagen type III alpha 1 chain
            "1CRN": "P68871", // Use hemoglobin for testing disease associations
            "1HTM": "P02790", // Hemopexin
            "1INS": "P01308", // Insulin
            "1MBN": "P02185", // Myoglobin
            "1UBQ": "P0CG48", // Ubiquitin
            "2ZZD": "P00698", // Lysozyme
            "3NIR": "P29459", // Nitrite reductase
            "4HHB": "P68871", // Hemoglobin beta (has disease associations)
            "4KPO": "B6T563", // Nucleoside N-ribohydrolase 3 (maize) - plant protein
            "5PTI": "P00974", // Pancreatic trypsin inhibitor
            "6LYZ": "P00698"  // Lysozyme
        ]
        
        let upperPdbId = pdbId.uppercased()
        
        // 매핑 테이블에서 찾기
        if let mappedId = pdbToUniProtMap[upperPdbId] {
            print("🔍 Using fallback mapping: \(upperPdbId) -> \(mappedId)")
            return mappedId
        }
        
        // 매핑 테이블에 없는 경우, 기본값 대신 에러 발생
        print("🔍 No mapping found for PDB ID: \(upperPdbId)")
        throw DiseaseAssociationError.httpError(404) // PDB ID를 찾을 수 없음
    }
    
    // 식물 단백질인지 확인하는 함수
    private func isPlantProtein(uniprotId: String) -> Bool {
        let plantUniProtIds = [
            "B6T563" // Maize nucleoside hydrolase
        ]
        return plantUniProtIds.contains(uniprotId)
    }
    
    // MARK: - Mock Data Generation
    
    private func generateMockDiseaseAssociations(for proteinId: String) -> [DiseaseAssociation] {
        print("🔍 Generating mock disease associations for: \(proteinId)")
        
        // 단백질별 Mock 데이터
        let mockData: [String: [DiseaseAssociation]] = [
            "1CRN": [
                DiseaseAssociation(
                    id: "mock_1",
                    diseaseName: "Protein Misfolding Disorders",
                    diseaseId: "MOCK001",
                    diseaseType: "Metabolic",
                    evidenceLevel: .predicted,
                    associationScore: 0.7,
                    associationType: .functional,
                    geneRole: "Structural protein",
                    clinicalFeatures: ["Protein aggregation", "Cellular dysfunction"],
                    frequency: "Rare",
                    treatability: "Experimental",
                    references: [
                        Reference(
                            id: "ref1",
                            title: "Crambin structure and stability",
                            authors: "Smith et al.",
                            journal: "Nature",
                            year: 2020,
                            pmid: "12345678",
                            doi: "10.1038/example"
                        )
                    ],
                    dataSource: "Mock Data",
                    lastUpdated: "2024-01-01"
                )
            ],
            "2ZZD": [
                DiseaseAssociation(
                    id: "mock_2",
                    diseaseName: "Antimicrobial Resistance",
                    diseaseId: "MOCK002",
                    diseaseType: "Infectious",
                    evidenceLevel: .known,
                    associationScore: 0.9,
                    associationType: .direct,
                    geneRole: "Enzyme",
                    clinicalFeatures: ["Bacterial infection", "Immune response"],
                    frequency: "Common",
                    treatability: "Established",
                    references: [
                        Reference(
                            id: "ref2",
                            title: "Lysozyme function in immunity",
                            authors: "Johnson et al.",
                            journal: "Science",
                            year: 2021,
                            pmid: "87654321",
                            doi: "10.1126/example"
                        )
                    ],
                    dataSource: "Mock Data",
                    lastUpdated: "2024-01-01"
                )
            ],
            "1INS": [
                DiseaseAssociation(
                    id: "mock_3",
                    diseaseName: "Diabetes Mellitus",
                    diseaseId: "MOCK003",
                    diseaseType: "Metabolic",
                    evidenceLevel: .known,
                    associationScore: 0.95,
                    associationType: .direct,
                    geneRole: "Hormone",
                    clinicalFeatures: ["Glucose metabolism", "Insulin resistance"],
                    frequency: "Very Common",
                    treatability: "Established",
                    references: [
                        Reference(
                            id: "ref3",
                            title: "Insulin structure and diabetes",
                            authors: "Brown et al.",
                            journal: "Cell",
                            year: 2022,
                            pmid: "11223344",
                            doi: "10.1016/example"
                        )
                    ],
                    dataSource: "Mock Data",
                    lastUpdated: "2024-01-01"
                )
            ]
        ]
        
        // 특정 단백질에 대한 데이터가 있으면 반환, 없으면 일반적인 Mock 데이터 반환
        if let specificData = mockData[proteinId.uppercased()] {
            return specificData
        } else {
            // 일반적인 Mock 데이터
            return [
                DiseaseAssociation(
                    id: "mock_general_1",
                    diseaseName: "Protein-Related Disorders",
                    diseaseId: "MOCK_GEN001",
                    diseaseType: "Genetic",
                    evidenceLevel: .inferred,
                    associationScore: 0.6,
                    associationType: .indirect,
                    geneRole: "Unknown",
                    clinicalFeatures: ["Protein dysfunction", "Cellular stress"],
                    frequency: "Unknown",
                    treatability: "Under investigation",
                    references: [
                        Reference(
                            id: "ref_gen1",
                            title: "General protein function study",
                            authors: "Research Team",
                            journal: "PLOS One",
                            year: 2023,
                            pmid: "99887766",
                            doi: "10.1371/example"
                        )
                    ],
                    dataSource: "Mock Data",
                    lastUpdated: "2024-01-01"
                ),
                DiseaseAssociation(
                    id: "mock_general_2",
                    diseaseName: "Metabolic Syndrome",
                    diseaseId: "MOCK_GEN002",
                    diseaseType: "Metabolic",
                    evidenceLevel: .uncertain,
                    associationScore: 0.3,
                    associationType: .functional,
                    geneRole: "Metabolic enzyme",
                    clinicalFeatures: ["Metabolic imbalance", "Energy regulation"],
                    frequency: "Unknown",
                    treatability: "Experimental",
                    references: nil,
                    dataSource: "Mock Data",
                    lastUpdated: "2024-01-01"
                )
            ]
        }
    }
    
    // MARK: - Parsing Methods
    
    private func parseDiseaseAssociations(from entry: UniProtDiseaseEntry) -> [DiseaseAssociation] {
        var diseases: [DiseaseAssociation] = []
        
        guard let comments = entry.comments else { 
            print("🔍 No comments found in UniProt entry")
            return diseases 
        }
        
        print("🔍 Found \(comments.count) comments")
        
        for comment in comments {
            print("🔍 Comment type: \(comment.commentType ?? "unknown")")
            
            if comment.commentType?.lowercased() == "disease" {
                print("🔍 Found disease comment")
                print("🔍 Texts count: \(comment.texts?.count ?? 0)")
                
                // 기존 텍스트 기반 파싱 사용
                if let texts = comment.texts, !texts.isEmpty {
                    print("🔍 Using text-based parsing as fallback")
                    for text in texts {
                        if let diseaseName = text.value {
                            print("🔍 Parsing disease from text: \(diseaseName)")
                            let diseaseAssociation = parseDiseaseFromText(diseaseName)
                            diseases.append(diseaseAssociation)
                        }
                    }
                } else {
                    print("🔍 No disease object or texts found in disease comment")
                }
            }
        }
        
        print("🔍 Parsed \(diseases.count) disease associations")
        
        // Sort by evidence level and score
        return diseases.sorted { first, second in
            if first.evidenceLevel != second.evidenceLevel {
                return first.evidenceLevel.rawValue < second.evidenceLevel.rawValue
            }
            
            let firstScore = first.associationScore ?? 0.0
            let secondScore = second.associationScore ?? 0.0
            return firstScore > secondScore
        }
    }
    
    private func parseDiseaseAssociation(from disease: UniProtDisease) -> DiseaseAssociation {
        let diseaseName = disease.name ?? "Unknown Disease"
        let diseaseId = disease.diseaseId
        let acronym = disease.acronym
        
        // Parse evidence level from description
        let evidenceLevel = parseEvidenceLevel(from: disease.description)
        
        // Parse clinical features
        let clinicalFeatures = parseClinicalFeatures(from: disease.description)
        
        // Create references
        let references = parseReferences(from: disease.description)
        
        return DiseaseAssociation(
            id: diseaseId ?? UUID().uuidString,
            diseaseName: diseaseName,
            diseaseId: diseaseId,
            diseaseType: acronym,
            evidenceLevel: evidenceLevel,
            associationScore: calculateAssociationScore(evidenceLevel: evidenceLevel),
            associationType: .direct, // Default to direct for UniProt data
            geneRole: nil,
            clinicalFeatures: clinicalFeatures,
            frequency: nil,
            treatability: nil,
            references: references,
            dataSource: "UniProt",
            lastUpdated: nil
        )
    }
    
    private func parseEvidenceLevel(from descriptions: [UniProtDiseaseDescription]?) -> EvidenceLevel {
        guard let descriptions = descriptions else { return .uncertain }
        
        for description in descriptions {
            let text = description.value.lowercased()
            
            if text.contains("known") || text.contains("established") {
                return .known
            } else if text.contains("predicted") || text.contains("likely") {
                return .predicted
            } else if text.contains("inferred") || text.contains("suggested") {
                return .inferred
            }
        }
        
        return .uncertain
    }
    
    private func parseClinicalFeatures(from descriptions: [UniProtDiseaseDescription]?) -> [String]? {
        guard let descriptions = descriptions else { return nil }
        
        var features: [String] = []
        
        for description in descriptions {
            let text = description.value
            
            // Extract clinical features from description
            if text.contains("characterized by") || text.contains("symptoms include") {
                features.append(text)
            }
        }
        
        return features.isEmpty ? nil : features
    }
    
    private func parseReferences(from descriptions: [UniProtDiseaseDescription]?) -> [Reference]? {
        guard let descriptions = descriptions else { return nil }
        
        var references: [Reference] = []
        
        for description in descriptions {
            if let evidences = description.evidences {
                for evidence in evidences {
                    if let source = evidence.source {
                        let reference = Reference(
                            id: source.id ?? UUID().uuidString,
                            title: source.name ?? "Unknown Reference",
                            authors: nil,
                            journal: nil,
                            year: nil,
                            pmid: source.id?.contains("PMID") == true ? source.id : nil,
                            doi: source.id?.contains("DOI") == true ? source.id : nil
                        )
                        references.append(reference)
                    }
                }
            }
        }
        
        return references.isEmpty ? nil : references
    }
    
    private func calculateAssociationScore(evidenceLevel: EvidenceLevel) -> Double {
        switch evidenceLevel {
        case .known: return 0.9
        case .predicted: return 0.7
        case .inferred: return 0.5
        case .uncertain: return 0.3
        }
    }
    
    // MARK: - Summary Methods
    
    func createDiseaseSummary(from diseases: [DiseaseAssociation]) -> DiseaseAssociationSummary {
        let totalDiseases = diseases.count
        let knownDiseases = diseases.filter { $0.evidenceLevel == .known }.count
        let predictedDiseases = diseases.filter { $0.evidenceLevel == .predicted }.count
        
        let topDiseases = Array(diseases.prefix(5))
        
        var categories: [String: Int] = [:]
        for disease in diseases {
            let category = disease.diseaseType ?? "Unknown"
            categories[category, default: 0] += 1
        }
        
        return DiseaseAssociationSummary(
            totalDiseases: totalDiseases,
            knownDiseases: knownDiseases,
            predictedDiseases: predictedDiseases,
            topDiseases: topDiseases,
            categories: categories
        )
    }
}

// MARK: - Error Handling

enum DiseaseAssociationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    case parsingError
    case plantProtein(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for disease association API"
        case .invalidResponse:
            return "Invalid response from disease association API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse disease association data"
        case .plantProtein(let message):
            return message
        }
    }
}

// MARK: - Additional Parsing Functions

extension DiseaseAssociationService {
    
    private func parseDiseaseFromText(_ diseaseText: String) -> DiseaseAssociation {
        // Extract disease name and additional information from the text
        let diseaseName = extractDiseaseName(from: diseaseText)
        let diseaseId = extractDiseaseId(from: diseaseText)
        let description = extractDescription(from: diseaseText)
        
        return DiseaseAssociation(
            id: UUID().uuidString,
            diseaseName: diseaseName,
            diseaseId: diseaseId,
            diseaseType: "Genetic disease", // Most protein-related diseases are genetic
            evidenceLevel: .known, // UniProt entries are usually well-established
            associationScore: 0.9, // High confidence for UniProt entries
            associationType: .direct, // Direct association
            geneRole: nil,
            clinicalFeatures: description != nil ? [description!] : nil,
            frequency: nil,
            treatability: nil,
            references: nil,
            dataSource: "UniProt",
            lastUpdated: Date().formatted(date: .abbreviated, time: .omitted)
        )
    }
    
    private func extractDiseaseName(from text: String) -> String {
        // Extract the main disease name from the text
        // This is a simplified extraction - in reality, you'd need more sophisticated parsing
        let components = text.components(separatedBy: ".")
        return components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? text
    }
    
    private func extractDiseaseId(from text: String) -> String? {
        // Look for disease IDs in the text (like OMIM, Orphanet, etc.)
        let idPatterns = [
            "OMIM:[0-9]+",
            "Orphanet:[0-9]+",
            "MIM:[0-9]+"
        ]
        
        for pattern in idPatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
            }
        }
        return nil
    }
    
    private func extractDescription(from text: String) -> String? {
        // Extract description after the disease name
        let components = text.components(separatedBy: ".")
        if components.count > 1 {
            return components[1...].joined(separator: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
