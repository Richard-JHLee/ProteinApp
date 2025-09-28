import Foundation

// MARK: - PubMed API Models

struct PubMedSearchResponse: Codable {
    let esearchresult: PubMedESearchResult?
}

// MARK: - Research Detail Models

struct ResearchPublication: Codable, Identifiable {
    let id = UUID()
    let pmid: String
    let title: String
    let authors: [String]
    let journal: String
    let year: String
    let abstract: String?
    let doi: String?
    
    enum CodingKeys: String, CodingKey {
        case pmid
        case title
        case authors
        case journal
        case year
        case abstract
        case doi
    }
}

struct ClinicalTrial: Codable, Identifiable {
    let id = UUID()
    let nctId: String
    let title: String
    let status: String
    let phase: String?
    let condition: String
    let intervention: String
    let sponsor: String
    let location: String
    
    enum CodingKeys: String, CodingKey {
        case nctId
        case title
        case status
        case phase
        case condition
        case intervention
        case sponsor
        case location
    }
}

struct ActiveStudy: Codable, Identifiable {
    let id = UUID()
    let title: String
    let type: String
    let status: String
    let institution: String
    let year: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case type
        case status
        case institution
        case year
        case description
    }
}

// MARK: - Research Detail Service

class ResearchDetailService {
    static let shared = ResearchDetailService()
    
    private init() {}
    
    // 실제 API에서 상세 데이터를 가져오는 함수들
    func fetchPublications(for proteinId: String) async throws -> [ResearchPublication] {
        // 실제 PubMed API에서 상세 정보를 가져오기
        return try await fetchRealPublications(for: proteinId)
    }
    
    func fetchClinicalTrials(for proteinId: String) async throws -> [ClinicalTrial] {
        // 실제로는 ClinicalTrials.gov API에서 상세 정보를 가져와야 함
        return try await generateSampleClinicalTrials(for: proteinId)
    }
    
    func fetchActiveStudies(for proteinId: String) async throws -> [ActiveStudy] {
        // 실제로는 다양한 연구 데이터베이스에서 정보를 가져와야 함
        return try await generateSampleActiveStudies(for: proteinId)
    }
    
    // 페이징 메서드들
    func fetchPublicationsPage(for proteinId: String, page: Int) async throws -> [ResearchPublication] {
        return try await fetchRealPublicationsPage(for: proteinId, page: page)
    }
    
    func fetchClinicalTrialsPage(for proteinId: String, page: Int) async throws -> [ClinicalTrial] {
        // Clinical Trials는 샘플 데이터이므로 빈 배열 반환
        return []
    }
    
    func fetchActiveStudiesPage(for proteinId: String, page: Int) async throws -> [ActiveStudy] {
        // Active Studies는 샘플 데이터이므로 빈 배열 반환
        return []
    }
    
    // 실제 PubMed API 호출
    private func fetchRealPublications(for proteinId: String) async throws -> [ResearchPublication] {
        print("🔍 Fetching real publications from PubMed for: \(proteinId)")
        
        // PDB ID를 UniProt ID로 동적 변환
        let uniprotId = try await resolveToUniProtId(proteinId)
        
        // 더 유연한 검색어 생성
        let searchTerms = try await generateSearchTerms(proteinId: proteinId, uniprotId: uniprotId)
        
        // 각 검색어로 시도해보기 (Rate Limit 고려)
        for (index, searchTerm) in searchTerms.enumerated() {
            print("🔍 Trying search term: \(searchTerm)")
            
            // 1단계: 검색하여 PMID 목록 가져오기
            guard let searchUrl = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&retmode=json&retmax=30") else {
                continue
            }
        
            do {
                let (searchData, response) = try await URLSession.shared.data(from: searchUrl)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ PubMed API error: Invalid response")
                    continue
                }
                
                if httpResponse.statusCode == 429 {
                    print("⚠️ Rate limit hit, waiting 3 seconds...")
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3초 대기
                    continue
                }
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ PubMed API error: HTTP \(httpResponse.statusCode)")
                    continue
                }
                
                let searchResult = try JSONDecoder().decode(PubMedSearchResponse.self, from: searchData)
                
                guard let pmids = searchResult.esearchresult?.idlist, !pmids.isEmpty else {
                    print("📚 No publications found for: \(searchTerm)")
                    continue // 다음 검색어 시도
                }
                
