import SwiftUI
import Foundation
import SafariServices

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - API Models

struct PDBSearchResponse: Codable {
    let result_set: [PDBEntry]?
    let total_count: Int?
    
    // missing 필드 처리를 위한 기본값
    var safeResultSet: [PDBEntry] {
        return result_set ?? []
    }
    
    var safeTotalCount: Int {
        return total_count ?? 0
    }
}

struct PDBEntry: Codable {
    let identifier: String?
    let title: String?
    let resolution: Double?
    let experimental_method: [String]?
    let organism_scientific_name: [String]?
    let classification: String?
    
    // identifier가 없는 경우를 대비한 안전한 접근자
    var safeIdentifier: String {
        return identifier ?? "UNKNOWN"
    }
    
    enum CodingKeys: String, CodingKey {
        case identifier
        case title
        case resolution
        case experimental_method
        case organism_scientific_name
        case classification
    }
}

// Data API 응답 모델
struct PDBDetailResponse: Codable {
    let pdb_struct: PDBStruct?
    let rcsb_entry_info: PDBEntryInfo?
    let rcsb_primary_citation: PDBCitation?
    let struct_keywords: PDBKeywords?
    let exptl: [PDBExperimental]?
    
    enum CodingKeys: String, CodingKey {
        case pdb_struct = "struct"
        case rcsb_entry_info
        case rcsb_primary_citation
        case struct_keywords
        case exptl
    }
}

struct PDBStruct: Codable {
    let title: String?
    let pdbx_descriptor: String?
}

struct PDBEntryInfo: Codable {
    let experimental_method: [String]?
    let resolution_combined: [Double]?
}

struct PDBCitation: Codable {
    let title: String?
    let journal_abbrev: String?
}

struct PDBKeywords: Codable {
    let pdbx_keywords: String?
}

struct PDBExperimental: Codable {
    let method: String?
}

// MARK: - GraphQL Models
struct GraphQLBody: Codable {
    let query: String
    let variables: [String: [String]]
}

struct GraphQLResponse: Codable {
    let data: GraphQLData
}

struct GraphQLData: Codable {
    let entries: [GraphQLEntry]
}

struct GraphQLEntry: Codable {
    let rcsb_id: String?
    let pdb_struct: GraphQLStruct?
    let exptl: [GraphQLExperimental]?
    let rcsb_entry_info: GraphQLEntryInfo?
    let rcsb_primary_citation: GraphQLCitation?
    let struct_keywords: GraphQLKeywords?
    
    enum CodingKeys: String, CodingKey {
        case rcsb_id
        case pdb_struct = "struct"
        case exptl
        case rcsb_entry_info
        case rcsb_primary_citation
        case struct_keywords
    }
}

struct GraphQLStruct: Codable {
    let title: String?
    let pdbx_descriptor: String?
}

struct GraphQLExperimental: Codable {
    let method: String?
}

struct GraphQLEntryInfo: Codable {
    let resolution_combined: [Double]?
    private let _experimental_method: ExperimentalMethodValue?
    
    // Computed property to handle both string and array cases
    var experimental_method: [String]? {
        switch _experimental_method {
        case .single(let method):
            return [method]
        case .multiple(let methods):
            return methods
        case .none:
            return nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case resolution_combined
        case _experimental_method = "experimental_method"
    }
    
    // Enum to handle both string and array cases
    private enum ExperimentalMethodValue: Codable {
        case single(String)
        case multiple([String])
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let stringValue = try? container.decode(String.self) {
                self = .single(stringValue)
            } else if let arrayValue = try? container.decode([String].self) {
                self = .multiple(arrayValue)
            } else {
                throw DecodingError.typeMismatch(
                    ExperimentalMethodValue.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected string or array of strings"
                    )
                )
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .single(let method):
                try container.encode(method)
            case .multiple(let methods):
                try container.encode(methods)
            }
        }
    }
}

struct GraphQLCitation: Codable {
    let title: String?
    let journal_abbrev: String?
}

struct GraphQLKeywords: Codable {
    let pdbx_keywords: String?
}

// MARK: - Protein Data Models

struct ProteinInfo: Identifiable, Hashable {
    let id: String // PDB ID
    let name: String
    let category: ProteinCategory
    let description: String
    let keywords: [String] // For search
    let isFavorite: Bool = false
    
    var displayName: String {
        "\(name) (\(id.uppercased()))"
    }
    
    // PDB 구조 기반 동적 이미지 생성
    var dynamicIcon: String {
        // PDB ID의 문자들을 분석하여 고유한 아이콘 생성
        let chars = Array(id.uppercased())
        let firstChar = chars.first ?? "A"
        let lastChar = chars.last ?? "A"
        let middleChar = chars.count > 2 ? chars[1] : "A"
        
        // 첫 번째 문자 기반 기본 카테고리
        let baseIcon: String
        switch firstChar {
        case "1", "2", "3": baseIcon = "building.2"      // 구조적 단백질
        case "4", "5", "6": baseIcon = "scissors"        // 효소
        case "7", "8", "9": baseIcon = "shield"          // 방어 단백질
        case "A", "B", "C": baseIcon = "car"             // 운반 단백질
        case "D", "E", "F": baseIcon = "antenna.radiowaves.left.and.right" // 호르몬
        case "G", "H", "I": baseIcon = "archivebox"      // 저장 단백질
        case "J", "K", "L": baseIcon = "wifi"            // 수용체
        case "M", "N", "O": baseIcon = "bubble.left.and.bubble.right" // 막단백질
        case "P", "Q", "R": baseIcon = "gear"            // 모터 단백질
        case "S", "T", "U": baseIcon = "network"         // 신호 전달
        case "V", "W", "X": baseIcon = "wrench.and.screwdriver" // 챠퍼론
        case "Y", "Z": baseIcon = "arrow.triangle.2.circlepath" // 대사
        default: baseIcon = category.icon
        }
        
        // 마지막 문자로 세부 분류
        let detailIcon: String
        switch lastChar {
        case "A", "1": detailIcon = "circle.fill"        // 단일체
        case "B", "2": detailIcon = "circle.lefthalf.filled" // 이량체
        case "C", "3": detailIcon = "triangle.fill"      // 삼량체
        case "D", "4": detailIcon = "square.fill"        // 사량체
        case "E", "5": detailIcon = "pentagon.fill"      // 오량체
        case "F", "6": detailIcon = "hexagon.fill"       // 육량체
        case "G", "7": detailIcon = "septagon.fill"      // 칠량체
        case "H", "8": detailIcon = "octagon.fill"       // 팔량체
        case "I", "9": detailIcon = "nonagon.fill"       // 구량체
        case "J", "0": detailIcon = "decagon.fill"       // 십량체
        default: detailIcon = "circle"
        }
        
        // 중간 문자로 특별한 특징 추가
        let specialIcon: String
        switch middleChar {
        case "A", "1": specialIcon = "atom"              // 원자 수준
        case "B", "2": specialIcon = "link.badge.plus"    // DNA 결합
        case "C", "3": specialIcon = "leaf"              // 식물성
        case "D", "4": specialIcon = "brain.head.profile" // 신경계
        case "E", "5": specialIcon = "heart.fill"        // 심혈관계
        case "F", "6": specialIcon = "lungs.fill"        // 호흡계
        case "G", "7": specialIcon = "eye.fill"          // 시각계
        case "H", "8": specialIcon = "ear.fill"          // 청각계
        case "I", "9": specialIcon = "hand.raised.fill"  // 수동적
        case "J", "0": specialIcon = "bolt.fill"         // 활성적
        default: specialIcon = "atom"
        }
        
        // PDB ID 길이에 따라 아이콘 선택
        if id.count >= 4 {
            return specialIcon // 특별한 특징
        } else if id.count >= 3 {
            return detailIcon  // 세부 분류
        } else {
            return baseIcon    // 기본 카테고리
        }
    }
    
    // PDB ID 기반 색상 생성
    var dynamicColor: Color {
        let hash = abs(id.hashValue)
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .cyan, .mint, .indigo, .teal]
        return colors[hash % colors.count]
    }
}

enum ProteinCategory: String, CaseIterable, Identifiable {
    case enzymes = "Enzymes"
    case structural = "Structural"
    case defense = "Defense"
    case transport = "Transport"
    case hormones = "Hormones"
    case storage = "Storage"
    case receptors = "Receptors"
    case membrane = "Membrane"
    case motor = "Motor"
    case signaling = "Signaling"
    case chaperones = "Chaperones"
    case metabolic = "Metabolic"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .enzymes: return "scissors"
        case .structural: return "building.2"
        case .defense: return "shield"
        case .transport: return "car"
        case .hormones: return "antenna.radiowaves.left.and.right"
        case .storage: return "archivebox"
        case .receptors: return "wifi"
        case .membrane: return "bubble.left.and.bubble.right"
        case .motor: return "gear"
        case .signaling: return "network"
        case .chaperones: return "wrench.and.screwdriver"
        case .metabolic: return "arrow.triangle.2.circlepath"
        }
    }
    
    var color: Color {
        switch self {
        case .enzymes: return .blue
        case .structural: return .orange
        case .defense: return .red
        case .transport: return .green
        case .hormones: return .purple
        case .storage: return .brown
        case .receptors: return .cyan
        case .membrane: return .mint
        case .motor: return .indigo
        case .signaling: return .pink
        case .chaperones: return .yellow
        case .metabolic: return .teal
        }
    }
    
    var description: String {
        switch self {
        case .enzymes: return "생화학 반응을 촉진하는 단백질"
        case .structural: return "세포와 조직의 구조를 이루는 단백질"
        case .defense: return "외부 침입으로부터 몸을 보호하는 단백질"
        case .transport: return "물질을 운반하는 단백질"
        case .hormones: return "신호 전달을 담당하는 단백질"
        case .storage: return "영양소를 저장하는 단백질"
        case .receptors: return "신호를 받아들이는 수용체 단백질"
        case .membrane: return "세포막을 구성하고 조절하는 단백질"
        case .motor: return "세포 내에서 움직임을 만드는 단백질"
        case .signaling: return "세포 간 정보 전달을 매개하는 단백질"
        case .chaperones: return "다른 단백질의 접힘을 도와주는 단백질"
        case .metabolic: return "대사 과정에 관여하는 단백질"
        }
    }
}

// MARK: - PDB API Service

class PDBAPIService {
    static let shared = PDBAPIService()
    private init() {}
    
    // API Endpoints
    private let searchBaseURL = "https://search.rcsb.org/rcsbsearch/v2/query"
    private let dataBaseURL = "https://data.rcsb.org/rest/v1/core"
    private let graphQLURL = "https://data.rcsb.org/graphql"
    
    // MARK: - Stage 1: Search & Filter (카테고리별 PDB ID 수집)
    func searchProteinsByCategory(category: ProteinCategory, limit: Int = 200, skip: Int = 0, customTerms: [String] = []) async throws -> ([String], Int) {
        print("🔍 [\(category.rawValue)] 카테고리 검색 시작 (limit: \(limit), skip: \(skip), custom terms: \(customTerms.count))")
        
        // 사용자 정의 검색어가 있으면 커스텀 쿼리 사용
        if !customTerms.isEmpty {
            print("🔍 [\(category.rawValue)] 사용자 정의 검색어로 검색 시도...")
            let customQuery = addCustomSearchTerms(to: category, terms: customTerms)
            let (customIdentifiers, customTotalCount) = try await executeSearchQuery(query: customQuery, description: "사용자 정의 검색")
            if !customIdentifiers.isEmpty {
                print("✅ [\(category.rawValue)] 사용자 정의 검색 성공: \(customIdentifiers.count)개, 전체: \(customTotalCount)개")
                return (customIdentifiers, customTotalCount)
            }
        }
        
        // 먼저 고급 검색 시도
        let (identifiers, totalCount) = try await performAdvancedSearch(category: category, limit: limit, skip: skip)
        print("🔍 [\(category.rawValue)] 고급 검색 결과: \(identifiers.count)개, 전체: \(totalCount)개")
        print("📋 [\(category.rawValue)] 고급 검색 PDB ID 목록: \(Array(identifiers.prefix(10)))")
        
        var finalIdentifiers = identifiers
        var finalTotalCount = totalCount
        
        // Structural 카테고리 특별 처리
        if category == .structural && identifiers.count < 100 {
            print("⚠️ [\(category.rawValue)] Structural 고급 검색 결과 부족, 직접 쿼리 시도...")
            let directQuery: [String: Any] = [
                "query": [
                    "type": "group",
                    "logical_operator": "or",
                    "nodes": [
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct.title","operator":"contains_words","value":"collagen"]],
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct.title","operator":"contains_words","value":"keratin"]],
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct.title","operator":"contains_words","value":"elastin"]],
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct.title","operator":"contains_words","value":"fibroin"]],
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct.title","operator":"contains_words","value":"laminin"]],
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct.title","operator":"contains_words","value":"intermediate filament"]],
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct.title","operator":"contains_words","value":"cytoskeleton"]],
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct.title","operator":"contains_words","value":"microtubule"]],
                        ["type":"terminal","service":"text","parameters":[
                            "attribute":"struct_keywords.pdbx_keywords","operator":"contains_words","value":"structural protein"]]
                    ]
                ] as [String: Any],
                "return_type": "entry",
                "request_options": [
                    "paginate": [
                        "start": skip, // skip 매개변수 적용
                        "rows": limit
                    ]
                ]
            ]
            
            do {
                let (directIdentifiers, directTotalCount) = try await executeSearchQuery(query: directQuery, description: "Structural 직접 쿼리")
                print("🔍 [\(category.rawValue)] 직접 쿼리 결과: \(directIdentifiers.count)개, 전체: \(directTotalCount)개")
                print("📋 [\(category.rawValue)] 직접 쿼리 PDB ID 목록: \(Array(directIdentifiers.prefix(10)))")
                if !directIdentifiers.isEmpty {
                    finalIdentifiers = directIdentifiers
                    finalTotalCount = directTotalCount
                    print("✅ [\(category.rawValue)] 직접 쿼리를 최종 결과로 사용")
                }
            } catch {
                print("❌ [\(category.rawValue)] 직접 쿼리 실패: \(error.localizedDescription)")
            }
        }
        
        // 고급 검색이 실패하면 기본 검색 시도
        if finalIdentifiers.isEmpty {
            print("🔄 [\(category.rawValue)] 고급 검색 실패, 기본 검색 시도...")
            let (basicIdentifiers, basicTotalCount) = try await performBasicSearch(category: category, limit: limit, skip: skip)
            print("🔍 [\(category.rawValue)] 기본 검색 결과: \(basicIdentifiers.count)개, 전체: \(basicTotalCount)개")
            finalIdentifiers = basicIdentifiers
            finalTotalCount = basicTotalCount
        }
        
        // 기본 검색도 실패하면 fallback 검색 시도
        if finalIdentifiers.isEmpty {
            print("🔄 [\(category.rawValue)] 기본 검색 실패, fallback 검색 시도...")
            // fallback 검색을 항상 시도 (skip 값과 관계없이)
            let (fallbackIdentifiers, fallbackTotalCount) = try await searchWithFallback(category: category, limit: limit, skip: skip)
            print("🔍 [\(category.rawValue)] fallback 검색 결과: \(fallbackIdentifiers.count)개, 전체: \(fallbackTotalCount)개")
            finalIdentifiers = fallbackIdentifiers
            finalTotalCount = fallbackTotalCount
        }
        
        // 모든 검색이 실패한 경우 최후의 수단으로 간단한 검색 시도
        if finalIdentifiers.isEmpty {
            print("🔄 [\(category.rawValue)] 모든 검색 실패, 최후 수단 시도...")
            let simpleQuery: [String: Any] = [
                "query": [
                    "type": "terminal",
                    "service": "text",
                    "parameters": [
                        "attribute": "struct.title",
                        "operator": "contains_words",
                        "value": category.rawValue.lowercased()
                    ]
                ],
                "return_type": "entry",
                "request_options": [
                    "paginate": [
                        "start": skip, // skip 매개변수 적용
                        "rows": limit
                    ]
                ]
            ]
            
            do {
                let (simpleIdentifiers, simpleTotalCount) = try await executeSearchQuery(query: simpleQuery, description: "최후 수단 검색")
                print("🔍 [\(category.rawValue)] 최후 수단 검색 결과: \(simpleIdentifiers.count)개, 전체: \(simpleTotalCount)개")
                finalIdentifiers = simpleIdentifiers
                finalTotalCount = simpleTotalCount
            } catch {
                print("❌ [\(category.rawValue)] 최후 수단 검색도 실패: \(error.localizedDescription)")
            }
        }
        
        print("🎯 [\(category.rawValue)] 최종 결과: \(finalIdentifiers.count)개 PDB ID 수집, 전체: \(finalTotalCount)개")
        if !finalIdentifiers.isEmpty {
            print("📋 [\(category.rawValue)] 첫 5개 ID: \(Array(finalIdentifiers.prefix(5)))")
        } else {
            print("⚠️ [\(category.rawValue)] 검색 결과 없음 - sample 데이터 사용 예정")
        }
        
        return (finalIdentifiers, finalTotalCount)
    }
    
