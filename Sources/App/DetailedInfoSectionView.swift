import SwiftUI

struct DetailedInfoSectionView: View {
    let protein: ProteinInfo
    @State private var showingRelatedProteins = false
    @State private var experimentalDetails: ExperimentalDetails? = nil
    @State private var isLoadingDetails = false

    var body: some View {
        VStack(spacing: 16) {
            // 동적 Additional Information
            InfoCard(icon: "info.circle",
                     title: "Additional Information",
                     tint: .gray) {
                VStack(spacing: 12) {
                    if isLoadingDetails {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading experimental details...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if let details = experimentalDetails {
                        // API에서 가져온 동적 데이터 표시
                        if let method = details.experimentalMethod {
                            infoRow(title: "Structure Type", value: method, icon: "cube.box")
                        }
                        if let resolution = details.resolution {
                            infoRow(title: "Resolution", value: "\(resolution) Å", icon: "scope")
                        }
                        if let organism = details.organism {
                            infoRow(title: "Organism", value: organism, icon: "person")
                        }
                        if let expression = details.expression {
                            infoRow(title: "Expression", value: expression, icon: "leaf")
                        }
                        if let journal = details.journal {
                            infoRow(title: "Journal", value: journal, icon: "book")
                        }
                    } else {
                        // 기본 데이터 (API 실패 시)
                        infoRow(title: "Structure Type", value: "X-ray Crystallography", icon: "cube.box")
                        infoRow(title: "Resolution", value: "2.5 Å", icon: "scope")
                        infoRow(title: "Organism", value: "Homo sapiens", icon: "person")
                        infoRow(title: "Expression", value: "E. coli", icon: "leaf")
                    }
                    
                    Button(action: {
                        print("🔍 Additional Information View Details 버튼이 탭되었습니다!")
                        showingRelatedProteins = true
                    }) {
                        HStack {
                            Text("View Details")
                                .font(.caption.weight(.medium))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            
            // 1,2,3,4 단계 구조 정보는 기존 기능에서 처리됨
        }
        .onAppear {
            loadExperimentalDetails()
        }
        .sheet(isPresented: $showingRelatedProteins) {
            RelatedProteinsView(protein: protein)
        }
    }

    // MARK: - API 호출 함수
    private func loadExperimentalDetails() {
        guard experimentalDetails == nil else { return } // 이미 로드된 경우 중복 호출 방지
        
        isLoadingDetails = true
        
        Task {
            do {
                let details = try await fetchExperimentalDetails(pdbId: protein.id)
                await MainActor.run {
                    self.experimentalDetails = details
                    self.isLoadingDetails = false
                }
            } catch {
                print("❌ Experimental details 로드 실패: \(error)")
                await MainActor.run {
                    self.isLoadingDetails = false
                }
            }
        }
    }
    
    // MARK: - API 호출 함수
    private func fetchExperimentalDetails(pdbId: String) async throws -> ExperimentalDetails {
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
        
        let body = [
            "query": query,
            "variables": ["ids": [pdbId.uppercased()]]
        ] as [String: Any]
        
        guard let url = URL(string: "https://data.rcsb.org/graphql") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.httpError
        }
        
        let graphQLResponse = try JSONDecoder().decode(ExperimentalDetailsResponse.self, from: data)
        
        guard let entry = graphQLResponse.data.entries.first else {
            throw APIError.noData
        }
        
        return ExperimentalDetails(
            experimentalMethod: entry.exptl?.first?.method ?? entry.rcsb_entry_info?.experimental_method,
            resolution: entry.rcsb_entry_info?.resolution_combined?.first,
            organism: extractOrganism(from: entry.`struct`?.title),
            expression: "E. coli", // 기본값 (추후 API에서 가져올 수 있음)
            journal: entry.rcsb_primary_citation?.journal_abbrev
        )
    }
    
    private func extractOrganism(from title: String?) -> String? {
        guard let title = title else { return nil }
        
        // 제목에서 생물체 정보 추출 (간단한 패턴 매칭)
        if title.contains("HUMAN") || title.contains("Homo sapiens") {
            return "Homo sapiens"
        } else if title.contains("MOUSE") || title.contains("Mus musculus") {
            return "Mus musculus"
        } else if title.contains("BOVINE") || title.contains("Bos taurus") {
            return "Bos taurus"
        } else if title.contains("CHICKEN") || title.contains("Gallus gallus") {
            return "Gallus gallus"
        } else if title.contains("RAT") || title.contains("Rattus norvegicus") {
            return "Rattus norvegicus"
        }
        
        return nil
    }

    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(protein.category.color)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(value)
                .font(.subheadline)
                .modifier(ConditionalFontWeight(weight: .medium, fallbackFont: .subheadline))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
}

// MARK: - 데이터 모델들
struct ExperimentalDetails {
    let experimentalMethod: String?
    let resolution: Double?
    let organism: String?
    let expression: String?
    let journal: String?
}

struct ExperimentalDetailsResponse: Codable {
    let data: ExperimentalDetailsData
}

struct ExperimentalDetailsData: Codable {
    let entries: [ExperimentalDetailsEntry]
}

struct ExperimentalDetailsEntry: Codable {
    let rcsb_id: String
    let `struct`: ExperimentalDetailsStruct?
    let exptl: [ExperimentalDetailsExptl]?
    let rcsb_entry_info: ExperimentalDetailsEntryInfo?
    let rcsb_primary_citation: ExperimentalDetailsCitation?
    let struct_keywords: ExperimentalDetailsKeywords?
}

struct ExperimentalDetailsStruct: Codable {
    let title: String?
    let pdbx_descriptor: String?
}

struct ExperimentalDetailsExptl: Codable {
    let method: String?
}

struct ExperimentalDetailsEntryInfo: Codable {
    let resolution_combined: [Double]?
    let experimental_method: String?
}

struct ExperimentalDetailsCitation: Codable {
    let title: String?
    let journal_abbrev: String?
}

struct ExperimentalDetailsKeywords: Codable {
    let pdbx_keywords: String?
}

enum APIError: Error {
    case invalidURL
    case httpError
    case noData
}