                print("📚 Found \(pmids.count) publications for: \(searchTerm)")
                
                // 2단계: PMID 목록으로 상세 정보 가져오기
                let pmidString = pmids.joined(separator: ",")
                guard let detailUrl = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=\(pmidString)&retmode=xml") else {
                    continue
                }
                
                let (detailData, _) = try await URLSession.shared.data(from: detailUrl)
                let detailXml = String(data: detailData, encoding: .utf8) ?? ""
                
                // XML 파싱하여 ResearchPublication 객체 생성
                let publications = parsePublicationsFromXML(detailXml)
                if !publications.isEmpty {
                    return publications
                }
            } catch {
                print("❌ PubMed API error for \(searchTerm): \(error)")
                continue
            }
            
            // API 호출 간 1초 대기 (Rate Limit 방지)
            if index < searchTerms.count - 1 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기
            }
        }
        
        // 모든 검색어로 실패한 경우 빈 배열 반환
        print("📚 No publications found with any search term")
        return []
    }
    
    // 페이징을 위한 PubMed API 호출
    private func fetchRealPublicationsPage(for proteinId: String, page: Int) async throws -> [ResearchPublication] {
        print("🔍 Fetching publications page \(page) from PubMed for: \(proteinId)")
        
        // PDB ID를 UniProt ID로 동적 변환
        let uniprotId = try await resolveToUniProtId(proteinId)
        
        // 더 유연한 검색어 생성
        let searchTerms = try await generateSearchTerms(proteinId: proteinId, uniprotId: uniprotId)
        
        // Research Status와 동일한 검색어로 페이징 시도
        for searchTerm in searchTerms {
            print("🔍 Trying search term for page \(page): \(searchTerm)")
            
            let startIndex = page * 30
            let retmax = 30
            
            // 1단계: 검색하여 PMID 목록 가져오기
            guard let searchUrl = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&retmode=json&retmax=\(retmax)&retstart=\(startIndex)") else {
                continue
            }
        
            let (searchData, _) = try await URLSession.shared.data(from: searchUrl)
            let searchResult = try JSONDecoder().decode(PubMedSearchResponse.self, from: searchData)
            
            guard let pmids = searchResult.esearchresult?.idlist, !pmids.isEmpty else {
                print("📚 No publications found for: \(searchTerm)")
                continue // 다음 검색어 시도
            }
            
            print("📚 Found \(pmids.count) publications for page \(page) with: \(searchTerm)")
            
            // 2단계: PMID 목록으로 상세 정보 가져오기
            let pmidString = pmids.joined(separator: ",")
            guard let detailUrl = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=\(pmidString)&retmode=xml") else {
                continue
            }
            
            let (detailData, _) = try await URLSession.shared.data(from: detailUrl)
            let detailXml = String(data: detailData, encoding: .utf8) ?? ""
            
            // XML 파싱하여 ResearchPublication 객체 생성
            let publications = parsePublicationsFromXML(detailXml)
            if !publications.isEmpty {
                return publications
            }
        }
        
        return []
    }
    
    // 단백질 ID 연관 검색어 우선 생성 (Rate Limit 고려)
    private func generateSearchTerms(proteinId: String, uniprotId: String) async throws -> [String] {
        var searchTerms: [String] = []
        
        // 1. 단백질 ID 직접 검색 (최우선)
        searchTerms.append(proteinId)
        searchTerms.append(uniprotId)
        
        // 2. 단백질 ID + 키워드 조합 (우선순위 2)
        let idBasedPatterns = [
            "\(proteinId) AND protein",
            "\(uniprotId) AND protein",
            "\(proteinId) AND structure",
            "\(uniprotId) AND structure",
            "\(proteinId) AND enzyme",
            "\(uniprotId) AND enzyme"
        ]
        searchTerms.append(contentsOf: idBasedPatterns)
        
        // 3. PDB에서 단백질 정보 가져와서 특화 검색어 생성 (우선순위 3)
        if let pdbInfo = try await getPDBInfo(proteinId) {
            // 단백질 제목 추가 (구체적)
            if let title = pdbInfo["title"] as? String, !title.isEmpty {
                searchTerms.append(title)
            }
            
            // 키워드들 추가 (단백질 특화)
            if let keywords = pdbInfo["keywords"] as? [String] {
                searchTerms.append(contentsOf: keywords.prefix(2))
            }
        }
        
        // 4. 단백질 ID + 일반 키워드 조합 (우선순위 4)
        let specificPatterns = [
            "\(proteinId) hydrolase",
            "\(uniprotId) hydrolase",
            "\(proteinId) crystal",
            "\(uniprotId) crystal"
        ]
        searchTerms.append(contentsOf: specificPatterns)
        
        // 중복 제거 및 빈 문자열 필터링, 최대 8개로 제한
        let uniqueTerms = Array(Set(searchTerms.filter { !$0.isEmpty }))
        return Array(uniqueTerms.prefix(8))
    }
    
    // PDB 정보 가져오기
    private func getPDBInfo(_ pdbId: String) async throws -> [String: Any]? {
        guard let url = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(pdbId)") else {
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        var result: [String: Any] = [:]
        
        // 구조 제목 추출
        if let structInfo = json?["struct"] as? [String: Any],
           let title = structInfo["title"] as? String {
            result["title"] = title
        }
        
        // 키워드 추출
        if let keywords = json?["struct_keywords"] as? [String: Any],
           let text = keywords["text"] as? String {
            let keywordArray = text.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            result["keywords"] = keywordArray
        }
        
        return result.isEmpty ? nil : result
    }
    
    // PDB ID를 UniProt ID로 동적 해결
    private func resolveToUniProtId(_ proteinId: String) async throws -> String {
        // 이미 UniProt ID 형식인지 확인 (P로 시작하고 6자리)
        if proteinId.hasPrefix("P") && proteinId.count == 6 {
            return proteinId
        }
        
        // 방법 1: PDB ID로 직접 검색
        if let uniprotId = try await searchByPDBId(proteinId) {
            print("🔍 Mapped \(proteinId) to UniProt ID via PDB search: \(uniprotId)")
            return uniprotId
        }
        
        // 방법 2: 단백질 이름으로 검색 (PDB에서 단백질 정보 가져오기)
        if let uniprotId = try await searchByProteinName(proteinId) {
            print("🔍 Mapped \(proteinId) to UniProt ID via protein name: \(uniprotId)")
            return uniprotId
        }
        
        // 방법 3: 알려진 매핑 사용
        let knownMappings: [String: String] = [
            "1BKV": "P02461", // Collagen alpha-1(III) chain
            "1CGD": "P02452", // Collagen alpha-1(I) chain  
            "1LYZ": "P00698", // Lysozyme C
            "4KPO": "B6T563", // Hemoglobin variant
            "6L90": "P59594"  // SARS-CoV-2 Spike protein
        ]
        
        if let mappedId = knownMappings[proteinId] {
            print("🔍 Mapped \(proteinId) to UniProt ID via known mapping: \(mappedId)")
            return mappedId
        }
        
        // 매핑 실패 시 원본 ID 반환
        print("⚠️ Could not map \(proteinId) to UniProt ID, using original")
        return proteinId
    }
    
    // PDB ID로 직접 검색
    private func searchByPDBId(_ pdbId: String) async throws -> String? {
        guard let url = URL(string: "https://rest.uniprot.org/uniprotkb/search?query=pdb_id:\(pdbId)&format=json&size=1") else {
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let results = json?["results"] as? [[String: Any]],
           let firstResult = results.first,
           let primaryAccession = firstResult["primaryAccession"] as? String {
            return primaryAccession
        }
        
        return nil
    }
    
    // 단백질 이름으로 검색
    private func searchByProteinName(_ pdbId: String) async throws -> String? {
        // PDB에서 단백질 정보 가져오기
        guard let pdbUrl = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(pdbId)") else {
            return nil
        }
        
        let (pdbData, _) = try await URLSession.shared.data(from: pdbUrl)
        let pdbJson = try JSONSerialization.jsonObject(with: pdbData) as? [String: Any]
        
        // 단백질 이름 추출
        var searchTerms: [String] = []
        
        if let structInfo = pdbJson?["struct"] as? [String: Any],
           let title = structInfo["title"] as? String {
            searchTerms.append(title)
        }
        
        if let keywords = pdbJson?["struct_keywords"] as? [String: Any],
           let text = keywords["text"] as? String {
            let keywordArray = text.components(separatedBy: ",")
            searchTerms.append(contentsOf: keywordArray.prefix(3))
        }
        
        // 각 검색어로 UniProt 검색
        for term in searchTerms {
            let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTerm.isEmpty {
                if let uniprotId = try await searchUniProtByTerm(cleanTerm) {
                    return uniprotId
                }
            }
        }
        
        return nil
    }
    
    // UniProt에서 용어로 검색
    private func searchUniProtByTerm(_ term: String) async throws -> String? {
        let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://rest.uniprot.org/uniprotkb/search?query=\(encodedTerm)&format=json&size=1&reviewed:true") else {
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let results = json?["results"] as? [[String: Any]],
           let firstResult = results.first,
           let primaryAccession = firstResult["primaryAccession"] as? String {
            return primaryAccession
        }
        
        return nil
    }
    
    // XML에서 Publication 정보 파싱
    private func parsePublicationsFromXML(_ xml: String) -> [ResearchPublication] {
        var publications: [ResearchPublication] = []
        
        // 간단한 XML 파싱 (실제로는 XMLParser를 사용하는 것이 좋음)
        let components = xml.components(separatedBy: "<PubmedArticle>")
        
        for component in components.dropFirst() {
            let article = component.components(separatedBy: "</PubmedArticle>").first ?? ""
            
            // PMID 추출
            let pmidMatch = article.range(of: "<PMID[^>]*>([^<]+)</PMID>", options: .regularExpression)
            let pmid = pmidMatch != nil ? String(article[pmidMatch!]).replacingOccurrences(of: "<PMID[^>]*>", with: "", options: .regularExpression).replacingOccurrences(of: "</PMID>", with: "") : ""
            
            // 제목 추출
            let titleMatch = article.range(of: "<ArticleTitle[^>]*>([^<]+)</ArticleTitle>", options: .regularExpression)
            let title = titleMatch != nil ? String(article[titleMatch!]).replacingOccurrences(of: "<ArticleTitle[^>]*>", with: "", options: .regularExpression).replacingOccurrences(of: "</ArticleTitle>", with: "") : ""
            
            // 저자 추출 (첫 번째 저자만)
            let authorMatch = article.range(of: "<LastName>([^<]+)</LastName>", options: .regularExpression)
            let author = authorMatch != nil ? String(article[authorMatch!]).replacingOccurrences(of: "<LastName>", with: "").replacingOccurrences(of: "</LastName>", with: "") : ""
            
            // 저널 추출
            let journalMatch = article.range(of: "<MedlineTA>([^<]+)</MedlineTA>", options: .regularExpression)
            let journal = journalMatch != nil ? String(article[journalMatch!]).replacingOccurrences(of: "<MedlineTA>", with: "", options: .regularExpression).replacingOccurrences(of: "</MedlineTA>", with: "") : ""
            
            // 연도 추출
            let yearMatch = article.range(of: "<Year>([^<]+)</Year>", options: .regularExpression)
            let year = yearMatch != nil ? String(article[yearMatch!]).replacingOccurrences(of: "<Year>", with: "").replacingOccurrences(of: "</Year>", with: "") : ""
            
            if !pmid.isEmpty && !title.isEmpty {
                publications.append(ResearchPublication(
                    pmid: pmid,
                    title: title,
                    authors: author.isEmpty ? ["Unknown"] : [author],
                    journal: journal.isEmpty ? "Unknown Journal" : journal,
                    year: year.isEmpty ? "Unknown" : year,
                    abstract: nil,
                    doi: nil
                ))
            }
        }
        
        return publications
    }
    
    // 샘플 데이터 생성 (실제 API 연동 전까지 사용)
    private func generateSamplePublications(for proteinId: String) async throws -> [ResearchPublication] {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5초 지연
        
        switch proteinId {
        case "1CGD":
            return [
                ResearchPublication(
                    pmid: "8980682",
                    title: "Crystallographic evidence for C alpha-H...O=C hydrogen bonds in a collagen triple helix",
                    authors: ["Bella J", "Berman HM"],
                    journal: "Journal of Molecular Biology",
                    year: "1996",
                    abstract: "The crystal structure of the collagen triple-helical peptide (Pro-Hyp-Gly)4-Pro-Hyp-Ala-(Pro-Hyp-Gly)5 shows evidence for the existence of interchain contacts between alpha-carbon hydrogens from Gly and Hyp residues, and carbonyl groups from Gly and Pro residues on neighboring chains.",
                    doi: "10.1006/jmbi.1996.0673"
                )
            ]
        case "1LYZ":
            return [
                ResearchPublication(
                    pmid: "12345678",
                    title: "Structure and function of lysozyme in bacterial cell wall degradation",
                    authors: ["Smith A", "Johnson B", "Williams C"],
                    journal: "Nature Structural Biology",
                    year: "2023",
                    abstract: "Lysozyme is an important antimicrobial enzyme that degrades bacterial cell walls by hydrolyzing the glycosidic bonds in peptidoglycan.",
                    doi: "10.1038/nsb.2023.123"
                ),
                ResearchPublication(
                    pmid: "87654321",
                    title: "Crystallographic analysis of lysozyme-substrate complex",
                    authors: ["Brown D", "Davis E"],
                    journal: "Science",
                    year: "2022",
                    abstract: "High-resolution crystal structure reveals the molecular mechanism of lysozyme catalysis.",
                    doi: "10.1126/science.abc.2022.456"
                )
            ]
        default:
            return []
        }
    }
    
    private func generateSampleClinicalTrials(for proteinId: String) async throws -> [ClinicalTrial] {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3초 지연
        
        switch proteinId {
        case "1LYZ":
            return [
                ClinicalTrial(
                    nctId: "NCT01234567",
                    title: "Lysozyme as a therapeutic agent for bacterial infections",
                    status: "Recruiting",
                    phase: "Phase II",
                    condition: "Bacterial Infections",
                    intervention: "Lysozyme Treatment",
                    sponsor: "University Hospital",
                    location: "United States"
                ),
                ClinicalTrial(
                    nctId: "NCT07654321",
                    title: "Safety and efficacy of lysozyme in pediatric patients",
                    status: "Active",
                    phase: "Phase I",
                    condition: "Pediatric Bacterial Infections",
                    intervention: "Lysozyme Oral Administration",
                    sponsor: "Children's Medical Center",
                    location: "Canada"
                )
            ]
        case "4KPO":
            return [
                ClinicalTrial(
                    nctId: "NCT09876543",
                    title: "Hemoglobin variants and sickle cell disease treatment",
                    status: "Completed",
                    phase: "Phase III",
                    condition: "Sickle Cell Disease",
                    intervention: "Hemoglobin Modification Therapy",
                    sponsor: "National Institutes of Health",
                    location: "United States"
                ),
                ClinicalTrial(
                    nctId: "NCT11223344",
                    title: "Blood transfusion optimization using hemoglobin analysis",
                    status: "Recruiting",
                    phase: "Phase II",
                    condition: "Blood Transfusion Complications",
                    intervention: "Hemoglobin Screening",
                    sponsor: "Blood Center Research",
                    location: "United Kingdom"
                )
            ]
        default:
            return []
        }
    }
    
    private func generateSampleActiveStudies(for proteinId: String) async throws -> [ActiveStudy] {
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4초 지연
        
        switch proteinId {
        case "1CGD":
            return [
                ActiveStudy(
                    title: "Collagen structure and disease mechanisms",
                    type: "Basic Research",
                    status: "Ongoing",
                    institution: "Rutgers University",
                    year: "2024",
                    description: "Investigating the molecular mechanisms of collagen-related diseases through structural analysis."
                )
            ]
        case "1LYZ":
            return [
                ActiveStudy(
                    title: "Lysozyme engineering for enhanced antimicrobial activity",
                    type: "Applied Research",
                    status: "Ongoing",
                    institution: "MIT",
                    year: "2024",
                    description: "Protein engineering approaches to improve lysozyme's antimicrobial properties."
                ),
                ActiveStudy(
                    title: "Lysozyme in food preservation applications",
                    type: "Applied Research",
                    status: "Planning",
                    institution: "Food Research Institute",
                    year: "2024",
                    description: "Exploring lysozyme as a natural preservative in food industry applications."
                )
            ]
        default:
            return []
        }
    }
}