    // 고급 검색 (카테고리별 전문 쿼리)
    private func performAdvancedSearch(category: ProteinCategory, limit: Int, skip: Int = 0) async throws -> ([String], Int) {
        let query = buildAdvancedSearchQuery(category: category, limit: limit, skip: skip)
        return try await executeSearchQuery(query: query, description: "고급 검색")
    }
    
    // 기본 검색 (카테고리 이름 기반)
    private func performBasicSearch(category: ProteinCategory, limit: Int, skip: Int = 0) async throws -> ([String], Int) {
        // Structural 카테고리 전용 특별 처리
        if category == .structural {
            return try await performStructuralBasicSearch(limit: limit, skip: skip)
        }
        
        let query: [String: Any] = [
            "query": [
                "type": "terminal",
                "service": "text",
                "parameters": [
                    "attribute": "struct.title",
                    "operator": "contains_words",  // contains_phrase에서 contains_words로 변경
                    "value": category.rawValue.lowercased()
                ]
            ],
            "return_type": "entry",
            "request_options": [
                "paginate": [
                    "start": skip, // skip 매개변수 적용
                    "rows": limit
                ]
            ]
        ]
        return try await executeSearchQuery(query: query, description: "기본 검색")
    }
    
    // Structural 카테고리 전용 기본 검색 (사용자 제안 기반 최적화)
    private func performStructuralBasicSearch(limit: Int, skip: Int = 0) async throws -> ([String], Int) {
        let query: [String: Any] = [
            "query": [
                "type": "group",
                "logical_operator": "or",
                "nodes": [
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "contains_words",
                            "value": "structural"
                        ]
                    ],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "contains_words",
                            "value": "collagen"
                        ]
                    ],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "contains_words",
                            "value": "keratin"
                        ]
                    ],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "contains_words",
                            "value": "elastin"
                        ]
                    ],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "contains_words",
                            "value": "cytoskeleton"
                        ]
                    ]
                ]
            ],
            "return_type": "entry",
            "request_options": [
                "paginate": [
                    "start": skip, // skip 매개변수 적용
                    "rows": limit
                ]
            ]
        ]
        return try await executeSearchQuery(query: query, description: "Structural 기본 검색")
    }
    
    // 검색 쿼리 실행
    private func executeSearchQuery(query: [String: Any], description: String) async throws -> ([String], Int) {
        print("🌐 API 호출 시작: \(description)")
        print("🔗 URL: \(searchBaseURL)")
        
        guard let url = URL(string: searchBaseURL) else {
            print("❌ 잘못된 URL: \(searchBaseURL)")
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: query)
        
        print("📤 요청 데이터: \(String(data: request.httpBody!, encoding: .utf8) ?? "N/A")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 HTTP 응답: \(httpResponse.statusCode)")
        }
        
        print("📥 받은 데이터 크기: \(data.count) bytes")
        
        do {
            let response = try JSONDecoder().decode(PDBSearchResponse.self, from: data)
            let identifiers: [String] = response.safeResultSet.compactMap { entry in
                guard !entry.safeIdentifier.isEmpty && entry.safeIdentifier != "UNKNOWN" else { return nil }
                return entry.safeIdentifier
            }
            let totalCount = response.safeTotalCount
            print("✅ \(description) 성공: \(identifiers.count)개 PDB ID, 전체: \(totalCount)개")
            
            // Structural 카테고리 특별 로깅
            if description.contains("Structural") || description.contains("고급 검색") {
                print("🔍 Structural 검색 결과 상세:")
                print("   - 전체 응답: \(response.safeResultSet.count)개")
                print("   - 유효한 ID: \(identifiers.count)개")
                print("   - API 총 개수: \(totalCount)개")
                if !identifiers.isEmpty {
                    print("   - 첫 5개 ID: \(Array(identifiers.prefix(5)))")
                }
            }
            
            return (identifiers, totalCount)
        } catch {
            print("❌ \(description) 디코딩 에러: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 받은 JSON: \(String(jsonString.prefix(500)))...")
            }
            print("❌ 디코딩 실패로 빈 배열 반환")
            return ([], 0)
        }
    }
    
    // MARK: - Stage 2: Data Enrichment (상세 정보 수집)
    func enrichProteinData(pdbIds: [String]) async throws -> [ProteinInfo] {
        var proteins: [ProteinInfo] = []
        
        // 배치 처리 (한 번에 최대 20개씩)
        let batchSize = 20
        for batch in pdbIds.chunked(into: batchSize) {
            let batchProteins = try await fetchProteinDetails(batch: batch, intendedCategory: nil)
            proteins.append(contentsOf: batchProteins)
            
            // API 부하 방지
            _ = try await Task.sleep(nanoseconds: 200_000_000) // 0.2초
        }
        
        return proteins
    }
    
    // Legacy 호환성을 위한 래퍼 함수 (페이지네이션 지원 추가)
    func searchProteins(category: ProteinCategory? = nil, limit: Int = 100, skip: Int = 0) async throws -> [ProteinInfo] {
        if let category = category {
            // 새로운 2단계 파이프라인 사용 (페이지네이션 지원)
            // skip 매개변수를 API 호출에 올바르게 적용
            let (pdbIds, _) = try await searchProteinsByCategory(
                category: category,
                limit: limit,
                skip: skip // skip을 API 검색에 직접 전달
            )
            
            print("📄 페이지네이션 적용: skip=\(skip), limit=\(limit), 받은 결과=\(pdbIds.count)개")
            
            // ⚠️ 중요: limit 개수만큼만 처리하여 정확한 페이지네이션 보장
            let limitedPdbIds = Array(pdbIds.prefix(limit))
            print("✂️ limit 적용: \(pdbIds.count)개 → \(limitedPdbIds.count)개로 제한")
            
            return try await fetchProteinDetails(batch: limitedPdbIds, intendedCategory: category)
        } else {
            // 전체 검색의 경우 기존 방식 유지 (성능상)
            return try await searchProteinsLegacy(limit: limit)
        }
    }
    
    // 기존 방식 (전체 검색용)
    private func searchProteinsLegacy(limit: Int) async throws -> [ProteinInfo] {
        let query = buildBasicSearchQuery(limit: limit)
        
        guard let url = URL(string: searchBaseURL) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: query)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            let response = try JSONDecoder().decode(PDBSearchResponse.self, from: data)
            let proteins: [ProteinInfo] = response.safeResultSet.compactMap { entry in
                // identifier가 유효한지 확인
                guard !entry.safeIdentifier.isEmpty && entry.safeIdentifier != "UNKNOWN" else { return nil }
                
                let inferredCategory = inferCategory(from: entry)
                let description = generateBetterDescription(from: entry)
                let name = generateBetterName(from: entry)
                
                return ProteinInfo(
                    id: entry.safeIdentifier,
                    name: name,
                    category: inferredCategory,
                    description: description,
                    keywords: extractKeywords(from: entry)
                )
            }
            return proteins
        } catch {
            print("Legacy Search API 디코딩 에러: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("받은 JSON: \(String(jsonString.prefix(500)))...")
            }
            // 빈 배열 반환하여 앱이 크래시되지 않도록 함
            return []
        }
    }
    
    // Legacy API용 설명 생성 함수
    private func generateBetterDescription(from entry: PDBEntry) -> String {
        var parts: [String] = []
        
        if let title = entry.title, !title.isEmpty {
            parts.append(title)
        }
        
        if let classification = entry.classification, !classification.isEmpty {
            parts.append("분류: \(classification)")
        }
        
        if let methods = entry.experimental_method, !methods.isEmpty {
            parts.append("분석방법: \(methods.joined(separator: ", "))")
        }
        
        if let resolution = entry.resolution {
            parts.append("해상도: \(String(format: "%.2f", resolution))Å")
        }
        
        return parts.isEmpty ? "단백질 구조 정보" : parts.joined(separator: " | ")
    }
    
    // Legacy API용 이름 생성 함수
    private func generateBetterName(from entry: PDBEntry) -> String {
        if let title = entry.title, !title.isEmpty {
            // 제목이 너무 길면 적절히 잘라서 사용
            let cleanTitle = title.replacingOccurrences(of: "CRYSTAL STRUCTURE OF", with: "")
                                   .replacingOccurrences(of: "X-RAY STRUCTURE OF", with: "")
                                   .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanTitle.isEmpty {
                return cleanTitle.capitalized
            }
        }
        
        // 제목이 없으면 PDB ID 기반으로 생성
        return "Protein \(entry.safeIdentifier)"
    }
    
    // Legacy API용 키워드 추출 함수
    private func extractKeywords(from entry: PDBEntry) -> [String] {
        var keywords: [String] = []
        
        // PDB ID 추가
        keywords.append(entry.safeIdentifier.lowercased())
        
        // 제목에서 키워드 추출
        if let title = entry.title {
            let titleWords = title.lowercased()
                .replacingOccurrences(of: "crystal structure of", with: "")
                .replacingOccurrences(of: "x-ray structure of", with: "")
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
            let titleWordsArray = Array(titleWords.prefix(3))
            keywords.append(contentsOf: titleWordsArray)
        }
        
        // 분류 정보 추가
        if let classification = entry.classification {
            keywords.append(classification.lowercased())
        }
        
        // 실험 방법 추가
        if let methods = entry.experimental_method {
            keywords.append(contentsOf: methods.map { $0.lowercased() })
        }
        
        // 생물체 정보 추가
        if let organisms = entry.organism_scientific_name {
            keywords.append(contentsOf: organisms.map { $0.lowercased() })
        }
        
        // 중복 제거 및 상위 5개만 반환
        return Array(Array(Set(keywords)).prefix(5))
    }
    
    // Legacy API용 카테고리 추론 함수
    private func inferCategory(from entry: PDBEntry) -> ProteinCategory {
        let title = (entry.title ?? "").lowercased()
        let classification = (entry.classification ?? "").lowercased()
        let keywords = extractKeywords(from: entry).joined(separator: " ").lowercased()
        let allText = "\(title) \(classification) \(keywords)"
        
        // 효소 (Enzymes)
        if allText.contains("enzyme") || allText.contains("kinase") || allText.contains("ase") ||
           allText.contains("transferase") || allText.contains("hydrolase") || allText.contains("lyase") ||
           allText.contains("ligase") || allText.contains("oxidoreductase") || allText.contains("isomerase") {
            return .enzymes
        }
        
        // 구조 단백질 (Structural)
        if allText.contains("collagen") || allText.contains("actin") || allText.contains("tubulin") ||
           allText.contains("keratin") || allText.contains("myosin") || allText.contains("structural") ||
           allText.contains("cytoskeleton") || allText.contains("fibrin") {
            return .structural
        }
        
        // 방어 단백질 (Defense)
        if allText.contains("antibody") || allText.contains("immunoglobulin") || allText.contains("complement") ||
           allText.contains("lysozyme") || allText.contains("defensin") || allText.contains("immune") ||
           allText.contains("interferon") || allText.contains("cytokine") {
            return .defense
        }
        
        // 운반 단백질 (Transport)
        if allText.contains("hemoglobin") || allText.contains("myoglobin") || allText.contains("transferrin") ||
           allText.contains("albumin") || allText.contains("transport") || allText.contains("carrier") ||
           allText.contains("channel") || allText.contains("pump") {
            return .transport
        }
        
        // 호르몬 (Hormones)
        if allText.contains("insulin") || allText.contains("hormone") || allText.contains("growth") ||
           allText.contains("thyroid") || allText.contains("cortisol") || allText.contains("glucagon") ||
           allText.contains("peptide hormone") {
            return .hormones
        }
        
        // 저장 단백질 (Storage)
        if allText.contains("ferritin") || allText.contains("ovalbumin") || allText.contains("casein") ||
           allText.contains("storage") || allText.contains("globulin") || allText.contains("seed") {
            return .storage
        }
        
        // 수용체 (Receptors)
        if allText.contains("receptor") || allText.contains("gpcr") || allText.contains("binding") ||
           allText.contains("ligand") {
            return .receptors
        }
        
        // 막 단백질 (Membrane)
        if allText.contains("membrane") || allText.contains("aquaporin") || allText.contains("channel") ||
           allText.contains("transporter") {
            return .membrane
        }
        
        // 모터 단백질 (Motor)
        if allText.contains("kinesin") || allText.contains("dynein") || allText.contains("motor") ||
           allText.contains("atpase") {
            return .motor
        }
        
        // 신호전달 (Signaling)
        if allText.contains("signaling") || allText.contains("gtpase") || allText.contains("calmodulin") ||
           allText.contains("cyclin") || allText.contains("kinase") {
            return .signaling
        }
        
        // 샤페론 (Chaperones)
        if allText.contains("chaperone") || allText.contains("heat shock") || allText.contains("hsp") ||
           allText.contains("groel") || allText.contains("folding") {
            return .chaperones
        }
        
        // 대사 효소 (Metabolic)
        if allText.contains("metabolic") || allText.contains("glycolysis") || allText.contains("citric") ||
           allText.contains("synthase") || allText.contains("dehydrogenase") {
            return .metabolic
        }
        
        // 기본값: 효소
        return .enzymes
    }
    
    // 카테고리 관련성 점수 계산
    private func calculateCategoryRelevance(entry: PDBEntry, targetCategory: ProteinCategory) -> Double {
        let title = (entry.title ?? "").lowercased()
        let classification = (entry.classification ?? "").lowercased()
        let experimentalMethod = (entry.experimental_method?.joined(separator: " ") ?? "").lowercased()
        let text = "\(title) \(classification) \(experimentalMethod)"
        
        let searchTerms = getCategorySearchTerms(targetCategory)
        var score = 0.0
        
        for term in searchTerms {
            if text.contains(term.lowercased()) {
                score += 1.0
            }
        }
        
        return score / Double(searchTerms.count)
    }

    
    private func buildSearchQuery(category: ProteinCategory?, limit: Int) -> [String: Any] {
        var query: [String: Any] = [
            "return_type": "entry",
            "request_options": [
                "return_all_hits": false,
                "results_verbosity": "minimal",
                "result_limit": limit,
                "sort": [
                    [
                        "sort_by": "score",
                        "direction": "desc"
                    ]
                ]
            ]
        ]
        
        // 카테고리별 더 정교한 검색 쿼리
        if let category = category {
            let searchTerms = getCategorySearchTerms(category)
            
            // OR 조건으로 여러 검색어를 조합 (더 많은 검색어 사용)
            var orQueries: [[String: Any]] = []
            
            for term in Array(searchTerms.prefix(8)) { // 상위 8개 검색어 사용
                // 제목에서 검색
                orQueries.append([
                    "type": "terminal",
                    "service": "text",
                    "parameters": [
                        "attribute": "struct.title",
                        "operator": "contains_phrase",
                        "value": term
                    ]
                ])
                
                // 키워드에서 검색
                orQueries.append([
                    "type": "terminal",
                    "service": "text",
                    "parameters": [
                        "attribute": "struct.keywords",
                        "operator": "contains_phrase",
                        "value": term
                    ]
                ])
            }
            
            query["query"] = [
                "type": "group",
                "logical_operator": "or",
                "nodes": orQueries
            ]
        } else {
            // 전체 검색 시에는 다양한 조건으로 더 많은 데이터 수집
            query["query"] = [
                "type": "group",
                "logical_operator": "or",
                "nodes": [
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "exists"
                        ]
                    ],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "exptl.method",
                            "operator": "exact_match",
                            "value": "X-RAY DIFFRACTION"
                        ]
                    ],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "exptl.method",
                            "operator": "exact_match",
                            "value": "ELECTRON MICROSCOPY"
                        ]
                    ]
                ]
            ]
        }
        
        return query
    }
    
    // MARK: - Advanced Search Queries (구조화된 검색)
    private func buildAdvancedSearchQuery(category: ProteinCategory, limit: Int, skip: Int = 0) -> [String: Any] {
        let query = [
            "query": buildCategorySpecificQuery(category: category),
            "return_type": "entry",
            "request_options": [
                "paginate": [
                    "start": skip, // skip 매개변수를 start로 사용
                    "rows": limit
                ],
                "sort": [
                    [
                        "sort_by": "score",
                        "direction": "desc"
                    ]
                ]
            ]
        ] as [String : Any]
        
        // Structural 카테고리 특별 로깅
        if category == .structural {
            print("🔍 Structural 고급 검색 쿼리 생성:")
            print("   - Limit: \(limit), Skip: \(skip)")
            print("   - 전체 쿼리: \(query)")
        }
        
        return query
    }
    
    private func buildBasicSearchQuery(limit: Int) -> [String: Any] {
        return [
            "query": [
                "type": "group",
                "logical_operator": "and",
                "nodes": [
                    [
                        "type": "group",
                        "logical_operator": "or",
                        "nodes": [
                            [
                                "type": "terminal",
                                "service": "text",
                                "parameters": [
                                    "attribute": "exptl.method",
                                    "operator": "exact_match",
                                    "value": "X-RAY DIFFRACTION"
                                ]
                            ],
                            [
                                "type": "terminal",
                                "service": "text",
                                "parameters": [
                                    "attribute": "exptl.method",
                                    "operator": "exact_match",
                                    "value": "ELECTRON MICROSCOPY"
                                ]
                            ],
                            [
                                "type": "terminal",
                                "service": "text",
                                "parameters": [
                                    "attribute": "exptl.method",
                                    "operator": "exact_match",
                                    "value": "SOLUTION NMR"
                                ]
                            ],
                            [
                                "type": "terminal",
                                "service": "text",
                                "parameters": [
                                    "attribute": "exptl.method",
                                    "operator": "exact_match",
                                    "value": "SOLID-STATE NMR"
                                ]
                            ],
                            [
                                "type": "terminal",
                                "service": "text",
                                "parameters": [
                                    "attribute": "exptl.method",
                                    "operator": "exact_match",
                                    "value": "CRYO-EM"
                                ]
                            ]
                        ]
                    ],
                    [
                        "type": "terminal",
                        "service": "numeric",
                        "parameters": [
                            "attribute": "rcsb_entry_info.resolution_combined",
                            "operator": "less_or_equal",
                            "value": 5.0
                        ]
                    ]
                ]
            ],
            "return_type": "entry",
            "request_options": [
                "paginate": [
                    "start": 0,
                    "rows": limit
                ]
            ]
        ]
    }
    
    // 카테고리별 전문적인 검색 쿼리 (개선된 버전)
    private func buildCategorySpecificQuery(category: ProteinCategory) -> [String: Any] {
        switch category {
        case .enzymes:
            return buildEnzymeQuery()
        case .structural:
            return buildStructuralQuery()
        case .defense:
            return buildDefenseQuery()
        case .transport:
            return buildTransportQuery()
        case .hormones:
            return buildHormoneQuery()
        case .storage:
            return buildStorageQuery()
        case .receptors:
            return buildReceptorQuery()
        case .membrane:
            return buildMembraneQuery()
        case .motor:
            return buildMotorQuery()
        case .signaling:
            return buildSignalingQuery()
        case .chaperones:
            return buildChaperoneQuery()
        case .metabolic:
            return buildMetabolicQuery()
        }
    }
    
    // MARK: - 개선된 검색 쿼리 빌더
    
    // 효소 검색 쿼리 (중복 최소화 + 정밀도 향상)
    private func buildEnzymeQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // EC 번호가 있는 경우 (가장 정확)
                [
                    "type": "terminal",
                    "service": "text",
                    "parameters": [
                        "attribute": "rcsb_polymer_entity_annotation.ec_number",
                        "operator": "exists",
                        "case_sensitive": false
                    ]
                ],
                // 효소 관련 키워드 (OR 조건으로 유연하게)
                [
                    "type": "group",
                    "logical_operator": "or",
                    "nodes": [
                        buildTextSearchNode("struct.title", "enzyme", caseSensitive: false),
                        buildTextSearchNode("struct.title", "kinase", caseSensitive: false),
                        buildTextSearchNode("struct.title", "transferase", caseSensitive: false),
                        buildTextSearchNode("struct.title", "hydrolase", caseSensitive: false),
                        buildTextSearchNode("struct.title", "oxidoreductase", caseSensitive: false)
                    ]
                ],
                // 구조적 키워드와 결합 (AND 조건으로 정밀도 향상)
                [
                    "type": "group",
                    "logical_operator": "and",
                    "nodes": [
                        buildTextSearchNode("struct_keywords.pdbx_keywords", "ENZYME", caseSensitive: false),
                        buildTextSearchNode("struct.title", "protein", caseSensitive: false)
                    ]
                ]
            ]
        ]
    }
    
    // Structural 카테고리 전용 검색 쿼리 (실제 작동하는 curl 쿼리와 동일)
    private func buildStructuralQuery() -> [String: Any] {
        let query: [String: Any] = [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct.title","operator":"contains_words","value":"collagen"]],
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct.title","operator":"contains_words","value":"keratin"]],
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct.title","operator":"contains_words","value":"elastin"]],
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct.title","operator":"contains_words","value":"fibroin"]],
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct.title","operator":"contains_words","value":"laminin"]],
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct.title","operator":"contains_words","value":"intermediate filament"]],
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct.title","operator":"contains_words","value":"cytoskeleton"]],
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct.title","operator":"contains_words","value":"microtubule"]],
                ["type":"terminal","service":"text","parameters":[
                    "attribute":"struct_keywords.pdbx_keywords","operator":"contains_words","value":"structural protein"]]
            ]
        ]
        
        print("🔍 Structural 쿼리 생성: \(query)")
        return query
    }
    
    // 방어 단백질 검색 쿼리 (개선된 버전)
    private func buildDefenseQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "IMMUNE SYSTEM", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "IMMUNOGLOBULIN", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "ANTIBODY", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "COMPLEMENT", caseSensitive: false),
                // 제목 기반 검색
                buildTextSearchNode("struct.title", "antibody", caseSensitive: false),
                buildTextSearchNode("struct.title", "immunoglobulin", caseSensitive: false),
                buildTextSearchNode("struct.title", "complement", caseSensitive: false),
                buildTextSearchNode("struct.title", "interferon", caseSensitive: false),
                buildTextSearchNode("struct.title", "interleukin", caseSensitive: false),
                buildTextSearchNode("struct.title", "cytokine", caseSensitive: false),
                buildTextSearchNode("struct.title", "defensin", caseSensitive: false),
                buildTextSearchNode("struct.title", "lysozyme", caseSensitive: false)
            ]
        ]
    }
    
    // 운반 단백질 검색 쿼리 (개선된 버전)
    private func buildTransportQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "TRANSPORT PROTEIN", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "OXYGEN TRANSPORT", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "METAL TRANSPORT", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "ION TRANSPORT", caseSensitive: false),
                // 대표적인 운반 단백질들
                buildTextSearchNode("struct.title", "hemoglobin", caseSensitive: false),
                buildTextSearchNode("struct.title", "myoglobin", caseSensitive: false),
                buildTextSearchNode("struct.title", "transferrin", caseSensitive: false),
                buildTextSearchNode("struct.title", "albumin", caseSensitive: false),
                // 기능적 키워드
                buildTextSearchNode("struct.title", "transporter", caseSensitive: false),
                buildTextSearchNode("struct.title", "channel", caseSensitive: false),
                buildTextSearchNode("struct.title", "pump", caseSensitive: false),
                buildTextSearchNode("struct.title", "carrier", caseSensitive: false)
            ]
        ]
    }
    
    // 호르몬 검색 쿼리 (개선된 버전)
    private func buildHormoneQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "HORMONE", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "GROWTH FACTOR", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "CYTOKINE", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "SIGNALING PROTEIN", caseSensitive: false),
                // 대표적인 호르몬들
                buildTextSearchNode("struct.title", "insulin", caseSensitive: false),
                buildTextSearchNode("struct.title", "growth hormone", caseSensitive: false),
                buildTextSearchNode("struct.title", "thyroid", caseSensitive: false),
                buildTextSearchNode("struct.title", "glucagon", caseSensitive: false),
                buildTextSearchNode("struct.title", "cortisol", caseSensitive: false),
                buildTextSearchNode("struct.title", "estrogen", caseSensitive: false),
                buildTextSearchNode("struct.title", "testosterone", caseSensitive: false),
                // 기능적 키워드
                buildTextSearchNode("struct.title", "cytokine", caseSensitive: false),
                buildTextSearchNode("struct.title", "signaling", caseSensitive: false),
                buildTextSearchNode("struct.title", "receptor", caseSensitive: false)
            ]
        ]
    }
    
    // 저장 단백질 검색 쿼리 (개선된 버전)
    private func buildStorageQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "STORAGE PROTEIN", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "METAL BINDING", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "LIGAND BINDING", caseSensitive: false),
                // 대표적인 저장 단백질들
                buildTextSearchNode("struct.title", "ferritin", caseSensitive: false),
                buildTextSearchNode("struct.title", "albumin", caseSensitive: false),
                buildTextSearchNode("struct.title", "transferrin", caseSensitive: false),
                buildTextSearchNode("struct.title", "ceruloplasmin", caseSensitive: false),
                // 기능적 키워드
                buildTextSearchNode("struct.title", "storage", caseSensitive: false),
                buildTextSearchNode("struct.title", "binding", caseSensitive: false),
                buildTextSearchNode("struct.title", "reserve", caseSensitive: false),
                buildTextSearchNode("struct.title", "depot", caseSensitive: false),
                buildTextSearchNode("struct.title", "accumulation", caseSensitive: false)
            ]
        ]
    }
    
    // 수용체 검색 쿼리 (개선된 버전)
    private func buildReceptorQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "RECEPTOR", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "GPCR", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "LIGAND BINDING", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "SIGNALING", caseSensitive: false),
                // 제목 기반 검색
                buildTextSearchNode("struct.title", "receptor", caseSensitive: false),
                buildTextSearchNode("struct.title", "gpcr", caseSensitive: false),
                buildTextSearchNode("struct.title", "neurotransmitter", caseSensitive: false),
                buildTextSearchNode("struct.title", "ligand", caseSensitive: false),
                buildTextSearchNode("struct.title", "agonist", caseSensitive: false),
                buildTextSearchNode("struct.title", "antagonist", caseSensitive: false),
                // 특정 수용체 타입
                buildTextSearchNode("struct.title", "adrenergic", caseSensitive: false),
                buildTextSearchNode("struct.title", "dopamine", caseSensitive: false),
                buildTextSearchNode("struct.title", "serotonin", caseSensitive: false),
                buildTextSearchNode("struct.title", "acetylcholine", caseSensitive: false)
            ]
        ]
    }
    
    // 막 단백질 검색 쿼리 (개선된 버전)
    private func buildMembraneQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "MEMBRANE PROTEIN", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "TRANSMEMBRANE", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "INTEGRAL MEMBRANE", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "PERIPHERAL MEMBRANE", caseSensitive: false),
                // 제목 기반 검색
                buildTextSearchNode("struct.title", "membrane", caseSensitive: false),
                buildTextSearchNode("struct.title", "transmembrane", caseSensitive: false),
                buildTextSearchNode("struct.title", "integral", caseSensitive: false),
                buildTextSearchNode("struct.title", "peripheral", caseSensitive: false),
                // 기능적 키워드
                buildTextSearchNode("struct.title", "channel", caseSensitive: false),
                buildTextSearchNode("struct.title", "pore", caseSensitive: false),
                buildTextSearchNode("struct.title", "transporter", caseSensitive: false),
                buildTextSearchNode("struct.title", "pump", caseSensitive: false),
                buildTextSearchNode("struct.title", "barrier", caseSensitive: false)
            ]
        ]
    }
    
    // 모터 단백질 검색 쿼리 (개선된 버전)
    private func buildMotorQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "MOTOR PROTEIN", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "CONTRACTILE PROTEIN", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "MUSCLE PROTEIN", caseSensitive: false),
                // 대표적인 모터 단백질들
                buildTextSearchNode("struct.title", "kinesin", caseSensitive: false),
                buildTextSearchNode("struct.title", "dynein", caseSensitive: false),
                buildTextSearchNode("struct.title", "myosin", caseSensitive: false),
                buildTextSearchNode("struct.title", "tropomyosin", caseSensitive: false),
                buildTextSearchNode("struct.title", "troponin", caseSensitive: false),
                buildTextSearchNode("struct.title", "actin", caseSensitive: false),
                // 기능적 키워드
                buildTextSearchNode("struct.title", "motor", caseSensitive: false),
                buildTextSearchNode("struct.title", "movement", caseSensitive: false),
                buildTextSearchNode("struct.title", "transport", caseSensitive: false),
                buildTextSearchNode("struct.title", "cargo", caseSensitive: false),
                buildTextSearchNode("struct.title", "microtubule", caseSensitive: false),
                buildTextSearchNode("struct.title", "contraction", caseSensitive: false),
                buildTextSearchNode("struct.title", "sliding", caseSensitive: false)
            ]
        ]
    }
    
    // 신호전달 단백질 검색 쿼리 (개선된 버전)
    private func buildSignalingQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "SIGNALING PROTEIN", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "SIGNAL TRANSDUCTION", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "CELL SIGNALING", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "PATHWAY", caseSensitive: false),
                // 제목 기반 검색
                buildTextSearchNode("struct.title", "signaling", caseSensitive: false),
                buildTextSearchNode("struct.title", "pathway", caseSensitive: false),
                buildTextSearchNode("struct.title", "cascade", caseSensitive: false),
                buildTextSearchNode("struct.title", "transduction", caseSensitive: false),
                buildTextSearchNode("struct.title", "messenger", caseSensitive: false),
                buildTextSearchNode("struct.title", "factor", caseSensitive: false),
                buildTextSearchNode("struct.title", "activation", caseSensitive: false),
                buildTextSearchNode("struct.title", "regulation", caseSensitive: false),
                buildTextSearchNode("struct.title", "response", caseSensitive: false)
            ]
        ]
    }
    
    // 샤페론 검색 쿼리 (개선된 버전)
    private func buildChaperoneQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "CHAPERONE", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "HEAT SHOCK", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "PROTEIN FOLDING", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "MOLECULAR CHAPERONE", caseSensitive: false),
                // 제목 기반 검색
                buildTextSearchNode("struct.title", "chaperone", caseSensitive: false),
                buildTextSearchNode("struct.title", "chaperonin", caseSensitive: false),
                buildTextSearchNode("struct.title", "heat shock", caseSensitive: false),
                buildTextSearchNode("struct.title", "hsp", caseSensitive: false),
                buildTextSearchNode("struct.title", "folding", caseSensitive: false),
                // 기능적 키워드
                buildTextSearchNode("struct.title", "assistance", caseSensitive: false),
                buildTextSearchNode("struct.title", "quality", caseSensitive: false),
                buildTextSearchNode("struct.title", "control", caseSensitive: false),
                buildTextSearchNode("struct.title", "refolding", caseSensitive: false)
            ]
        ]
    }
    
    // 대사 단백질 검색 쿼리 (개선된 버전)
    private func buildMetabolicQuery() -> [String: Any] {
        return [
            "type": "group",
            "logical_operator": "or",
            "nodes": [
                // 공식 키워드 기반 (가장 정확)
                buildTextSearchNode("struct_keywords.pdbx_keywords", "METABOLISM", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "METABOLIC PATHWAY", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "BIOSYNTHESIS", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "CATABOLISM", caseSensitive: false),
                buildTextSearchNode("struct_keywords.pdbx_keywords", "ANABOLISM", caseSensitive: false),
                // 제목 기반 검색
                buildTextSearchNode("struct.title", "metabolic", caseSensitive: false),
                buildTextSearchNode("struct.title", "metabolism", caseSensitive: false),
                buildTextSearchNode("struct.title", "glycolysis", caseSensitive: false),
                buildTextSearchNode("struct.title", "citric acid", caseSensitive: false),
                buildTextSearchNode("struct.title", "biosynthesis", caseSensitive: false),
                buildTextSearchNode("struct.title", "catabolism", caseSensitive: false),
                buildTextSearchNode("struct.title", "anabolism", caseSensitive: false),
                // 대사 경로별 키워드
                buildTextSearchNode("struct.title", "fatty acid", caseSensitive: false),
                buildTextSearchNode("struct.title", "amino acid", caseSensitive: false),
                buildTextSearchNode("struct.title", "nucleotide", caseSensitive: false),
                buildTextSearchNode("struct.title", "carbohydrate", caseSensitive: false)
            ]
        ]
    }
    
    // 공통 텍스트 검색 노드 빌더 (대소문자 민감성 해결)
    private func buildTextSearchNode(_ attribute: String, _ value: String, caseSensitive: Bool = false) -> [String: Any] {
        var parameters: [String: Any] = [
            "attribute": attribute,
            "operator": "contains_words",  // contains_phrase에서 contains_words로 변경
            "value": value
        ]
        
        if !caseSensitive {
            parameters["case_sensitive"] = false
        }
        
        return [
            "type": "terminal",
            "service": "text",
            "parameters": parameters
        ]
    }
    
    // 동적 검색어 추가 기능
    func addCustomSearchTerms(to category: ProteinCategory, terms: [String]) -> [String: Any] {
        var baseQuery = buildCategorySpecificQuery(category: category)
        
        // 기존 쿼리에 사용자 정의 검색어 추가
        if var nodes = baseQuery["nodes"] as? [[String: Any]] {
            for term in terms {
                let customNode = buildTextSearchNode("struct.title", term, caseSensitive: false)
                nodes.append(customNode)
            }
            baseQuery["nodes"] = nodes
        }
        
        return baseQuery
    }
    
    // Structural 카테고리 전용 fallback 검색 (사용자 제안 기반 최적화)
    private func searchStructuralFallback(limit: Int, skip: Int = 0) async throws -> ([String], Int) {
        print("🔄 Structural 전용 fallback 검색 시작... (skip: \(skip), limit: \(limit))")
        
        // 여러 단계의 fallback 검색 시도
        let fallbackQueries: [[String: Any]] = [
            // 1단계: 구조적 키워드 기반 (contains_words 사용)
            [
                "query": [
                    "type": "group",
                    "logical_operator": "or",
                    "nodes": [
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct_keywords.pdbx_keywords",
                                "operator": "contains_words",
                                "value": "structural protein"
                            ]
                        ] as [String: Any],
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct_keywords.pdbx_keywords",
                                "operator": "contains_words",
                                "value": "cytoskeletal"
                            ]
                        ] as [String: Any]
                    ]
                ] as [String: Any],
                "return_type": "entry",
                "request_options": [
                    "paginate": [
                        "start": skip, // skip 매개변수 적용
                        "rows": limit
                    ]
                ]
            ] as [String: Any],
            // 2단계: 구체적인 단백질 이름 기반 (contains_words 사용)
            [
                "query": [
                    "type": "group",
                    "logical_operator": "or",
                    "nodes": [
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "collagen"
                            ]
                        ] as [String: Any],
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "keratin"
                            ]
                        ] as [String: Any],
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "elastin"
                            ]
                        ] as [String: Any],
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "fibroin"
                            ]
                        ] as [String: Any],
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "laminin"
                            ]
                        ] as [String: Any]
                    ]
                ] as [String: Any],
                "return_type": "entry",
                "request_options": [
                    "paginate": [
                        "start": skip, // skip 매개변수 적용
                        "rows": limit
                    ]
                ]
            ] as [String: Any],
            // 3단계: 일반적인 구조 키워드 (contains_words 사용)
            [
                "query": [
                    "type": "group",
                    "logical_operator": "or",
                    "nodes": [
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "structural"
                            ]
                        ] as [String: Any],
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "cytoskeleton"
                            ]
                        ] as [String: Any],
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "intermediate filament"
                            ]
                        ] as [String: Any],
                        [
                            "type": "terminal",
                            "service": "text",
                            "parameters": [
                                "attribute": "struct.title",
                                "operator": "contains_words",
                                "value": "microtubule"
                            ]
                        ] as [String: Any]
                    ]
                ] as [String: Any],
                "return_type": "entry",
                "request_options": [
                    "paginate": [
                        "start": skip, // skip 매개변수 적용
                        "rows": limit
                    ]
                ]
            ] as [String: Any]
        ]
        
        // 각 fallback 쿼리를 순차적으로 시도
        for (index, query) in fallbackQueries.enumerated() {
            print("🔄 Structural fallback \(index + 1)단계 시도...")
            let (identifiers, totalCount) = try await executeSearchQuery(query: query, description: "Structural fallback \(index + 1)")
            
            if identifiers.count > 0 {
                print("✅ Structural fallback \(index + 1)단계 성공: \(identifiers.count)개, 전체: \(totalCount)개")
                return (identifiers, totalCount)
            }
        }
        
        print("⚠️ 모든 Structural fallback 검색 실패")
        return ([], 0)
    }
    
    // GraphQL을 통한 일괄 상세 정보 수집 (의도된 카테고리 정보 포함)
    private func fetchProteinDetails(batch: [String], intendedCategory: ProteinCategory? = nil) async throws -> [ProteinInfo] {
        guard !batch.isEmpty else { return [] }
        
        let query = """
        query ($ids: [String!]!) {
          entries(entry_ids: $ids) {
            rcsb_id
            struct { 
              title 
              pdbx_descriptor 
            }
            exptl { 
              method 
            }
            rcsb_entry_info { 
              resolution_combined 
              experimental_method
            }
            rcsb_primary_citation {
              title
              journal_abbrev
            }
            struct_keywords {
              pdbx_keywords
            }
          }
        }
        """
        
        let body = GraphQLBody(query: query, variables: ["ids": batch])
        
        do {
            guard let url = URL(string: graphQLURL) else {
                print("Invalid GraphQL URL: \(graphQLURL)")
                return []
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("GraphQL API HTTP error: \(response)")
                return []
            }
            
            let graphQLResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)
            
            let proteinInfos: [ProteinInfo] = graphQLResponse.data.entries.compactMap { entry in
                convertGraphQLToProteinInfo(from: entry)
            }
            
            print("🧬 GraphQL API 성공: \(proteinInfos.count)개 단백질 정보 변환")
            print("📋 첫 3개 단백질: \(Array(proteinInfos.prefix(3)).map { $0.name })")
            
            return proteinInfos
            
        } catch {
            print("GraphQL API error: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            if let bodyData = try? JSONEncoder().encode(body),
               let jsonString = String(data: bodyData, encoding: .utf8) {
                print("GraphQL request: \(jsonString)")
            }
            
            // GraphQL 실패 시에도 PDB ID는 성공적으로 수집되었으므로
            // 기본 정보로 ProteinInfo 생성
            print("🔄 GraphQL 실패, 기본 정보로 ProteinInfo 생성...")
            let fallbackProteins = batch.map { pdbId in
                createFallbackProteinInfo(pdbId: pdbId, intendedCategory: intendedCategory)
            }
            print("✅ Fallback 데이터 생성 완료: \(fallbackProteins.count)개")
            return fallbackProteins
        }
    }
    
    // GraphQL 응답을 ProteinInfo로 변환
    private func convertGraphQLToProteinInfo(from entry: GraphQLEntry) -> ProteinInfo? {
        guard let rcsb_id = entry.rcsb_id, !rcsb_id.isEmpty else {
            return nil
        }
        
        // 카테고리 추론
        let category = inferCategoryFromGraphQL(entry: entry)
        
        // 설명 생성
        let description = buildDescriptionFromGraphQL(entry: entry)
        
        // 이름 생성
        let name = generateNameFromGraphQL(entry: entry)
        
        // 키워드 추출
        let keywords = extractKeywordsFromGraphQL(entry: entry)
        
        return ProteinInfo(
            id: rcsb_id,
            name: name,
            category: category,
            description: description,
            keywords: keywords
        )
    }
    
    // GraphQL 엔트리로부터 카테고리 추론
    private func inferCategoryFromGraphQL(entry: GraphQLEntry) -> ProteinCategory {
        let title = (entry.pdb_struct?.title ?? "").lowercased()
        let classification = (entry.pdb_struct?.pdbx_descriptor ?? "").lowercased()
        let keywords = (entry.struct_keywords?.pdbx_keywords ?? "").lowercased()
        let methods = (entry.exptl?.compactMap { $0.method } ?? []).joined(separator: " ").lowercased()
        
        let allText = "\(title) \(classification) \(keywords) \(methods)"
        
        // 12개 카테고리에 대한 키워드 매칭 (기존 inferCategory 로직 재사용)
        return inferCategoryFromText(allText)
    }
    
    // 텍스트로부터 카테고리 추론 (공통 로직)
    private func inferCategoryFromText(_ text: String) -> ProteinCategory {
        let lowercaseText = text.lowercased()
        
        // 효소 (Enzymes)
        if lowercaseText.contains("enzyme") || lowercaseText.contains("kinase") || lowercaseText.contains("ase") ||
           lowercaseText.contains("transferase") || lowercaseText.contains("hydrolase") || lowercaseText.contains("lyase") ||
           lowercaseText.contains("ligase") || lowercaseText.contains("oxidoreductase") || lowercaseText.contains("isomerase") {
            return .enzymes
        }
        
        // 구조 단백질 (Structural)
        if lowercaseText.contains("collagen") || lowercaseText.contains("actin") || lowercaseText.contains("tubulin") ||
           lowercaseText.contains("keratin") || lowercaseText.contains("myosin") || lowercaseText.contains("structural") ||
           lowercaseText.contains("cytoskeleton") || lowercaseText.contains("fibrin") {
            return .structural
        }
        
        // 방어 단백질 (Defense)
        if lowercaseText.contains("antibody") || lowercaseText.contains("immunoglobulin") || lowercaseText.contains("complement") ||
           lowercaseText.contains("lysozyme") || lowercaseText.contains("defensin") || lowercaseText.contains("immune") ||
           lowercaseText.contains("interferon") || lowercaseText.contains("cytokine") {
            return .defense
        }
        
        // 운반 단백질 (Transport)
        if lowercaseText.contains("hemoglobin") || lowercaseText.contains("myoglobin") || lowercaseText.contains("transferrin") ||
           lowercaseText.contains("albumin") || lowercaseText.contains("transport") || lowercaseText.contains("carrier") ||
           lowercaseText.contains("channel") || lowercaseText.contains("pump") {
            return .transport
        }
        
        // 호르몬 (Hormones)
        if lowercaseText.contains("insulin") || lowercaseText.contains("hormone") || lowercaseText.contains("growth") ||
           lowercaseText.contains("thyroid") || lowercaseText.contains("cortisol") || lowercaseText.contains("glucagon") {
            return .hormones
        }
        
        // 저장 단백질 (Storage)
        if lowercaseText.contains("ferritin") || lowercaseText.contains("ovalbumin") || lowercaseText.contains("casein") ||
           lowercaseText.contains("storage") || lowercaseText.contains("globulin") {
            return .storage
        }
        
        // 수용체 (Receptors)
        if lowercaseText.contains("receptor") || lowercaseText.contains("gpcr") || lowercaseText.contains("binding") {
            return .receptors
        }
        
        // 막 단백질 (Membrane)
        if lowercaseText.contains("membrane") || lowercaseText.contains("aquaporin") || lowercaseText.contains("transporter") {
            return .membrane
        }
        
        // 모터 단백질 (Motor)
        if lowercaseText.contains("kinesin") || lowercaseText.contains("dynein") || lowercaseText.contains("motor") {
            return .motor
        }
        
        // 신호전달 (Signaling)
        if lowercaseText.contains("signaling") || lowercaseText.contains("gtpase") || lowercaseText.contains("calmodulin") {
            return .signaling
        }
        
        // 샤페론 (Chaperones)
        if lowercaseText.contains("chaperone") || lowercaseText.contains("heat shock") || lowercaseText.contains("hsp") {
            return .chaperones
        }
        
        // 대사 효소 (Metabolic)
        if lowercaseText.contains("metabolic") || lowercaseText.contains("glycolysis") || lowercaseText.contains("synthase") {
            return .metabolic
        }
        
        // 기본값: 효소
        return .enzymes
    }
    
    // GraphQL 엔트리로부터 설명 생성
    private func buildDescriptionFromGraphQL(entry: GraphQLEntry) -> String {
        var parts: [String] = []
        
        if let title = entry.pdb_struct?.title, !title.isEmpty {
            parts.append(title)
        }
        
        if let classification = entry.pdb_struct?.pdbx_descriptor, !classification.isEmpty {
            parts.append("분류: \(classification)")
        }
        
        if let exptl = entry.exptl {
            let methods: [String] = exptl.compactMap { $0.method }
            if !methods.isEmpty {
                parts.append("분석방법: \(methods.joined(separator: ", "))")
            }
        }
        
        if let resolution = entry.rcsb_entry_info?.resolution_combined?.first {
            parts.append("해상도: \(String(format: "%.2f", resolution))Å")
        }
        
        if let journal = entry.rcsb_primary_citation?.journal_abbrev, !journal.isEmpty {
            parts.append("저널: \(journal)")
        }
        
        return parts.isEmpty ? "단백질 구조 정보" : parts.joined(separator: " | ")
    }
    
    // GraphQL 엔트리로부터 이름 생성
    private func generateNameFromGraphQL(entry: GraphQLEntry) -> String {
        if let title = entry.pdb_struct?.title, !title.isEmpty {
            let cleanTitle = title.replacingOccurrences(of: "CRYSTAL STRUCTURE OF", with: "")
                                   .replacingOccurrences(of: "X-RAY STRUCTURE OF", with: "")
                                   .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanTitle.isEmpty {
                return cleanTitle.capitalized
            }
        }
        
        return "Protein \(entry.rcsb_id ?? "Unknown")"
    }
    
    // GraphQL 엔트리로부터 키워드 추출
    private func extractKeywordsFromGraphQL(entry: GraphQLEntry) -> [String] {
        var keywords: [String] = []
        
        // PDB ID 추가
        if let rcsb_id = entry.rcsb_id {
            keywords.append(rcsb_id.lowercased())
        }
        
        // 제목에서 키워드 추출
        if let title = entry.pdb_struct?.title {
            let titleWords = title.lowercased()
                .replacingOccurrences(of: "crystal structure of", with: "")
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
            let titleWordsArray = Array(titleWords.prefix(3))
            keywords.append(contentsOf: titleWordsArray)
        }
        
        // 분류 정보 추가
        if let classification = entry.pdb_struct?.pdbx_descriptor {
            keywords.append(classification.lowercased())
        }
        
        // 키워드 정보 추가
        if let pdbx_keywords = entry.struct_keywords?.pdbx_keywords {
            let keywordList = pdbx_keywords.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            let keywordArray = Array(keywordList.prefix(3))
            keywords.append(contentsOf: keywordArray)
        }
        
        // 중복 제거 및 상위 5개만 반환
        return Array(Array(Set(keywords)).prefix(5))
    }
    
    // MARK: - Main Search Function (2-Stage Loading with Guaranteed Results)
    func searchProteins(category: ProteinCategory, limit: Int = 30) async throws -> [ProteinInfo] {
        print("🔍 Starting 2-stage search for \(category) with limit \(limit)")
        
        var finalProteins: [ProteinInfo] = []
        
        do {
            // Stage 1: Search for PDB IDs (더 많은 ID 수집)
            print("🔄 Stage 1: PDB ID 검색 시작...")
            let (pdbIds, _) = try await searchProteinsByCategory(category: category, limit: limit * 5)
            print("📋 Stage 1 완료: \(pdbIds.count)개 PDB ID 수집")
            
            if !pdbIds.isEmpty {
                // Stage 2: Enrich with detailed information (GraphQL batch)
                print("🔄 Stage 2: 상세 정보 수집 시작...")
                let detailedProteins = try await fetchProteinDetails(batch: pdbIds)
                print("📋 Stage 2 완료: \(detailedProteins.count)개 상세 정보 수집")
                
                if !detailedProteins.isEmpty {
                    finalProteins = detailedProteins
                }
            }
            
            // API 데이터가 부족하면 fallback 시도
            if finalProteins.count < 5 {
                print("⚠️ API 데이터 부족 (\(finalProteins.count)개), fallback 검색 시도...")
                let (fallbackIds, _) = try await searchWithFallback(category: category, limit: limit)
                if !fallbackIds.isEmpty {
                    let fallbackProteins = try await fetchProteinDetails(batch: Array(fallbackIds.prefix(limit)))
                    if !fallbackProteins.isEmpty {
                        // 기존 데이터와 중복 제거 후 더하기
                        let newProteins = fallbackProteins.filter { fallback in
                            !finalProteins.contains { $0.id == fallback.id }
                        }
                        finalProteins.append(contentsOf: newProteins)
                        print("✅ Fallback 성공: \(newProteins.count)개 추가 데이터 수집")
                    }
                }
            }
            
        } catch {
            print("❌ API 검색 오류: \(error.localizedDescription)")
        }
        
        // API 데이터만 반환 (샘플 데이터 제외)
        print("✅ \(category) 카테고리 API 검색 완료: 총 \(finalProteins.count)개 API 단백질")
        return Array(finalProteins.prefix(limit)) // limit로 제한
    }

    // Fallback 검색 (더 관대한 조건)
    func searchWithFallback(category: ProteinCategory, limit: Int, skip: Int = 0) async throws -> ([String], Int) {
        let categoryTerms = getCategorySearchTerms(category)
        
        // Structural 카테고리 전용 특별 처리
        if category == .structural {
            return try await searchStructuralFallback(limit: limit, skip: skip)
        }
        
        // 더 포괄적인 검색을 위해 여러 필드에서 검색
        let simpleQuery: [String: Any] = [
            "query": [
                "type": "group",
                "logical_operator": "or",
                "nodes": [
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "contains_words",
                            "value": categoryTerms.first ?? category.rawValue.lowercased()
                        ]
                    ] as [String: Any],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct_keywords.pdbx_keywords",
                            "operator": "contains_words",
                            "value": category.rawValue.uppercased()
                        ]
                    ] as [String: Any],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "contains_words",
                            "value": category.rawValue.lowercased()
                        ]
                    ] as [String: Any],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct.title",
                            "operator": "contains_words",
                            "value": categoryTerms.randomElement() ?? "protein"
                        ]
                    ] as [String: Any],
                    [
                        "type": "terminal",
                        "service": "text",
                        "parameters": [
                            "attribute": "struct_keywords.pdbx_keywords",
                            "operator": "contains_words",
                            "value": "PROTEIN"
                        ]
                    ] as [String: Any]
                ]
            ] as [String: Any],
            "return_type": "entry",
            "request_options": [
                "paginate": [
                    "start": skip, // skip 매개변수 적용
                    "rows": limit
                ]
            ]
        ]
        
        guard let url = URL(string: searchBaseURL) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: simpleQuery)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            let response = try JSONDecoder().decode(PDBSearchResponse.self, from: data)
            let identifiers: [String] = response.safeResultSet.compactMap { entry in
                guard !entry.safeIdentifier.isEmpty && entry.safeIdentifier != "UNKNOWN" else { return nil }
                return entry.safeIdentifier
            }
            let totalCount = response.safeTotalCount
            print("🔄 Fallback search for \(category): \(identifiers.count) results, total: \(totalCount)")
            return (identifiers, totalCount)
        } catch {
            print("❌ Fallback search failed: \(error)")
            return ([], 0)
        }
    }

    // API 디코딩 실패 시 기본 ProteinInfo 생성 (의도된 카테고리 지원)
    private func createFallbackProteinInfo(pdbId: String, intendedCategory: ProteinCategory? = nil) -> ProteinInfo {
        // 의도된 카테고리가 있으면 사용, 없으면 PDB ID로부터 추론
        let category: ProteinCategory
        if let intendedCategory = intendedCategory {
            category = intendedCategory
            print("🎡 PDB ID \(pdbId): 의도된 카테고리 \(intendedCategory.rawValue) 사용")
        } else {
            category = inferCategoryFromPdbId(pdbId: pdbId)
            print("🔍 PDB ID \(pdbId): 추론된 카테고리 \(category.rawValue) 사용")
        }
        
        return ProteinInfo(
            id: pdbId,
            name: "Protein \(pdbId.uppercased())",
            category: category,
            description: "구조 정보를 로드하는 중입니다. PDB ID: \(pdbId.uppercased())",
            keywords: ["protein", "structure", pdbId.lowercased()]
        )
    }
    
    // PDB ID로부터 간단한 카테고리 추론
    private func inferCategoryFromPdbId(pdbId: String) -> ProteinCategory {
        let idLower = pdbId.lowercased()
        
        // 일반적인 PDB ID 패턴을 통한 추론
        if idLower.contains("enz") || idLower.contains("cat") || idLower.contains("lyz") {
            return .enzymes
        } else if idLower.contains("hgb") || idLower.contains("myb") || idLower.contains("trf") {
            return .transport
        } else if idLower.contains("col") || idLower.contains("act") || idLower.contains("tub") {
            return .structural
        } else if idLower.contains("igg") || idLower.contains("ign") || idLower.contains("def") {
            return .defense
        } else if idLower.contains("ins") || idLower.contains("gh") || idLower.contains("hor") {
            return .hormones
        } else if idLower.contains("fer") || idLower.contains("alb") || idLower.contains("ova") {
            return .storage
        }
        
        // 기본값은 enzymes (가장 일반적)
        return .enzymes
    }
    
    private func convertToProteinInfo(from detail: PDBDetailResponse, pdbId: String) -> ProteinInfo {
        let title = detail.pdb_struct?.title ?? "Unknown Structure"
        
        // 더 정확한 카테고리 추론
        let category = inferCategoryFromDetail(detail: detail)
        
        let description = buildDetailedDescription(from: detail)
        let name = generateBetterNameFromTitle(title: title)
        
        return ProteinInfo(
            id: pdbId,
            name: name,
            category: category,
            description: description,
            keywords: extractKeywordsFromDetail(detail: detail)
        )
    }
    
    // Data API 응답으로부터 카테고리 추론
    private func inferCategoryFromDetail(detail: PDBDetailResponse) -> ProteinCategory {
        let title = (detail.pdb_struct?.title ?? "").lowercased()
        let keywords = (detail.struct_keywords?.pdbx_keywords ?? "").lowercased()
        let classification = (detail.pdb_struct?.pdbx_descriptor ?? "").lowercased()
        let text = "\(title) \(keywords) \(classification)"
        
        // 키워드 기반 우선 분류
        if keywords.contains("immune system") || keywords.contains("antibody") {
            return .defense
        } else if keywords.contains("transport protein") || keywords.contains("oxygen transport") {
            return .transport
        } else if keywords.contains("structural protein") {
            return .structural
        } else if keywords.contains("enzyme") || keywords.contains("hydrolase") || keywords.contains("transferase") {
            return .enzymes
        } else if keywords.contains("hormone") {
            return .hormones
        } else if keywords.contains("receptor") {
            return .receptors
        } else if keywords.contains("membrane protein") {
            return .membrane
        } else if keywords.contains("metabolism") {
            return .metabolic
        } else {
            // 기존 제목 기반 추론으로 fallback
            return inferCategoryFromTitle(text)
        }
    }
    
    private func inferCategoryFromTitle(_ text: String) -> ProteinCategory {
        if text.contains("chaperone") || text.contains("heat shock") {
            return .chaperones
        } else if text.contains("motor") || text.contains("kinesin") || text.contains("dynein") {
            return .motor
        } else if text.contains("signaling") || text.contains("pathway") {
            return .signaling
        } else if text.contains("enzyme") || text.contains("kinase") || text.contains("phosphatase") {
            return .enzymes
        } else if text.contains("membrane") || text.contains("channel") {
            return .membrane
        } else if text.contains("receptor") {
            return .receptors
        } else if text.contains("transport") || text.contains("hemoglobin") {
            return .transport
        } else if text.contains("structural") || text.contains("collagen") {
            return .structural
        } else if text.contains("defense") || text.contains("immune") {
            return .defense
        } else if text.contains("hormone") {
            return .hormones
        } else if text.contains("storage") || text.contains("ferritin") {
            return .storage
        } else if text.contains("metabolic") || text.contains("metabolism") {
            return .metabolic
        } else {
            return .structural // 기본값
        }
    }
    
    private func buildDetailedDescription(from detail: PDBDetailResponse) -> String {
        var parts: [String] = []
        
        if let title = detail.pdb_struct?.title, !title.isEmpty {
            parts.append(title)
        }
        
        if let classification = detail.pdb_struct?.pdbx_descriptor, !classification.isEmpty {
            parts.append("분류: \(classification)")
        }
        
        if let methods = detail.rcsb_entry_info?.experimental_method, !methods.isEmpty {
            parts.append("실험방법: \(methods.joined(separator: ", "))")
        }
        
        if let resolution = detail.rcsb_entry_info?.resolution_combined?.first {
            parts.append("해상도: \(String(format: "%.2f", resolution))Å")
        }
        
        if let journal = detail.rcsb_primary_citation?.journal_abbrev {
            parts.append("저널: \(journal)")
        }
        
        return parts.isEmpty ? "단백질 구조 정보" : parts.joined(separator: " | ")
    }
    
    private func extractKeywordsFromDetail(detail: PDBDetailResponse) -> [String] {
        var keywords: [String] = []
        
        if let title = detail.pdb_struct?.title {
            keywords.append(contentsOf: title.components(separatedBy: " ").filter { $0.count > 2 })
        }
        
        if let pdbxKeywords = detail.struct_keywords?.pdbx_keywords {
            keywords.append(contentsOf: pdbxKeywords.components(separatedBy: ", "))
        }
        
        if let methods = detail.rcsb_entry_info?.experimental_method {
            keywords.append(contentsOf: methods)
        }
        
        return Array(Array(Set(keywords.map { $0.lowercased() })).prefix(8))
    }
    
    // 제목 문자열로부터 이름 생성
    private func generateBetterNameFromTitle(title: String) -> String {
        let unwantedWords = ["crystal", "structure", "complex", "domain", "fragment", "mutant", "variant"]
        let words = title.components(separatedBy: " ")
        let filteredWords = words.filter { word in
            !unwantedWords.contains(word.lowercased())
        }
        
        let meaningfulWords = Array(filteredWords.prefix(4)).joined(separator: " ")
        return meaningfulWords.isEmpty ? "Unknown Protein" : meaningfulWords
    }
    
    private func getCategorySearchTerms(_ category: ProteinCategory) -> [String] {
        switch category {
        case .enzymes:
            return ["kinase", "phosphatase", "enzyme", "catalase", "oxidase", "reductase", "transferase", "hydrolase", "ligase", "isomerase"]
        case .structural:
            return [
                // 섬유성 단백질 계열
                "collagen", "keratin", "elastin", "fibroin", "laminin",
                // 세포골격 단백질 계열
                "actin", "tubulin", "titin", "spectrin", "dystrophin",
                // 중간섬유 단백질
                "vimentin", "desmin", "lamin", "neurofilament",
                // 구조적 기능 키워드
                "cytoskeleton", "intermediate filament", "microtubule", "microfilament",
                "thick filament", "thin filament", "scaffold", "matrix",
                "filament", "fiber", "bundle", "network",
                // 추가 구조 단백질들
                "fibrin", "fibronectin", "tenascin", "osteopontin", "bone sialoprotein", "osteocalcin",
                "myosin", "tropomyosin", "troponin", "nebulin", "dystrophin", "utrophin"
            ]
        case .defense:
            return ["immunoglobulin", "antibody", "complement", "lysozyme", "defensin", "interferon", "interleukin", "cytokine", "antigen", "immune"]
        case .transport:
            return ["hemoglobin", "myoglobin", "transferrin", "albumin", "transporter", "channel", "pump", "carrier", "receptor", "binding"]
        case .hormones:
            return ["insulin", "hormone", "growth", "cytokine", "signaling", "receptor", "factor", "regulator", "activator", "inhibitor"]
        case .storage:
            return ["ferritin", "albumin", "storage", "binding", "carrier", "reserve", "depot", "accumulation", "sequestration", "retention"]
        case .receptors:
            return ["receptor", "gpcr", "neurotransmitter", "agonist", "antagonist", "ligand", "binding", "membrane", "signaling", "activation"]
        case .membrane:
            return ["membrane", "integral", "peripheral", "transmembrane", "lipid", "channel", "pore", "transporter", "pump", "barrier"]
        case .motor:
            return ["motor", "kinesin", "dynein", "myosin", "movement", "transport", "cargo", "microtubule", "actin", "contraction"]
        case .signaling:
            return ["signaling", "pathway", "cascade", "messenger", "factor", "protein", "transduction", "activation", "regulation", "response"]
        case .chaperones:
            return ["chaperone", "chaperonin", "folding", "hsp", "shock", "protein", "assistance", "quality", "control", "refolding"]
        case .metabolic:
            return ["metabolic", "metabolism", "pathway", "biosynthesis", "catabolism", "anabolism", "glycolysis", "citric", "fatty", "amino"]
        }
    }

    
    // 백업용 샘플 데이터 생성
    func getSampleProteins(for category: ProteinCategory) -> [ProteinInfo] {
        switch category {
        case .enzymes:
            return [
                ProteinInfo(id: "1LYZ", name: "리소자임", category: .enzymes, 
                           description: "세균의 세포벽을 분해하여 항균 작용을 하는 효소 | 분류: Hydrolase | 분석방법: X-ray crystallography", 
                           keywords: ["enzyme", "antibacterial", "hydrolase"]),
                ProteinInfo(id: "1CAT", name: "카탈레이스", category: .enzymes, 
                           description: "과산화수소를 물과 산소로 분해하는 산화환원 효소 | 분류: Oxidoreductase | 분석방법: X-ray crystallography", 
                           keywords: ["enzyme", "antioxidant", "oxidoreductase"]),
                ProteinInfo(id: "1ATP", name: "ATP 신타제", category: .enzymes, 
                           description: "ATP 생성을 담당하는 핵심 효소 | 분류: Transferase | 분석방법: Cryo-EM", 
                           keywords: ["enzyme", "ATP", "energy"])
            ]
        case .structural:
            return [
                ProteinInfo(id: "1CGD", name: "콜라겐", category: .structural, 
                           description: "피부, 뼈, 연골의 주요 구조 단백질 | 분류: Structural protein | 분석방법: X-ray fiber diffraction", 
                           keywords: ["structural", "collagen", "connective tissue"]),
                ProteinInfo(id: "1ATN", name: "액틴", category: .structural, 
                           description: "세포골격을 이루는 주요 단백질, 근육 수축에 관여 | 분류: Motor protein | 분석방법: X-ray crystallography", 
                           keywords: ["structural", "cytoskeleton", "muscle"]),
                ProteinInfo(id: "1TUB", name: "튜불린", category: .structural, 
                           description: "미세소관을 형성하는 구조 단백질 | 분류: Structural protein | 분석방법: Cryo-EM", 
                           keywords: ["structural", "microtubule", "cytoskeleton"]),
                ProteinInfo(id: "1KER", name: "케라틴", category: .structural, 
                           description: "머리카락, 손톱, 피부의 주요 구조 단백질 | 분류: Structural protein | 분석방법: X-ray crystallography", 
                           keywords: ["structural", "keratin", "hair", "nail"]),
                ProteinInfo(id: "1ELA", name: "엘라스틴", category: .structural, 
                           description: "피부와 혈관의 탄성을 유지하는 구조 단백질 | 분류: Structural protein | 분석방법: X-ray crystallography", 
                           keywords: ["structural", "elastin", "elasticity", "skin"]),
                ProteinInfo(id: "1FIB", name: "피브린", category: .structural, 
                           description: "혈액 응고에 관여하는 섬유성 단백질 | 분류: Structural protein | 분석방법: X-ray crystallography", 
                           keywords: ["structural", "fibrin", "blood clotting", "coagulation"])
            ]
        case .defense:
            return [
                ProteinInfo(id: "1IGG", name: "면역글로불린 G", category: .defense, 
                           description: "가장 흔한 항체로 병원체를 중화시키는 방어 단백질 | 분류: Immunoglobulin | 분석방법: X-ray crystallography", 
                           keywords: ["antibody", "immune", "immunoglobulin"]),
                ProteinInfo(id: "1C3D", name: "보체 C3", category: .defense, 
                           description: "면역 반응에서 병원체를 제거하는 보체 단백질 | 분류: Immune system protein | 분석방법: X-ray crystallography", 
                           keywords: ["complement", "immune", "defense"]),
                ProteinInfo(id: "1IFN", name: "인터페론", category: .defense, 
                           description: "바이러스 감염에 대항하는 사이토카인 | 분류: Cytokine | 분석방법: NMR", 
                           keywords: ["cytokine", "antiviral", "interferon"])
            ]
        case .transport:
            return [
                ProteinInfo(id: "1HHB", name: "헤모글로빈", category: .transport, 
                           description: "혈액에서 산소를 운반하는 적혈구의 주요 단백질 | 분류: Oxygen transport | 분석방법: X-ray crystallography", 
                           keywords: ["transport", "oxygen", "hemoglobin", "blood"]),
                ProteinInfo(id: "1MYG", name: "미오글로빈", category: .transport, 
                           description: "근육 조직에서 산소를 저장하고 운반하는 단백질 | 분류: Oxygen storage | 분석방법: X-ray crystallography", 
                           keywords: ["transport", "oxygen", "myoglobin", "muscle"]),
                ProteinInfo(id: "1TFN", name: "트랜스페린", category: .transport, 
                           description: "혈액에서 철분을 운반하는 당단백질 | 분류: Metal transport | 분석방법: X-ray crystallography", 
                           keywords: ["transport", "iron", "transferrin"])
            ]
        case .hormones:
            return [
                ProteinInfo(id: "1ZNJ", name: "인슐린", category: .hormones, 
                           description: "혈당 조절을 담당하는 췌장 호르몬 | 분류: Hormone | 분석방법: X-ray crystallography", 
                           keywords: ["hormone", "insulin", "glucose", "diabetes"]),
                ProteinInfo(id: "1GH1", name: "성장 호르몬", category: .hormones, 
                           description: "뇌하수체에서 분비되는 성장과 발달을 촉진하는 호르몬 | 분류: Growth factor | 분석방법: X-ray crystallography", 
                           keywords: ["hormone", "growth", "pituitary"]),
                ProteinInfo(id: "1TH1", name: "갑상선 호르몬", category: .hormones, 
                           description: "신진대사를 조절하는 갑상선 호르몬 | 분류: Hormone | 분석방법: X-ray crystallography", 
                           keywords: ["hormone", "thyroid", "metabolism"])
            ]
        case .storage:
            return [
                ProteinInfo(id: "1FHA", name: "페리틴", category: .storage, 
                           description: "세포 내에서 철분을 안전하게 저장하는 단백질 | 분류: Metal storage | 분석방법: X-ray crystallography", 
                           keywords: ["storage", "iron", "ferritin"]),
                ProteinInfo(id: "1BM0", name: "혈청 알부민", category: .storage, 
                           description: "혈액에서 지방산과 호르몬을 저장하고 운반 | 분류: Storage protein | 분석방법: X-ray crystallography", 
                           keywords: ["storage", "albumin", "fatty acid"]),
                ProteinInfo(id: "1OVA", name: "오브알부민", category: .storage, 
                           description: "달걀흰자의 주요 저장 단백질 | 분류: Storage protein | 분석방법: X-ray crystallography", 
                           keywords: ["storage", "ovalbumin", "egg"])
            ]
        case .receptors:
            return [
                ProteinInfo(id: "1GPR", name: "G-단백질 연결 수용체", category: .receptors, 
                           description: "세포막에서 신호를 받아들이는 주요 수용체 | 분류: GPCR | 분석방법: Cryo-EM", 
                           keywords: ["receptor", "GPCR", "signaling", "membrane"]),
                ProteinInfo(id: "1ACH", name: "아세틸콜린 수용체", category: .receptors, 
                           description: "신경전달물질 아세틸콜린을 인식하는 수용체 | 분류: Neurotransmitter receptor | 분석방법: Cryo-EM", 
                           keywords: ["receptor", "acetylcholine", "neurotransmitter"]),
                ProteinInfo(id: "1INS", name: "인슐린 수용체", category: .receptors, 
                           description: "혈당 조절을 위한 인슐린 신호를 받는 수용체 | 분류: Hormone receptor | 분석방법: X-ray crystallography", 
                           keywords: ["receptor", "insulin", "hormone", "diabetes"])
            ]
        case .membrane:
            return [
                ProteinInfo(id: "1AQP", name: "아쿠아포린", category: .membrane, 
                           description: "세포막을 통한 물 이동을 조절하는 막단백질 | 분류: Water channel | 분석방법: X-ray crystallography", 
                           keywords: ["membrane", "water", "channel", "aquaporin"]),
                ProteinInfo(id: "1SOD", name: "나트륨-칼륨 펌프", category: .membrane, 
                           description: "세포막에서 이온 농도를 조절하는 펌프 | 분류: Ion pump | 분석방법: Cryo-EM", 
                           keywords: ["membrane", "pump", "sodium", "potassium"]),
                ProteinInfo(id: "1BAC", name: "박테리오로돕신", category: .membrane, 
                           description: "빛 에너지를 이용하는 막관통 단백질 | 분류: Light-driven pump | 분석방법: X-ray crystallography", 
                           keywords: ["membrane", "light", "proton pump", "bacteriorhodopsin"])
            ]
        case .motor:
            return [
                ProteinInfo(id: "1KIN", name: "키네신", category: .motor, 
                           description: "미세소관을 따라 이동하는 모터 단백질 | 분류: Motor protein | 분석방법: X-ray crystallography", 
                           keywords: ["motor", "kinesin", "microtubule", "transport"]),
                ProteinInfo(id: "1DYN", name: "다이네인", category: .motor, 
                           description: "세포 내 역방향 이동을 담당하는 모터 단백질 | 분류: Motor protein | 분석방법: Cryo-EM", 
                           keywords: ["motor", "dynein", "microtubule", "retrograde"]),
                ProteinInfo(id: "1MYS", name: "미오신 II", category: .motor, 
                           description: "근육 수축을 담당하는 주요 모터 단백질 | 분류: Motor protein | 분석방법: X-ray crystallography", 
                           keywords: ["motor", "myosin", "muscle", "contraction"])
            ]
        case .signaling:
            return [
                ProteinInfo(id: "1RAS", name: "Ras 단백질", category: .signaling, 
                           description: "세포 증식과 분화를 조절하는 신호전달 단백질 | 분류: GTPase | 분석방법: X-ray crystallography", 
                           keywords: ["signaling", "GTPase", "cell growth", "oncogene"]),
                ProteinInfo(id: "1CAM", name: "칼모듈린", category: .signaling, 
                           description: "칼슘 신호를 전달하는 중요한 신호전달 단백질 | 분류: Calcium-binding | 분석방법: X-ray crystallography", 
                           keywords: ["signaling", "calcium", "calmodulin", "binding"]),
                ProteinInfo(id: "1CYC", name: "사이클린", category: .signaling, 
                           description: "세포 주기를 조절하는 신호전달 단백질 | 분류: Cell cycle regulator | 분석방법: X-ray crystallography", 
                           keywords: ["signaling", "cell cycle", "cyclin", "regulation"])
            ]
        case .chaperones:
            return [
                ProteinInfo(id: "1HSP", name: "열충격 단백질 70", category: .chaperones, 
                           description: "스트레스 상황에서 단백질 접힘을 도와주는 샤페론 | 분류: Molecular chaperone | 분석방법: X-ray crystallography", 
                           keywords: ["chaperone", "heat shock", "protein folding", "stress"]),
                ProteinInfo(id: "1GRO", name: "GroEL", category: .chaperones, 
                           description: "세균의 대표적인 샤페로닌 복합체 | 분류: Chaperonin | 분석방법: Cryo-EM", 
                           keywords: ["chaperonin", "protein folding", "bacterial", "GroEL"]),
                ProteinInfo(id: "1PDI", name: "단백질 이황화 이성화효소", category: .chaperones, 
                           description: "단백질의 이황화 결합 형성을 도와주는 효소 | 분류: Protein disulfide isomerase | 분석방법: X-ray crystallography", 
                           keywords: ["chaperone", "disulfide", "isomerase", "folding"])
            ]
        case .metabolic:
            return [
                ProteinInfo(id: "1PFK", name: "포스포프럭토키나제", category: .metabolic, 
                           description: "당분해 과정의 핵심 조절 효소 | 분류: Metabolic enzyme | 분석방법: X-ray crystallography", 
                           keywords: ["metabolic", "glycolysis", "kinase", "regulation"]),
                ProteinInfo(id: "1CIT", name: "시트르산 신타제", category: .metabolic, 
                           description: "시트르산 회로의 첫 번째 효소 | 분류: Metabolic enzyme | 분석방법: X-ray crystallography", 
                           keywords: ["metabolic", "citric acid cycle", "synthase", "TCA"]),
                ProteinInfo(id: "1FAD", name: "지방산 신타제", category: .metabolic, 
                           description: "지방산 생합성을 담당하는 효소 복합체 | 분류: Metabolic enzyme | 분석방법: Cryo-EM", 
                           keywords: ["metabolic", "fatty acid", "synthesis", "lipid"])
            ]
        }
    }
}

