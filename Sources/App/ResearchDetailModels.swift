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
    
    // 실제 PubMed API 호출
    private func fetchRealPublications(for proteinId: String) async throws -> [ResearchPublication] {
        print("🔍 Fetching real publications from PubMed for: \(proteinId)")
        
        // PDB ID를 UniProt ID로 변환
        let uniprotId = mapPDBToUniProt(proteinId)
        let searchTerm = uniprotId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // 1단계: 검색하여 PMID 목록 가져오기
        guard let searchUrl = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=\(searchTerm)&retmode=json&retmax=20") else {
            throw NSError(domain: "PubMedError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (searchData, _) = try await URLSession.shared.data(from: searchUrl)
        let searchResult = try JSONDecoder().decode(PubMedSearchResponse.self, from: searchData)
        
        guard let pmids = searchResult.esearchresult?.idlist, !pmids.isEmpty else {
            print("📚 No publications found for \(proteinId)")
            return []
        }
        
        print("📚 Found \(pmids.count) publications for \(proteinId)")
        
        // 2단계: PMID 목록으로 상세 정보 가져오기
        let pmidString = pmids.joined(separator: ",")
        guard let detailUrl = URL(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=\(pmidString)&retmode=xml") else {
            throw NSError(domain: "PubMedError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid detail URL"])
        }
        
        let (detailData, _) = try await URLSession.shared.data(from: detailUrl)
        let detailXml = String(data: detailData, encoding: .utf8) ?? ""
        
        // XML 파싱하여 ResearchPublication 객체 생성
        return parsePublicationsFromXML(detailXml)
    }
    
    // PDB ID를 UniProt ID로 매핑하는 함수
    private func mapPDBToUniProt(_ pdbId: String) -> String {
        let mapping: [String: String] = [
            "1CGD": "P02452",
            "1LYZ": "P00698",
            "4KPO": "B6T563",
            "6L90": "P59594"
        ]
        return mapping[pdbId] ?? pdbId
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
