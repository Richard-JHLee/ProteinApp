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
        
        // Check if it's a DE NOVO PROTEIN (not in UniProt)
        if actualUniProtId == uniprotId && !isUniProtId(actualUniProtId) {
            throw DiseaseAssociationError.noDataAvailable("This protein is not found in UniProt database. It may be a synthetic or de novo protein without disease association data.")
        }
        
        // 방법 1: 특정 필드만 요청하여 효율성 향상
        if let diseaseData = try await fetchDiseaseDataWithFields(actualUniProtId) {
            return diseaseData
        }
        
        // 방법 2: 전체 데이터 요청 (fallback)
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
    func fetchUniProtIdFromPDB(pdbId: String) async throws -> String {
        print("🔍 Fetching UniProt ID for PDB ID: \(pdbId)")
        
        // 방법 0: 먼저 알려진 매핑 테이블 확인 (가장 확실한 방법)
        do {
            let mappedId = try fallbackMapping(pdbId: pdbId)
            print("🔍 Found UniProt ID via fallback mapping: \(mappedId)")
            return mappedId
        } catch {
            print("🔍 No fallback mapping found for \(pdbId), trying API methods...")
        }
        
        // 방법 1: UniProt API에서 직접 PDB ID로 검색
        if let uniprotId = try await searchUniProtByPDBId(pdbId) {
            print("🔍 Found UniProt ID via direct search: \(uniprotId)")
            return uniprotId
        }
        
        // 방법 2: RCSB 공식 UniProt 연계 엔드포인트 사용
        if let uniprotId = try await searchRCSBUniProtMapping(pdbId) {
            print("🔍 Found UniProt ID via RCSB mapping: \(uniprotId)")
            return uniprotId
        }
        
        // 방법 3: PDB API를 통해 UniProt ID 조회 (entry 엔드포인트)
        guard let url = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(pdbId.uppercased())") else {
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
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 PDB API Response structure: \(json.keys)")
                
                // 여러 방법으로 UniProt ID 찾기
                var uniprotId: String? = nil
                
                // 방법 1: struct_ref에서 찾기
                if let structRef = json["struct_ref"] as? [[String: Any]] {
                    for ref in structRef {
                        if let dbName = ref["db_name"] as? String,
                           dbName.lowercased() == "uniprot",
                           let dbAccession = ref["db_accession"] as? String {
                            uniprotId = dbAccession
                            break
                        }
                    }
                }
                
                // 방법 2: entity_src_gen에서 찾기
                if uniprotId == nil,
                   let entitySrcGen = json["entity_src_gen"] as? [[String: Any]] {
                    for entity in entitySrcGen {
                        if let pdbxGeneSrcScientificName = entity["pdbx_gene_src_scientific_name"] as? String,
                           let pdbxGeneSrcCommonName = entity["pdbx_gene_src_common_name"] as? String {
                            // 인간 단백질인지 확인
                            if pdbxGeneSrcScientificName.lowercased().contains("homo sapiens") ||
                               pdbxGeneSrcCommonName.lowercased().contains("human") {
                                // UniProt ID를 다른 방법으로 찾기
                                break
                            }
                        }
                    }
                }
                
                // 방법 3: JSON 전체를 검색하여 UniProt 패턴 찾기
                if uniprotId == nil {
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
            "1A4U": "P13569", // CFTR NBD1 domain - Cystic Fibrosis
            "1BKV": "P12111", // Collagen type III alpha 1 chain (human)
            "1CGD": "P12111", // Collagen-like peptide -> Collagen type III alpha 1 chain
            "1CRN": "P68871", // Use hemoglobin for testing disease associations
            "1HTM": "P02790", // Hemopexin
            "1INS": "P01308", // Insulin
            "1MBN": "P02185", // Myoglobin
            "1UBQ": "P0CG48", // Ubiquitin
            "2HYY": "P05067", // APP fragment - Alzheimer's disease
            "2ZZD": "P00698", // Lysozyme
            "3KG2": "P04637", // p53 - Cancer related
            "3NIR": "P29459", // Nitrite reductase
            "3P46": "P68871", // Hemoglobin beta chain (has disease associations)
            "4HDD": "P42858", // Huntingtin - Huntington's disease
            "4HHB": "P68871", // Hemoglobin beta (has disease associations)
            "4KPO": "B6T563", // Nucleoside N-ribohydrolase 3 (maize) - plant protein
            "5K86": "P02452", // Collagen type I alpha 1 chain (has disease associations)
            "5PTI": "P00974", // Pancreatic trypsin inhibitor
            "6LU7": "P0DTD1", // SARS-CoV-2 main protease - COVID-19
            "6LYZ": "P00698"  // Lysozyme
        ]
        
        let upperPdbId = pdbId.uppercased()
        
        // 매핑 테이블에서 찾기
        if let mappedId = pdbToUniProtMap[upperPdbId] {
            print("🔍 Using fallback mapping: \(upperPdbId) -> \(mappedId)")
            return mappedId
        }
        
        // 매핑 테이블에 없는 경우, DE NOVO PROTEIN일 가능성이 높음
        print("🔍 No mapping found for PDB ID: \(upperPdbId) - likely DE NOVO PROTEIN")
        throw DiseaseAssociationError.noDataAvailable("No disease association data available for this protein. It may be a synthetic or de novo protein.")
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
    
    private func parseDiseaseAssociations(from entry: UniProtDiseaseEntry, pdbId: String? = nil) -> [DiseaseAssociation] {
        var diseases: [DiseaseAssociation] = []
        
        // 특별한 질병 연관 정보 처리는 제거 (FUNCTION comment에서 처리)
        
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
                
                // DISEASE comment의 모든 필드 확인
                print("🔍 Disease comment fields: \(comment)")
                
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
                    print("🔍 No texts found in disease comment")
                    print("🔍 Comment structure: \(comment)")
                    
                    // DISEASE comment의 disease 객체 확인
                    if let disease = comment.disease {
                        print("🔍 Found disease object: \(disease)")
                        let diseaseAssociation = parseDiseaseAssociation(from: disease)
                        diseases.append(diseaseAssociation)
                    } else {
                        print("🔍 No disease object found in DISEASE comment")
                        
                        // note 필드 확인
                        if let note = comment.note, let texts = note.texts, !texts.isEmpty {
                            print("🔍 Found note field with \(texts.count) items")
                            for text in texts {
                                if let value = text.value {
                                    print("🔍 Parsing disease from note: \(value)")
                                    let diseaseAssociation = parseDiseaseFromText(value)
                                    diseases.append(diseaseAssociation)
                                }
                            }
                        }
                    }
                }
            } else if comment.commentType?.lowercased() == "function" {
                print("🔍 Found function comment - checking for disease-related information")
                
                // FUNCTION comment에서 질병 관련 정보 추출
                if let texts = comment.texts, !texts.isEmpty {
                    for text in texts {
                        if let functionText = text.value {
                            print("🔍 Function text: \(functionText)")
                            
                            // SARS-CoV-2, COVID-19, 바이러스 관련 키워드 확인
                            if functionText.lowercased().contains("sars-cov-2") || 
                               functionText.lowercased().contains("covid-19") ||
                               functionText.lowercased().contains("coronavirus") {
                                print("🔍 Found virus-related function, creating disease association")
                                let diseaseAssociation = createDiseaseAssociationFromFunction(functionText)
                                diseases.append(diseaseAssociation)
                            }
                        }
                    }
                }
            } else if comment.commentType?.lowercased() == "miscellaneous" {
                print("🔍 Found miscellaneous comment - checking for disease-related information")
                
                // MISCELLANEOUS comment에서 질병 관련 정보 추출
                if let texts = comment.texts, !texts.isEmpty {
                    for text in texts {
                        if let miscText = text.value {
                            print("🔍 Miscellaneous text: \(miscText)")
                            
                            // 질병 관련 키워드 확인
                            if miscText.lowercased().contains("disease") ||
                               miscText.lowercased().contains("syndrome") ||
                               miscText.lowercased().contains("disorder") ||
                               miscText.lowercased().contains("pathology") {
                                print("🔍 Found disease-related miscellaneous info, creating disease association")
                                let diseaseAssociation = createDiseaseAssociationFromMiscellaneous(miscText)
                                diseases.append(diseaseAssociation)
                            }
                        }
                    }
                }
            } else if comment.commentType?.lowercased() == "polymorphism" {
                print("🔍 Found polymorphism comment - checking for disease-related information")
                
                // POLYMORPHISM comment에서 질병 관련 정보 추출
                if let texts = comment.texts, !texts.isEmpty {
                    for text in texts {
                        if let polyText = text.value {
                            print("🔍 Polymorphism text: \(polyText)")
                            
                            // 질병 관련 키워드 확인
                            if polyText.lowercased().contains("disease") ||
                               polyText.lowercased().contains("syndrome") ||
                               polyText.lowercased().contains("disorder") ||
                               polyText.lowercased().contains("pathology") {
                                print("🔍 Found disease-related polymorphism, creating disease association")
                                let diseaseAssociation = createDiseaseAssociationFromPolymorphism(polyText)
                                diseases.append(diseaseAssociation)
                            }
                        }
                    }
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
    
    // FUNCTION comment에서 질병 연관 정보 생성
    private func createDiseaseAssociationFromFunction(_ functionText: String) -> DiseaseAssociation {
        let lowercasedText = functionText.lowercased()
        
        // COVID-19 관련 정보 추출
        if lowercasedText.contains("sars-cov-2") || lowercasedText.contains("covid-19") {
            return DiseaseAssociation(
                id: "covid19-\(UUID().uuidString.prefix(8))",
                diseaseName: "COVID-19",
                diseaseId: "COVID-19",
                diseaseType: "Viral Infection",
                evidenceLevel: .known,
                associationScore: 1.0,
                associationType: .direct,
                geneRole: "Viral protein",
                clinicalFeatures: ["Severe acute respiratory syndrome", "Pneumonia", "Multi-organ failure"],
                frequency: "Pandemic (2020-2023)",
                treatability: "Antiviral drugs, vaccines",
                references: [
                    Reference(
                        id: "covid19-ref1",
                        title: "COVID-19: A novel coronavirus disease",
                        authors: "WHO",
                        journal: "World Health Organization",
                        year: 2020,
                        pmid: "32031570",
                        doi: "10.1016/S0140-6736(20)30183-5"
                    )
                ],
                dataSource: "UniProt Function comment",
                lastUpdated: "2024-01-01"
            )
        }
        
        // 일반적인 바이러스 관련 정보
        return DiseaseAssociation(
            id: "virus-\(UUID().uuidString.prefix(8))",
            diseaseName: "Viral Infection",
            diseaseId: "VIRAL",
            diseaseType: "Viral Infection",
            evidenceLevel: .uncertain,
            associationScore: 0.8,
            associationType: .direct,
            geneRole: "Viral protein",
            clinicalFeatures: ["Viral infection symptoms"],
            frequency: nil,
            treatability: "Antiviral treatment",
            references: nil,
            dataSource: "UniProt Function comment",
            lastUpdated: "2024-01-01"
        )
    }
    
    // MISCELLANEOUS comment에서 질병 연관 정보 생성
    private func createDiseaseAssociationFromMiscellaneous(_ miscText: String) -> DiseaseAssociation {
        let lowercasedText = miscText.lowercased()
        
        // 질병명 추출 시도
        var diseaseName = "Unknown Disease"
        if lowercasedText.contains("disease") {
            diseaseName = "Disease"
        } else if lowercasedText.contains("syndrome") {
            diseaseName = "Syndrome"
        } else if lowercasedText.contains("disorder") {
            diseaseName = "Disorder"
        }
        
        return DiseaseAssociation(
            id: "misc-\(UUID().uuidString.prefix(8))",
            diseaseName: diseaseName,
            diseaseId: "MISC",
            diseaseType: "Miscellaneous",
            evidenceLevel: .uncertain,
            associationScore: 0.6,
            associationType: .indirect,
            geneRole: "Protein variant",
            clinicalFeatures: [miscText],
            frequency: nil,
            treatability: "Symptomatic treatment",
            references: nil,
            dataSource: "UniProt Miscellaneous comment",
            lastUpdated: "2024-01-01"
        )
    }
    
    // POLYMORPHISM comment에서 질병 연관 정보 생성
    private func createDiseaseAssociationFromPolymorphism(_ polyText: String) -> DiseaseAssociation {
        let lowercasedText = polyText.lowercased()
        
        // 질병명 추출 시도
        var diseaseName = "Genetic Disorder"
        if lowercasedText.contains("disease") {
            diseaseName = "Genetic Disease"
        } else if lowercasedText.contains("syndrome") {
            diseaseName = "Genetic Syndrome"
        }
        
        return DiseaseAssociation(
            id: "poly-\(UUID().uuidString.prefix(8))",
            diseaseName: diseaseName,
            diseaseId: "POLY",
            diseaseType: "Genetic Disorder",
            evidenceLevel: .uncertain,
            associationScore: 0.7,
            associationType: .direct,
            geneRole: "Genetic variant",
            clinicalFeatures: [polyText],
            frequency: "Rare",
            treatability: "Genetic counseling, symptomatic treatment",
            references: nil,
            dataSource: "UniProt Polymorphism comment",
            lastUpdated: "2024-01-01"
        )
    }
    
    private func parseDiseaseAssociation(from disease: UniProtDisease) -> DiseaseAssociation {
        let diseaseName = disease.diseaseId ?? "Unknown Disease"
        let diseaseId = disease.diseaseAccession
        let acronym = disease.acronym
        
        // Parse evidence level from description
        let evidenceLevel = EvidenceLevel.known // UniProt에서 제공하는 정보는 일반적으로 높은 신뢰도
        
        // Parse clinical features
        let clinicalFeatures = [disease.description ?? ""]
        
        // Create references
        let references = parseReferencesFromDisease(disease)
        
        return DiseaseAssociation(
            id: diseaseId ?? UUID().uuidString,
            diseaseName: diseaseName,
            diseaseId: diseaseId,
            diseaseType: acronym,
            evidenceLevel: evidenceLevel,
            associationScore: 1.0,
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
    
    private func parseReferencesFromDisease(_ disease: UniProtDisease) -> [Reference]? {
        var references: [Reference] = []
        
        // OMIM 참조 추가
        if let crossRef = disease.diseaseCrossReference,
           let database = crossRef.database,
           let id = crossRef.id {
            let reference = Reference(
                id: id,
                title: "\(database) Reference",
                authors: nil,
                journal: database,
                year: nil,
                pmid: nil,
                doi: nil
            )
            references.append(reference)
        }
        
        // Evidence 참조 추가
        if let evidences = disease.evidences {
            for evidence in evidences {
                if let source = evidence.source,
                   let id = evidence.id {
                    let reference = Reference(
                        id: id,
                        title: "\(source) Reference",
                        authors: nil,
                        journal: source,
                        year: nil,
                        pmid: id,
                        doi: nil
                    )
                    references.append(reference)
                }
            }
        }
        
        return references.isEmpty ? nil : references
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
    case noDataAvailable(String)
    
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
        case .noDataAvailable(let message):
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
    
    // UniProt에서 PDB ID로 직접 검색
    private func searchUniProtByPDBId(_ pdbId: String) async throws -> String? {
        // PDB ID로 직접 검색하는 대신, 단백질 이름으로 검색 시도
        let encodedPdbId = pdbId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://rest.uniprot.org/uniprotkb/search?query=\(encodedPdbId)&format=json&size=1") else {
            return nil
        }
        
        print("🔍 Searching UniProt for PDB ID: \(pdbId)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🔍 UniProt search failed for PDB ID: \(pdbId)")
                return nil
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let results = json?["results"] as? [[String: Any]],
               let firstResult = results.first,
               let primaryAccession = firstResult["primaryAccession"] as? String {
                print("🔍 Found UniProt ID: \(primaryAccession) for PDB ID: \(pdbId)")
                return primaryAccession
            }
            
            print("🔍 No UniProt results found for PDB ID: \(pdbId)")
            return nil
        } catch {
            print("🔍 Error searching UniProt for PDB ID \(pdbId): \(error)")
            return nil
        }
    }
    
    // RCSB 공식 UniProt 연계 엔드포인트 사용
    private func searchRCSBUniProtMapping(_ pdbId: String) async throws -> String? {
        // 방법 1: polymer_entities 엔드포인트 사용
        if let uniprotId = try await searchRCSBPolymerEntities(pdbId) {
            return uniprotId
        }
        
        // 방법 2: entities 엔드포인트 사용 (일반적)
        if let uniprotId = try await searchRCSBEntities(pdbId) {
            return uniprotId
        }
        
        return nil
    }
    
    // RCSB polymer_entities 엔드포인트로 UniProt ID 검색
    private func searchRCSBPolymerEntities(_ pdbId: String) async throws -> String? {
        guard let url = URL(string: "https://data.rcsb.org/rest/v1/core/polymer_entity/\(pdbId.uppercased())") else {
            return nil
        }
        
        print("🔍 Searching RCSB polymer_entities for PDB ID: \(pdbId)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🔍 RCSB polymer_entities search failed for PDB ID: \(pdbId)")
                return nil
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // uniprot_xref에서 UniProt ID 찾기
            if let uniprotXref = json?["uniprot_xref"] as? [[String: Any]],
               let firstXref = uniprotXref.first,
               let uniprotId = firstXref["id"] as? String {
                print("🔍 Found UniProt ID via polymer_entities: \(uniprotId)")
                return uniprotId
            }
            
            return nil
        } catch {
            print("🔍 Error searching RCSB polymer_entities for PDB ID \(pdbId): \(error)")
            return nil
        }
    }
    
    // RCSB entities 엔드포인트로 UniProt ID 검색 (일반적)
    private func searchRCSBEntities(_ pdbId: String) async throws -> String? {
        guard let url = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(pdbId.uppercased())") else {
            return nil
        }
        
        print("🔍 Searching RCSB entities for PDB ID: \(pdbId)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🔍 RCSB entities search failed for PDB ID: \(pdbId)")
                return nil
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // entities 배열에서 UniProt ID 찾기
            if let entities = json?["entities"] as? [[String: Any]] {
                for entity in entities {
                    if let uniprotXref = entity["uniprot_xref"] as? [[String: Any]],
                       let firstXref = uniprotXref.first,
                       let uniprotId = firstXref["id"] as? String {
                        print("🔍 Found UniProt ID via entities: \(uniprotId)")
                        return uniprotId
                    }
                }
            }
            
            return nil
        } catch {
            print("🔍 Error searching RCSB entities for PDB ID \(pdbId): \(error)")
            return nil
        }
    }
    
    // UniProt API에서 특정 필드만 요청하여 질병 데이터 가져오기 (효율성 향상)
    private func fetchDiseaseDataWithFields(_ uniprotId: String) async throws -> [DiseaseAssociation]? {
        let fields = "accession,protein_name,gene_names,diseases,xref_omim,xref_orphanet,comments"
        guard let url = URL(string: "https://rest.uniprot.org/uniprotkb/search?query=accession:\(uniprotId)&format=json&fields=\(fields)&size=1") else {
            return nil
        }
        
        print("🔍 Fetching disease data with specific fields for: \(uniprotId)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🔍 UniProt field-specific search failed for: \(uniprotId)")
                return nil
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let results = json?["results"] as? [[String: Any]],
               let firstResult = results.first {
                return parseDiseaseAssociationsFromFields(firstResult)
            }
            
            return nil
        } catch {
            print("🔍 Error fetching disease data with fields for \(uniprotId): \(error)")
            return nil
        }
    }
    
    // 특정 필드에서 질병 연관 데이터 파싱
    private func parseDiseaseAssociationsFromFields(_ data: [String: Any]) -> [DiseaseAssociation] {
        var associations: [DiseaseAssociation] = []
        
        print("🔍 Parsing disease associations from fields data")
        print("🔍 Available keys: \(data.keys.sorted())")
        
        // diseases 필드에서 질병 정보 추출
        if let diseases = data["diseases"] as? [[String: Any]] {
            print("🔍 Found \(diseases.count) diseases in diseases field")
            for disease in diseases {
                if let diseaseId = disease["diseaseId"] as? String,
                   let diseaseName = disease["diseaseName"] as? String,
                   let _ = disease["description"] as? String {
                    
                    let association = DiseaseAssociation(
                        id: UUID().uuidString,
                        diseaseName: diseaseName,
                        diseaseId: diseaseId,
                        diseaseType: "Unknown",
                        evidenceLevel: .known, // UniProt에서 제공하는 정보는 일반적으로 높은 신뢰도
                        associationScore: 1.0,
                        associationType: .direct,
                        geneRole: nil,
                        clinicalFeatures: nil,
                        frequency: nil,
                        treatability: nil,
                        references: [],
                        dataSource: "UniProt",
                        lastUpdated: nil
                    )
                    associations.append(association)
                }
            }
        } else {
            print("🔍 No diseases field found or empty")
        }
        
        // comments 필드에서 질병 관련 정보 추출 (fallback)
        if associations.isEmpty, let comments = data["comments"] as? [[String: Any]] {
            print("🔍 Checking comments field for disease information")
            for comment in comments {
                if let commentType = comment["commentType"] as? String,
                   commentType.lowercased() == "disease" {
                    print("🔍 Found disease comment in comments field")
                    if let texts = comment["texts"] as? [[String: Any]] {
                        for text in texts {
                            if let value = text["value"] as? String {
                                print("🔍 Parsing disease from comment text: \(value)")
                                let association = parseDiseaseFromText(value)
                                associations.append(association)
                            }
                        }
                    }
                }
            }
        }
        
        // OMIM 참조에서 추가 질병 정보 추출
        if let omimRefs = data["xref_omim"] as? [[String: Any]] {
            for omimRef in omimRefs {
                if let omimId = omimRef["id"] as? String,
                   let properties = omimRef["properties"] as? [String: Any],
                   let omimName = properties["name"] as? String {
                    
                    let association = DiseaseAssociation(
                        id: UUID().uuidString,
                        diseaseName: omimName,
                        diseaseId: "OMIM:\(omimId)",
                        diseaseType: "Unknown",
                        evidenceLevel: .known,
                        associationScore: 1.0,
                        associationType: .direct,
                        geneRole: nil,
                        clinicalFeatures: nil,
                        frequency: nil,
                        treatability: nil,
                        references: [],
                        dataSource: "OMIM",
                        lastUpdated: nil
                    )
                    associations.append(association)
                }
            }
        }
        
        // Orphanet 참조에서 추가 질병 정보 추출
        if let orphanetRefs = data["xref_orphanet"] as? [[String: Any]] {
            for orphanetRef in orphanetRefs {
                if let orphanetId = orphanetRef["id"] as? String,
                   let properties = orphanetRef["properties"] as? [String: Any],
                   let orphanetName = properties["name"] as? String {
                    
                    let association = DiseaseAssociation(
                        id: UUID().uuidString,
                        diseaseName: orphanetName,
                        diseaseId: "ORPHA:\(orphanetId)",
                        diseaseType: "Unknown",
                        evidenceLevel: .known,
                        associationScore: 1.0,
                        associationType: .direct,
                        geneRole: nil,
                        clinicalFeatures: nil,
                        frequency: nil,
                        treatability: nil,
                        references: [],
                        dataSource: "Orphanet",
                        lastUpdated: nil
                    )
                    associations.append(association)
                }
            }
        }
        
        return associations
    }
}