// MARK: - Protein Database

class ProteinDatabase: ObservableObject {
    @Published var proteins: [ProteinInfo] = []
    @Published var favorites: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var categoryTotalCounts: [ProteinCategory: Int] = [:]
    
    let apiService = PDBAPIService.shared
    private var loadedCategories: Set<ProteinCategory> = []
    
    // 페이지네이션 상태 관리
    private var categoryPages: [ProteinCategory: Int] = [:]
    private var categoryHasMore: [ProteinCategory: Bool] = [:]
    private let itemsPerPage = 30
    
    init() {
        // 초기화 시 기본 샘플 데이터를 먼저 로드
        loadBasicSampleData()
        
        // API에서 실제 데이터 로드 시도 (loadAllCategoriesWithPagination에서 처리)
        // 초기화 시 API 카운트도 미리 로드
        Task {
            await loadAllCategoryCounts()
        }
    }
    
    private func loadBasicSampleData() {
        print("🔄 Starting to load basic sample data...")
        var allSamples: [ProteinInfo] = []
        for category in ProteinCategory.allCases {
            let samples = apiService.getSampleProteins(for: category)
            print("📦 Category \(category.rawValue): \(samples.count) samples")
            allSamples.append(contentsOf: samples)
        }
        proteins = allSamples
        print("✅ Loaded \(allSamples.count) basic sample proteins for all categories")
        print("🔍 First 3 proteins: \(Array(allSamples.prefix(3)).map { $0.name })")
    }
    
    private func loadInitialData() async {
        print("Loading initial data for all categories...")
        await loadAllCategoriesWithPagination()
    }
    
    func loadProteins(for category: ProteinCategory? = nil, refresh: Bool = false) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        if let category = category {
            // 특정 카테고리의 첫 페이지 로드 (실제 API 데이터 우선, 실패 시 샘플 데이터 유지)
            print("🔍 \(category.rawValue) 카테고리 실제 데이터 로딩 시작...")
            
            // categoryHasMore 상태 초기화 (기본값을 true로 설정)
            await MainActor.run {
                categoryHasMore[category] = true
            }
            
            do {
                // 먼저 샘플 데이터가 있는지 확인
                let _ = proteins.filter { $0.category == category }
                let _ = !proteins.filter { $0.category == category }.isEmpty
                
                // 실제 API 데이터 로드 시도
                try await loadCategoryPage(category: category, refresh: true)
                print("✅ \(category.rawValue) 카테고리 로딩 완료")
                
                // 로드된 실제 데이터 확인
                let loadedRealProteins = proteins.filter { $0.category == category }
                if loadedRealProteins.isEmpty {
                    print("⚠️ \(category.rawValue) 실제 데이터 없음, 샘플 데이터 유지")
                    // 샘플 데이터 복원
                    let sampleProteins = apiService.getSampleProteins(for: category)
                    await MainActor.run {
                        proteins.append(contentsOf: sampleProteins)
                        // API가 실패했지만 더 시도해볼 수 있으므로 hasMore는 여전히 true로 유지
                        // 샘플 데이터만 있는 경우에는 실제 API 데이터가 있을 가능성이 있으므로 true 유지
                        categoryHasMore[category] = true
                    }
                } else {
                    print("✅ \(category.rawValue) 실제 API 데이터 \(loadedRealProteins.count)개 로드 성공")
                }
            } catch {
                print("❌ \(category.rawValue) 로딩 실패: \(error.localizedDescription)")
                
                // API 실패 시 샘플 데이터 사용
                await MainActor.run {
                    proteins.removeAll { $0.category == category }
                    let sampleProteins = apiService.getSampleProteins(for: category)
                    proteins.append(contentsOf: sampleProteins)
                    errorMessage = "Using sample data for \(category.rawValue) (API error: \(error.localizedDescription))"
                    // API 실패했지만 재시도 가능성이 있으므로 hasMore는 true 유지
                    // 사용자가 Load More를 누르면 다시 API를 시도할 수 있음
                    categoryHasMore[category] = true
                }
                print("🔄 \(category.rawValue) 샘플 데이터로 복원 완료")
            }
        } else {
            // 전체 카테고리의 샘플 데이터만 로드 (빠른 시작)
            if proteins.isEmpty || refresh {
                print("🚀 전체 카테고리 샘플 데이터 로딩...")
                await loadAllCategoriesWithPagination()
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // 특정 카테고리의 페이지 로드 (수정됨: 실제 API 데이터 우선, 실패 시 폴백)
    private func loadCategoryPage(category: ProteinCategory, refresh: Bool = false) async throws {
        if refresh {
            categoryPages[category] = 0
            categoryHasMore[category] = true
            await MainActor.run {
                proteins.removeAll { $0.category == category }
            }
        }
        
        let currentPage = categoryPages[category] ?? 0
        print("🔄 \(category.rawValue) 카테고리 실제 API 데이터 로딩 중... (페이지 \(currentPage + 1))")
        
        do {
            // 실제 API에서 30개씩 가져오기 (페이지네이션)
            let skip = currentPage * itemsPerPage
            let limit = itemsPerPage // 항상 30개씩
            
            print("📡 API 호출: skip=\(skip), limit=\(limit)")
            print("🗒 예상 로드 개수: \(limit)개 (해당 카테고리의 API 데이터만)")
            let newProteins = try await apiService.searchProteins(category: category, limit: limit, skip: skip)
            print("✅ \(category.rawValue): \(newProteins.count)개 실제 단백질 로드 완료 (페이지 \(currentPage + 1))")
            print("🔍 받은 데이터 상세: \(newProteins.count)/\(limit) (샘플 데이터 제외)")
            
            // API 데이터가 30개 미만이면 원인 디버깅
            if newProteins.count < limit {
                print("⚠️ 예상보다 적은 데이터: \(newProteins.count)<\(limit)")
                print("   - API 응답이 비어있거나")
                print("   - 해당 카테고리에 데이터가 부족하다는 의미")
                print("   - searchProteins 함수 내부 로직 확인 필요")
            }
            
            // 모든 API 데이터를 사용 (샘플 데이터 포함)
            let allProteins = newProteins
            
            await MainActor.run {
                if refresh {
                    proteins.removeAll { $0.category == category }
                }
                proteins.append(contentsOf: allProteins)
                categoryPages[category] = currentPage + 1
                
                // hasMore 로직 개선: 실제 받은 데이터 개수와 요청한 개수 비교
                let actuallyReceived = newProteins.count
                let hasMoreData = actuallyReceived >= limit
                categoryHasMore[category] = hasMoreData
                
                // 추가 검증: 전체 개수와 비교
                let totalCount = categoryTotalCounts[category] ?? 0
                let currentTotal = proteins.filter { $0.category == category }.count
                if totalCount > 0 && currentTotal >= totalCount {
                    categoryHasMore[category] = false
                }
                
                loadedCategories.insert(category)
                
                print("📊 \(category.rawValue) 상태 업데이트:")
                print("   - 로드된 단백질: \(allProteins.count)개 (API 데이터만)")
                print("   - 수신된 데이터: \(actuallyReceived)개 (limit: \(limit))")
                print("   - hasMore: \(categoryHasMore[category] ?? false)")
                print("   - 전체 로드된 개수: \(currentTotal)/\(totalCount)")
            }
        } catch {
            print("❌ \(category.rawValue) API 실패: \(error.localizedDescription)")
            // 에러 발생 시 더 이상 로드하지 않도록 설정
            await MainActor.run {
                categoryHasMore[category] = false
            }
            throw error
        }
    }
    
    // 카테고리의 다음 페이지 로드 (Load More)
    func loadMoreProteins(for category: ProteinCategory) async {
        guard categoryHasMore[category] == true else {
            print("No more proteins available for \(category)")
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await loadCategoryPage(category: category, refresh: false)
        } catch {
            print("❌ \(category.rawValue) 추가 로딩 실패: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load more \(category.rawValue): \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // 모든 카테고리의 첫 페이지 로드 (수정됨: 필요할 때만 로딩)
    private func loadAllCategoriesWithPagination() async {
        print("🚀 초기 데이터 로딩 시작...")
        print("📊 샘플 데이터만 로드하여 빠른 시작")
        
        // 모든 카테고리 초기화
        for category in ProteinCategory.allCases {
            categoryPages[category] = 0
            categoryHasMore[category] = true
        }
        
        await MainActor.run {
            proteins.removeAll()
        }
        
        // 샘플 데이터만 로드하여 빠른 시작
        for category in ProteinCategory.allCases {
            print("🔄 \(category.rawValue) 샘플 데이터 로드...")
            let sampleProteins = apiService.getSampleProteins(for: category)
            await MainActor.run {
                proteins.append(contentsOf: sampleProteins)
                categoryPages[category] = 0 // 샘플 데이터는 페이지 0으로 설정
                categoryHasMore[category] = true // 실제 데이터가 더 있을 수 있음
                loadedCategories.insert(category)
            }
        }
        
        await MainActor.run {
            let totalProteins = proteins.count
            let loadedCategoriesCount = loadedCategories.count
            print("🎉 초기 샘플 데이터 로딩 완료!")
            print("📈 총 \(totalProteins)개 샘플 단백질이 \(loadedCategoriesCount)개 카테고리에서 로드됨")
            print("💡 실제 데이터는 카테고리 선택 시 로드됩니다")
        }
        
        // API에서 실제 카테고리별 총 개수 로드
        await loadAllCategoryCounts()
    }
    
    // 특정 카테고리에 더 로드할 수 있는지 확인 (개선된 로직)
    func hasMoreProteins(for category: ProteinCategory) -> Bool {
        let hasMoreFromState = categoryHasMore[category] ?? true // 기본값을 true로 설정
        let currentlyLoaded = proteins.filter { $0.category == category }.count
        let totalAvailable = categoryTotalCounts[category] ?? 0
        
        print("🔍 \(category.rawValue) hasMoreProteins 체크:")
        print("   - categoryHasMore[\(category.rawValue)]: \(hasMoreFromState)")
        print("   - 현재 로드된 개수: \(currentlyLoaded)")
        print("   - 전체 사용 가능: \(totalAvailable)")
        
        // 샘플 데이터만 있는 경우 (보통 3-6개): API에서 더 많은 데이터가 있을 가능성이 높음
        if currentlyLoaded <= 10 && totalAvailable > currentlyLoaded {
            print("   - 샘플 데이터 수준, API에서 더 로드 가능")
            return true
        }
        
        // 상태가 true이고, 현재 로드된 개수가 전체보다 적은 경우에만 true
        let result = hasMoreFromState && (totalAvailable == 0 || currentlyLoaded < totalAvailable)
        print("   - 최종 결과: \(result)")
        
        return result
    }
    
    // 모든 카테고리의 실제 API 총 개수 로드
    private func loadAllCategoryCounts() async {
        print("🔍 모든 카테고리 실제 API 개수 로딩 시작...")
        
        for category in ProteinCategory.allCases {
            do {
                let (_, totalCount) = try await apiService.searchProteinsByCategory(category: category, limit: 1)
                await MainActor.run {
                    categoryTotalCounts[category] = totalCount
                }
                print("✅ \(category.rawValue): 실제 \(totalCount)개 단백질 확인")
                
                // API 개수가 1 이하인 경우 fallback 검색 시도
                if totalCount <= 1 {
                    print("⚠️ \(category.rawValue) API 개수 부족, fallback 검색 시도...")
                    let (_, fallbackCount) = try await apiService.searchWithFallback(category: category, limit: 1)
                    if fallbackCount > totalCount {
                        await MainActor.run {
                            categoryTotalCounts[category] = fallbackCount
                        }
                        print("✅ \(category.rawValue): fallback으로 \(fallbackCount)개 단백질 확인")
                    }
                }
            } catch {
                print("❌ \(category.rawValue) API 개수 로딩 실패: \(error.localizedDescription)")
                // 실패 시 샘플 데이터 개수 사용
                let sampleCount = apiService.getSampleProteins(for: category).count
                await MainActor.run {
                    categoryTotalCounts[category] = sampleCount
                }
            }
        }
        
        await MainActor.run {
            print("🎉 모든 카테고리 개수 로드 완료!")
            for (category, count) in categoryTotalCounts {
                print("📊 \(category.rawValue): \(count)개")
            }
        }
    }
    
    // 개별 카테고리의 실제 API 데이터 로드 (전체 카테고리 보기에서 사용)
    func loadCategoryProteins(category: ProteinCategory) async {
        print("🔄 \(category.rawValue) 카테고리 실제 API 데이터 로드 시작...")
        
        do {
            // 기존 샘플 데이터 제거
            await MainActor.run {
                proteins.removeAll { $0.category == category }
            }
            
            // 첫 페이지 API 데이터 로드
            try await loadCategoryPage(category: category, refresh: true)
            print("✅ \(category.rawValue) 카테고리 API 데이터 로드 완료")
        } catch {
            print("❌ \(category.rawValue) 카테고리 API 로드 실패: \(error.localizedDescription)")
            // 실패 시 샘플 데이터라도 다시 로드
            let sampleProteins = apiService.getSampleProteins(for: category)
            await MainActor.run {
                proteins.append(contentsOf: sampleProteins)
            }
        }
    }

    
    // 백업용 샘플 데이터
    private func loadSampleProteins() {
        proteins = [
            // Enzymes (효소)
            ProteinInfo(
                id: "1LYZ",
                name: "Lysozyme",
                category: .enzymes,
                description: "항균 작용을 하는 효소, 눈물과 침에 존재",
                keywords: ["항균", "효소", "lysozyme", "antibacterial", "tears"]
            ),
            ProteinInfo(
                id: "1CAT",
                name: "Catalase",
                category: .enzymes,
                description: "과산화수소를 분해하는 항산화 효소",
                keywords: ["catalase", "antioxidant", "항산화", "효소"]
            ),
            ProteinInfo(
                id: "1TIM",
                name: "Triose Phosphate Isomerase",
                category: .enzymes,
                description: "당분해 과정의 핵심 효소",
                keywords: ["glycolysis", "당분해", "metabolism", "대사"]
            ),
            ProteinInfo(
                id: "1HRP",
                name: "Horseradish Peroxidase",
                category: .enzymes,
                description: "식물의 과산화효소, 실험에 널리 사용",
                keywords: ["peroxidase", "과산화효소", "plant", "식물"]
            ),
            ProteinInfo(
                id: "1TRX",
                name: "Thioredoxin",
                category: .enzymes,
                description: "세포 산화환원 조절 효소",
                keywords: ["redox", "산화환원", "cellular", "세포"]
            ),
            ProteinInfo(
                id: "1RNT",
                name: "Ribonuclease T1",
                category: .enzymes,
                description: "RNA를 분해하는 효소",
                keywords: ["ribonuclease", "RNA", "분해", "효소"]
            ),
            
            // Structural (구조 단백질)
            ProteinInfo(
                id: "1CGD",
                name: "Collagen",
                category: .structural,
                description: "피부, 뼈, 연골의 주요 구조 단백질",
                keywords: ["collagen", "콜라겐", "피부", "뼈", "구조"]
            ),
            ProteinInfo(
                id: "1AO6",
                name: "Keratin",
                category: .structural,
                description: "머리카락, 손톱의 구성 단백질",
                keywords: ["keratin", "케라틴", "머리카락", "손톱"]
            ),
            ProteinInfo(
                id: "1ELA",
                name: "Elastin",
                category: .structural,
                description: "혈관과 피부의 탄성 단백질",
                keywords: ["elastin", "엘라스틴", "탄성", "혈관", "피부"]
            ),
            ProteinInfo(
                id: "1FBN",
                name: "Fibronectin",
                category: .structural,
                description: "세포외 기질의 구조 단백질",
                keywords: ["fibronectin", "파이브로넥틴", "기질", "세포외"]
            ),
            ProteinInfo(
                id: "1ACT",
                name: "Actin",
                category: .structural,
                description: "세포골격의 주요 구성 단백질",
                keywords: ["actin", "액틴", "세포골격", "cytoskeleton"]
            ),
            ProteinInfo(
                id: "1TUB",
                name: "Tubulin",
                category: .structural,
                description: "미세소관을 구성하는 단백질",
                keywords: ["tubulin", "튜불린", "미세소관", "microtubule"]
            ),
            
            // Defense (방어 단백질)
            ProteinInfo(
                id: "1IGY",
                name: "Immunoglobulin",
                category: .defense,
                description: "항체, 면역 반응의 핵심 단백질",
                keywords: ["antibody", "항체", "면역", "immunoglobulin"]
            ),
            ProteinInfo(
                id: "1A0O",
                name: "Complement C3",
                category: .defense,
                description: "보체 시스템의 중심 단백질",
                keywords: ["complement", "보체", "면역", "defense"]
            ),
            ProteinInfo(
                id: "1LYS",
                name: "Lysozyme C",
                category: .defense,
                description: "세균 세포벽을 파괴하는 방어 단백질",
                keywords: ["lysozyme", "라이소자임", "항균", "세포벽"]
            ),
            ProteinInfo(
                id: "1DEF",
                name: "Defensin",
                category: .defense,
                description: "선천 면역의 항균 펩타이드",
                keywords: ["defensin", "디펜신", "항균", "펩타이드"]
            ),
            ProteinInfo(
                id: "1LAC",
                name: "Lactoferrin",
                category: .defense,
                description: "철분 결합 항균 단백질",
                keywords: ["lactoferrin", "락토페린", "철분", "항균"]
            ),
            
            // Transport (수송 단백질)
            ProteinInfo(
                id: "1HHB",
                name: "Hemoglobin",
                category: .transport,
                description: "적혈구의 산소 운반 단백질",
                keywords: ["hemoglobin", "헤모글로빈", "산소", "적혈구", "blood"]
            ),
            ProteinInfo(
                id: "1MYG",
                name: "Myoglobin",
                category: .transport,
                description: "근육의 산소 저장 단백질",
                keywords: ["myoglobin", "미오글로빈", "근육", "산소"]
            ),
            ProteinInfo(
                id: "1H15",
                name: "Transferrin",
                category: .transport,
                description: "철분을 운반하는 단백질",
                keywords: ["transferrin", "트랜스페린", "철분", "iron"]
            ),
            
            // Hormones (호르몬)
            ProteinInfo(
                id: "1ZNJ",
                name: "Insulin",
                category: .hormones,
                description: "혈당 조절 호르몬",
                keywords: ["insulin", "인슐린", "혈당", "당뇨병", "hormone"]
            ),
            ProteinInfo(
                id: "1HCG",
                name: "Growth Hormone",
                category: .hormones,
                description: "성장을 촉진하는 호르몬",
                keywords: ["growth", "성장", "hormone", "호르몬"]
            ),
            
            // Storage (저장 단백질)
            ProteinInfo(
                id: "1ALC",
                name: "Albumin",
                category: .storage,
                description: "혈장의 주요 단백질, 영양소 운반",
                keywords: ["albumin", "알부민", "혈장", "영양소"]
            ),
            ProteinInfo(
                id: "1CRN",
                name: "Crambin",
                category: .storage,
                description: "식물 종자의 저장 단백질",
                keywords: ["crambin", "storage", "저장", "seed", "식물"]
            )
        ]
    }
    
    func searchProteins(_ query: String) -> [ProteinInfo] {
        if query.isEmpty {
            return proteins
        }
        
        let lowercasedQuery = query.lowercased()
        return proteins.filter { protein in
            protein.name.lowercased().contains(lowercasedQuery) ||
            protein.id.lowercased().contains(lowercasedQuery) ||
            protein.description.lowercased().contains(lowercasedQuery) ||
            protein.keywords.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    func proteinsByCategory(_ category: ProteinCategory) -> [ProteinInfo] {
        proteins.filter { $0.category == category }
    }
    
    func toggleFavorite(_ proteinId: String) {
        if favorites.contains(proteinId) {
            favorites.remove(proteinId)
        } else {
            favorites.insert(proteinId)
        }
    }
}

// MARK: - Protein Library View

struct ProteinLibraryView: View {
    @StateObject private var database = ProteinDatabase()
    @State private var searchText = ""
    @State private var selectedCategory: ProteinCategory? = nil
    @State private var showingFavoritesOnly = false
    @State private var currentPage = 1
    @State private var isLoadingMore = false
    @State private var showingLoadingPopup = false
    @State private var customSearchTerms: [String] = []
    @State private var showingCustomSearchSheet = false
    @State private var showingInfoSheet = false
    @State private var selectedProtein: ProteinInfo? = nil
    @Environment(\.dismiss) private var dismiss
    
    let onProteinSelected: (String) -> Void
    
    private let itemsPerPage = 30
    
    var allFilteredProteins: [ProteinInfo] {
        var result = database.proteins
        print("📊 전체 단백질 수: \(result.count)")
        
        // 검색어 필터링
        if !searchText.isEmpty {
            result = result.filter { protein in
                protein.name.localizedCaseInsensitiveContains(searchText) ||
                protein.description.localizedCaseInsensitiveContains(searchText) ||
                protein.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
            print("🔍 검색어 '\(searchText)' 필터링 후: \(result.count)개")
        }
        
        // 카테고리 필터링
        if let category = selectedCategory {
            let beforeCount = result.count
            result = result.filter { $0.category == category }
            print("📊 카테고리 '\(category.rawValue)' 필터링: \(beforeCount)개 -> \(result.count)개")
            
            // 카테고리별 세부 데이터 확인
            let categoryProteins = database.proteins.filter { $0.category == category }
            print("📊 데이터베이스에서 \(category.rawValue) 카테고리: \(categoryProteins.count)개")
            if categoryProteins.count <= 3 {
                print("📊 \(category.rawValue) 세부: \(categoryProteins.map { $0.name })")
            }
        }
        
        // 즐겨찾기 필터링
        if showingFavoritesOnly {
            let beforeCount = result.count
            result = result.filter { database.favorites.contains($0.id) }
            print("🔍 즐겨찾기 필터링: \(beforeCount)개 -> \(result.count)개")
        }
        
        print("✅ 최종 필터링 결과: \(result.count)개 단백질")
        return result
    }
    
    var displayedProteins: [ProteinInfo] {
        // 카테고리별 보기에서는 모든 로드된 데이터를 표시 (API 페이지네이션 사용)
        if selectedCategory != nil {
            print("📺 카테고리별 보기: 모든 로드된 데이터 표시 (\(allFilteredProteins.count)개)")
            return allFilteredProteins
        }
        
        // 전체 카테고리 보기에서만 로컬 페이지네이션 적용
        let totalItems = min(currentPage * itemsPerPage, allFilteredProteins.count)
        print("📺 전체 카테고리 보기: \(totalItems)/\(allFilteredProteins.count)개 표시")
        return Array(allFilteredProteins.prefix(totalItems))
    }
    
    var proteinsByCategory: [ProteinCategory: [ProteinInfo]] {
        Dictionary(grouping: allFilteredProteins) { $0.category }
    }
    
    var allProteinsByCategory: [ProteinCategory: [ProteinInfo]] {
        let grouped = Dictionary(grouping: database.proteins) { $0.category }
        print("📊 카테고리별 단백질 분류: \(grouped.mapValues { $0.count })")
        return grouped
    }
    
    var categoryProteinCounts: [ProteinCategory: Int] {
        var counts: [ProteinCategory: Int] = [:]
        for category in ProteinCategory.allCases {
            // API에서 가져온 총 개수 우선 사용, 없으면 로드된 데이터 개수 사용
            let apiCount = database.categoryTotalCounts[category] ?? 0
            let loadedCount = allProteinsByCategory[category]?.count ?? 0
            counts[category] = apiCount > 0 ? apiCount : loadedCount
            
            // 디버깅을 위한 상세 로깅
            if apiCount > 0 {
                print("📊 \(category.rawValue): API 개수 \(apiCount)개 사용")
            } else {
                print("📊 \(category.rawValue): 샘플 개수 \(loadedCount)개 사용 (API 개수: \(apiCount))")
            }
        }
        print("📈 카테고리별 단백질 개수 (API 우선): \(counts)")
        return counts
    }
    
    var sortedCategories: [ProteinCategory] {
        ProteinCategory.allCases.filter { category in
            proteinsByCategory[category]?.isEmpty == false
        }
    }
    
    var hasMoreData: Bool {
        print("🔍 hasMoreData 체크 시작...")
        
        // 카테고리가 선택된 경우: API에서 더 가져올 수 있는지 확인
        if let selectedCategory = selectedCategory {
            let hasMore = database.hasMoreProteins(for: selectedCategory)
            let currentCount = displayedProteins.count
            let totalCount = categoryProteinCounts[selectedCategory] ?? 0
            let loadedCount = database.proteins.filter { $0.category == selectedCategory }.count
            
            print("📊 \(selectedCategory.rawValue) 카테고리:")
            print("   - 현재 표시: \(currentCount)개")
            print("   - 로드된 데이터: \(loadedCount)개")
            print("   - 전체 개수: \(totalCount)개")
            print("   - API hasMore: \(hasMore)")
            
            // 로드된 데이터가 샘플 데이터만 있거나, API에서 더 가져올 수 있는 경우
            let shouldShowLoadMore = hasMore || (loadedCount <= 10 && totalCount > loadedCount)
            print("   - Load More 버튼 표시: \(shouldShowLoadMore)")
            
            return shouldShowLoadMore
        }
        
        // 전체 카테고리 보기 시: 샘플 데이터만 있는 카테고리가 있는지 확인
        var hasSampleDataCategories = false
        for category in ProteinCategory.allCases {
            let currentCategoryProteins = database.proteins.filter { $0.category == category }.count
            let totalAvailable = categoryProteinCounts[category] ?? 0
            
            // 샘플 데이터만 있고 API에 더 많은 데이터가 있는 카테고리
            if currentCategoryProteins <= 10 && totalAvailable > currentCategoryProteins {
                hasSampleDataCategories = true
                break
            }
        }
        
        print("📊 전체 카테고리 보기: 샘플 데이터만 있는 카테고리 \(hasSampleDataCategories)")
        return hasSampleDataCategories
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search proteins...", text: $searchText)
                            .textFieldStyle(.plain)
                            .onChange(of: searchText) { _ in
                                resetPagination()
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(10)
                    
                    // 데이터 가져오기 버튼
                    Button(action: {
                        Task {
                            await refreshCategoryCounts()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("데이터 가져오기")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemBlue).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Category Filter Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Categories")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // All Categories Button (명확한 필터 버튼임을 표시)
                        CategoryChip(
                            title: "All Categories",
                            icon: "grid.circle", 
                            color: .blue,
                            isSelected: selectedCategory == nil
                        ) {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = nil
                                resetPagination()
                            }
                        }
                        
                        // Category Chips
                        ForEach(ProteinCategory.allCases) { category in
                            CategoryChip(
                                title: category.rawValue,
                                icon: category.icon,
                                color: category.color,
                                isSelected: selectedCategory == category
                            ) {
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedCategory == category {
                                        selectedCategory = nil
                                    } else {
                                        selectedCategory = category
                                        resetPagination()
                                    }
                                }
                            }
                        }
                        
                        // Favorites
                        CategoryChip(
                            title: "♥︎",
                            icon: "heart.fill",
                            color: .pink,
                            isSelected: showingFavoritesOnly
                        ) {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3)) {
                                showingFavoritesOnly.toggle()
                            }
                        }
                        
                        // Custom Search Terms
                        CategoryChip(
                            title: "🔍+",
                            icon: "plus.magnifyingglass",
                            color: .orange,
                            isSelected: !customSearchTerms.isEmpty
                        ) {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3)) {
                                showingCustomSearchSheet = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    }
                }
                
                // Results Count
                HStack {
                    if selectedCategory == nil {
                        // All Categories 화면: 전체 카테고리 합계 표시
                        let totalCount = categoryProteinCounts.values.reduce(0, +)
                        Text("Total: \(totalCount) proteins across all categories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        // 특정 카테고리 선택 시: 해당 카테고리의 API 총 개수 표시
                        let categoryTotal = categoryProteinCounts[selectedCategory!] ?? 0
                        Text("Showing \(displayedProteins.count) of \(categoryTotal) proteins")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // Main Content
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: []) {
                        if selectedCategory == nil {
                            // All Categories - 카테고리 선택 인터페이스
                            VStack(spacing: 20) {
                                // 헤더
                                VStack(spacing: 8) {
                                    Text("Choose a Category")
                                        .font(.title2)
                                        .modifier(ConditionalFontWeight(weight: .bold, fallbackFont: .title2))
                                        .foregroundColor(.primary)
                                    
                                    Text("Explore proteins by their biological function")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 20)
                                
                                // 카테고리 그리드
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 16) {
                                    ForEach(ProteinCategory.allCases) { category in
                                        CategorySelectionCard(
                                            category: category,
                                            proteinCount: categoryProteinCounts[category] ?? 0
                                        ) {
                                            // 카테고리 선택 시 해당 카테고리로 필터링
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                            impactFeedback.impactOccurred()
                                            
                                            withAnimation(.spring(response: 0.3)) {
                                                selectedCategory = category
                                                resetPagination()
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // Single Category - 단일 카테고리 리스트
                            VStack(spacing: 16) {
                                // 선택된 카테고리 헤더
                                SelectedCategoryHeader(
                                    category: selectedCategory!,
                                    proteinCount: allFilteredProteins.count
                                ) {
                                    // 뒤로 가기
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedCategory = nil
                                    }
                                }
                                
                                // 단백질 리스트
                                ForEach(displayedProteins) { protein in
                                    ProteinRowCard(
                                        protein: protein,
                                        isFavorite: database.favorites.contains(protein.id),
                                        onSelect: {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                            impactFeedback.impactOccurred()
                                            
                                            // 자연스러운 로딩 흐름: 먼저 로딩 화면 표시
                                            selectedProtein = nil
                                            showingInfoSheet = true
                                            
                                            // 짧은 지연 후 데이터 설정 (로딩 효과)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                selectedProtein = protein
                                            }
                                        },
                                        onFavoriteToggle: {
                                            database.toggleFavorite(protein.id)
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                    )
                                }
                                
                                // Load More Button
                                if hasMoreData {
                                    LoadMoreButton(isLoading: isLoadingMore) {
                                        loadMoreProteins()
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Protein Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if #available(iOS 16.0, *) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationViewStyle(.stack) // iPhone에서 더 나은 UX
        .onChange(of: searchText) { _ in resetPagination() }
        .onChange(of: selectedCategory) { newCategory in 
            resetPagination()
            print("Category changed to: \(newCategory?.rawValue ?? "All")")
            Task {
                await database.loadProteins(for: newCategory)
                print("Loaded proteins count: \(database.proteins.count)")
            }
        }
        .onChange(of: showingFavoritesOnly) { _ in resetPagination() }
        .task {
            // 초기 로딩 - 모든 카테고리의 데이터를 가져와서 개수 표시
            if database.proteins.isEmpty {
                print("🚀 Protein Library 초기 데이터 로딩 시작...")
                await database.loadProteins()
                print("✅ 초기 로딩 완료: \(database.proteins.count)개 단백질")
            }
            
            // API 카운트가 로드될 때까지 대기 (최대 5초)
            var waitCount = 0
            while database.categoryTotalCounts.isEmpty && waitCount < 50 {
                _ = try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
                waitCount += 1
            }
            
            // 여전히 API 카운트가 없으면 직접 로드
            if database.categoryTotalCounts.isEmpty {
                print("🔍 모든 카테고리의 실제 개수 직접 로드 시작...")
                await loadAllCategoryCounts()
            } else {
                print("📊 캐시된 API 카운트 사용: \(database.categoryTotalCounts.count)개 카테고리")
            }
            
            // 샘플 데이터가 로드될 때까지 대기
            while database.proteins.isEmpty && !database.isLoading {
                _ = try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            }
        }
        .overlay {
            if showingLoadingPopup || database.isLoading {
                LoadingPopup()
            }
        }
        .sheet(isPresented: $showingCustomSearchSheet) {
            CustomSearchTermsSheet(
                customSearchTerms: $customSearchTerms,
                selectedCategory: selectedCategory
            )
        }
        .sheet(isPresented: $showingInfoSheet) {
            if let protein = selectedProtein {
                InfoSheet(
                    protein: protein,
                    onProteinSelected: onProteinSelected
                )
            } else {
                // 로딩 상태 표시
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.blue)
                    
                    VStack(spacing: 4) {
                        Text("단백질 정보 로드 중...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("잠시만 기다려주세요")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onAppear {
                    // 로딩 타임아웃 처리 (3초 후 시트 닫기)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if selectedProtein == nil {
                            showingInfoSheet = false
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(database.errorMessage != nil)) {
            Button("Retry") {
                Task {
                    await database.loadProteins(refresh: true)
                }
            }
            Button("OK") {
                database.errorMessage = nil
            }
        } message: {
            Text(database.errorMessage ?? "")
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadMoreProteins() {
        guard !isLoadingMore else { 
            print("⚠️ LoadMore 이미 진행 중, 요청 무시")
            return 
        }
        
        print("🔄 LoadMore 버튼 클릭 시작")
        isLoadingMore = true
        
        Task {
            if let selectedCategory = selectedCategory {
                // 카테고리가 선택된 경우: API에서 더 많은 데이터 로드
                print("🔄 \(selectedCategory.rawValue) 카테고리의 추가 데이터 로딩...")
                
                // 현재 상태 정보 출력
                let currentCount = displayedProteins.count
                let totalCount = categoryProteinCounts[selectedCategory] ?? 0
                let hasMore = database.hasMoreProteins(for: selectedCategory)
                
                print("📊 현재 상태 - 표시: \(currentCount), 전체: \(totalCount), hasMore: \(hasMore)")
                
                if hasMore {
                    await database.loadMoreProteins(for: selectedCategory)
                    print("✅ \(selectedCategory.rawValue) 추가 로딩 완료")
                } else {
                    print("⚠️ \(selectedCategory.rawValue) 더 이상 로드할 데이터 없음")
                }
            } else {
                // 전체 카테고리 보기 시: 실제 API에서 더 많은 데이터 로딩
                print("🔄 전체 카테고리 Load More: API에서 추가 데이터 로딩...")
                
                // 현재 샘플 데이터만 있는 카테고리들을 찾아서 실제 API 데이터로 대체
                for category in ProteinCategory.allCases {
                    let currentCategoryProteins = database.proteins.filter { $0.category == category }
                    
                    // 샘플 데이터만 있는 카테고리라면 (6개 이하) 실제 API 데이터 로드
                    if currentCategoryProteins.count <= 10 {
                        print("🔄 \(category.rawValue) 카테고리: 샘플 데이터(\(currentCategoryProteins.count)개)를 실제 API 데이터로 교체")
                        await database.loadCategoryProteins(category: category)
                    }
                }
                
                print("✅ 전체 카테고리 API 데이터 로딩 완료")
            }
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4)) {
                    isLoadingMore = false
                }
                
                // 합틱 피드백
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                print("✅ LoadMore 완료, isLoadingMore = false")
            }
        }
    }
    
    private func resetPagination() {
        withAnimation(.spring(response: 0.3)) {
            currentPage = 1
            isLoadingMore = false
            showingLoadingPopup = false
        }
    }
    
    // 카테고리 카운트 새로고침
    private func refreshCategoryCounts() async {
        await MainActor.run {
            showingLoadingPopup = true
        }
        
        print("🔄 카테고리 카운트 새로고침 시작...")
        await loadAllCategoryCounts()
        
        await MainActor.run {
            showingLoadingPopup = false
        }
    }
    
    // 모든 카테고리의 실제 개수를 미리 로드
    private func loadAllCategoryCounts() async {
        print("🔄 모든 카테고리 개수 로드 시작...")
        
        for category in ProteinCategory.allCases {
            do {
                // 각 카테고리에서 실제 API 데이터 개수 확인 (빠른 검색)
                let (_, totalCount) = try await database.apiService.searchProteinsByCategory(category: category, limit: 100)
                
                await MainActor.run {
                    database.categoryTotalCounts[category] = totalCount
                    print("✅ \(category.rawValue): 실제 \(totalCount)개 단백질 확인")
                }
                
                // API 부하 방지를 위한 짧은 지연
                _ = try? await Task.sleep(nanoseconds: 200_000_000) // 0.2초
                
            } catch {
                print("❌ \(category.rawValue) 개수 확인 실패: \(error.localizedDescription)")
                // 실패 시 샘플 데이터 개수 사용
                let sampleCount = database.apiService.getSampleProteins(for: category).count
                await MainActor.run {
                    database.categoryTotalCounts[category] = sampleCount
                }
            }
        }
        
        await MainActor.run {
            print("🎉 모든 카테고리 개수 로드 완료!")
            for (category, count) in database.categoryTotalCounts {
                print("📊 \(category.rawValue): \(count)개")
            }
        }
    }
}

// MARK: - Supporting Views

struct CustomSearchTermsSheet: View {
    @Binding var customSearchTerms: [String]
    let selectedCategory: ProteinCategory?
    @Environment(\.dismiss) private var dismiss
    @State private var newTerm = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 헤더
                VStack(spacing: 8) {
                    Text("Custom Search Terms")
                        .font(.title2)
                        .modifier(ConditionalFontWeight(weight: .bold, fallbackFont: .title2))
                        .foregroundColor(.primary)
                    
                    if let category = selectedCategory {
                        Text("Add search terms for \(category.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Add search terms for all categories")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // 검색어 입력
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Search Term")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Enter protein name or keyword...", text: $newTerm)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            addSearchTerm()
                        }
                        .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 20)
                
                // 현재 검색어 목록
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Search Terms")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if customSearchTerms.isEmpty {
                        Text("No custom search terms added yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(customSearchTerms, id: \.self) { term in
                                    HStack {
                                        Text(term)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            removeSearchTerm(term)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Custom Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .modifier(ConditionalFontWeight(weight: .semibold, fallbackFont: .headline))
                }
            }
        }
    }
    
    private func addSearchTerm() {
        let trimmedTerm = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { return }
        
        if !customSearchTerms.contains(trimmedTerm) {
            customSearchTerms.append(trimmedTerm)
            newTerm = ""
        }
    }
    
    private func removeSearchTerm(_ term: String) {
        customSearchTerms.removeAll { $0 == term }
    }
}

struct CategorySelectionCard: View {
    let category: ProteinCategory
    let proteinCount: Int
    let onSelect: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(category.color)
                }
                
                // 카테고리 정보
                VStack(spacing: 4) {
                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("\(proteinCount) proteins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .onAppear {
                            print("📊 \(category.rawValue) 카테고리: \(proteinCount)개 단백질")
                        }
                }
                
                // 설명
                Text(category.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(category.color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: { })
    }
}

struct SelectedCategoryHeader: View {
    let category: ProteinCategory
    let proteinCount: Int
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // 뒤로 가기 + 카테고리 정보
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Categories")
                    }
                    .font(.body)
                    .foregroundColor(category.color)
                }
                
                Spacer()
            }
            
            // 카테고리 헤더
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.title)
                    .foregroundColor(category.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.title2)
                        .modifier(ConditionalFontWeight(weight: .bold, fallbackFont: .title2))
                        .foregroundColor(.primary)
                    
                    Text("\(proteinCount) proteins found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(category.color.opacity(0.1))
            .cornerRadius(12)
            
            // 카테고리 설명
            Text(category.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 4)
        }
    }
}

struct CategorySection: View {
    let category: ProteinCategory
    let proteins: [ProteinInfo]
    let database: ProteinDatabase
    let onProteinSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(category.color)
                    
                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("(\(proteins.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("See All") {
                    // 해당 카테고리로 필터링 (부모 뷰에서 처리 필요)
                }
                .font(.caption)
                .foregroundColor(category.color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(category.color.opacity(0.1))
            .cornerRadius(8)
            
            // Proteins in this category
            ForEach(proteins) { protein in
                ProteinRowCard(
                    protein: protein,
                    isFavorite: database.favorites.contains(protein.id),
                    onSelect: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        withAnimation(.spring(response: 0.3)) {
                            onProteinSelected(protein.id)
                        }
                    },
                    onFavoriteToggle: {
                        database.toggleFavorite(protein.id)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                )
            }
        }
    }
}

struct LoadingPopup: View {
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Loading card
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                Text("Loading proteins...")
                    .modifier(ConditionalFontWeight(weight: .medium, fallbackFont: .body))
                    .foregroundColor(.primary)
                
                Text("Please wait")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: true)
    }
}

struct LoadMoreButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.blue)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Text(isLoading ? "Loading..." : "Load More")
                    .modifier(ConditionalFontWeight(weight: .medium, fallbackFont: .body))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemFill))
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .onTapGesture {
            // 단순한 탭 애니메이션
            withAnimation(.easeInOut(duration: 0.08)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.08)) {
                    isPressed = false
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .modifier(ConditionalFontWeight(weight: .medium, fallbackFont: .caption))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? .white : color)
            .background(isSelected ? color : Color(.secondarySystemFill))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0) // 단순화된 스케일 효과
        .animation(.easeInOut(duration: 0.15), value: isSelected) // 단일 애니메이션만 유지
    }
}

struct ProteinRowCard: View {
    let protein: ProteinInfo
    let isFavorite: Bool
    let onSelect: () -> Void
    let onFavoriteToggle: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Optimized Preview (No 3D rendering)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    protein.category.color.opacity(0.2),
                                    protein.category.color.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    // 3D Protein Structure Preview (개선된 버전)
                    ProteinStructurePreview(proteinId: protein.id)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(protein.category.color.opacity(0.3), lineWidth: 1)
                )
                
                // Protein Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(protein.id.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(protein.category.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(protein.category.color.opacity(0.1))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Button(action: onFavoriteToggle) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .pink : .secondary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(protein.name)
                        .modifier(ConditionalFontWeight(weight: .semibold, fallbackFont: .headline))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(protein.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Label(protein.category.rawValue, systemImage: protein.dynamicIcon)
                            .font(.caption2)
                            .foregroundColor(protein.dynamicColor)
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: { })
    }
}

// MARK: - iOS Version Compatibility

struct ConditionalFontWeight: ViewModifier {
    let weight: Font.Weight
    let fallbackFont: Font
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.fontWeight(weight)
        } else {
            content.font(fallbackFont)
        }
    }
}


