import SwiftUI

struct PrimaryStructureView: View {
    let protein: ProteinInfo
    @State private var aminoAcidSequences: [String] = []
    @State private var isLoadingSequence = false
    @State private var sequenceError: String? = nil
    @State private var proteinDetails: ProteinDetails? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingSequence {
                        aminoAcidLoadingView
                    } else if let error = sequenceError {
                        aminoAcidErrorView(error)
                    } else {
                        aminoAcidContentView
                    }
                }
                .padding()
            }
            .navigationTitle("Primary Structure")
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
            loadAminoAcidSequence()
            loadProteinDetails()
        }
    }
    
    // MARK: - Loading View
    private var aminoAcidLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading amino acid sequence...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func aminoAcidErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to load sequence")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadAminoAcidSequence()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Content View
    private var aminoAcidContentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("Primary Structure")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 단백질 상세 정보
            if let details = proteinDetails {
                VStack(alignment: .leading, spacing: 16) {
                    // 잔기 수 정보
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Residue Count")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(Array(details.chains.enumerated()), id: \.offset) { index, chain in
                            HStack {
                                Text("Chain \(chain.chainId):")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(chain.residueCount) residues")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // 원본 유전자 출처
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gene Source / Organism")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(details.organism)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            if let gene = details.gene {
                                Text("Gene: \(gene)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // 호스트 발현 시스템
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expression Host")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text(details.expressionHost)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // PDB 해상도
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PDB Resolution")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(details.resolution) Å")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // 단백질 종류/기능
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Protein Family / Function")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text(details.proteinFamily)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // UniProt / CATH 분류
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UniProt / CATH Classification")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let uniprot = details.uniprotAccession {
                                Text("UniProt: \(uniprot)")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            
                            if let cath = details.cathClassification {
                                Text("CATH: \(cath)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            
            // 아미노산 서열 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("Amino Acid Sequences")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                if !aminoAcidSequences.isEmpty {
                    Text("\(aminoAcidSequences.count) chain(s) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 아미노산 서열 표시
            if !aminoAcidSequences.isEmpty {
                ForEach(Array(aminoAcidSequences.enumerated()), id: \.offset) { index, sequence in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Chain \(String(UnicodeScalar(65 + index)!))")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(protein.category.color)
                            
                            Spacer()
                            
                            Text("\(sequence.count) residues")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 서열을 80자씩 나누어 표시
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(0..<(sequence.count / 80 + 1), id: \.self) { lineIndex in
                                let startIndex = lineIndex * 80
                                let endIndex = min(startIndex + 80, sequence.count)
                                let line = String(sequence[sequence.index(sequence.startIndex, offsetBy: startIndex)..<sequence.index(sequence.startIndex, offsetBy: endIndex)])
                                
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No amino acid sequence available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadAminoAcidSequence() {
        isLoadingSequence = true
        sequenceError = nil
        
        Task {
            do {
                // 실제 API 호출
                let sequences = try await fetchAminoAcidSequence(pdbId: protein.id)
                
                await MainActor.run {
                    if sequences.isEmpty {
                        sequenceError = "No amino acid sequence found for this protein"
                    } else {
                        aminoAcidSequences = sequences
                    }
                    isLoadingSequence = false
                }
            } catch {
                await MainActor.run {
                    sequenceError = "Failed to load sequence: \(error.localizedDescription)"
                    isLoadingSequence = false
                }
            }
        }
    }
    
    // MARK: - API Function
    private func fetchAminoAcidSequence(pdbId: String) async throws -> [String] {
        // PDB 파일에서 직접 체인별 서열 추출
        let pdbUrl = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
        let (pdbData, _) = try await URLSession.shared.data(from: pdbUrl)
        let pdbContent = String(data: pdbData, encoding: .utf8) ?? ""
        
        return parseSequencesFromPDB(pdbContent: pdbContent)
    }
    
    private func parseSequencesFromPDB(pdbContent: String) -> [String] {
        var chainResidues: [String: [(Int, String)]] = [:]
        let lines = pdbContent.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("ATOM") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 6 {
                    let chainId = components[4]
                    let residueNumber = Int(components[5]) ?? 0
                    let residueName = components[3]
                    
                    // 아미노산 3글자 코드를 1글자 코드로 변환
                    let oneLetterCode = convertThreeLetterToOneLetter(residueName)
                    
                    if chainResidues[chainId] == nil {
                        chainResidues[chainId] = []
                    }
                    chainResidues[chainId]?.append((residueNumber, oneLetterCode))
                }
            }
        }
        
        // 체인별로 잔기 번호 순으로 정렬하고 중복 제거
        var sequences: [String] = []
        
        // 체인 ID 순으로 정렬
        let sortedChains = chainResidues.keys.sorted()
        
        for chainId in sortedChains {
            guard let residues = chainResidues[chainId] else { continue }
            
            // 잔기 번호로 정렬
            let sortedResidues = residues.sorted { $0.0 < $1.0 }
            
            // 중복 잔기 번호 제거 (같은 잔기 번호의 다른 원자는 제외)
            var uniqueResidues: [(Int, String)] = []
            var lastResidueNumber = -1
            
            for (residueNumber, oneLetterCode) in sortedResidues {
                if residueNumber != lastResidueNumber {
                    uniqueResidues.append((residueNumber, oneLetterCode))
                    lastResidueNumber = residueNumber
                }
            }
            
            // 서열 생성
            let sequence = uniqueResidues.map { $0.1 }.joined()
            sequences.append(sequence)
        }
        
        return sequences
    }
    
    private func convertThreeLetterToOneLetter(_ threeLetter: String) -> String {
        let conversionMap: [String: String] = [
            "ALA": "A", "ARG": "R", "ASN": "N", "ASP": "D", "CYS": "C",
            "GLN": "Q", "GLU": "E", "GLY": "G", "HIS": "H", "ILE": "I",
            "LEU": "L", "LYS": "K", "MET": "M", "PHE": "F", "PRO": "P",
            "SER": "S", "THR": "T", "TRP": "W", "TYR": "Y", "VAL": "V"
        ]
        return conversionMap[threeLetter] ?? "X"
    }
    
    // MARK: - Protein Details Loading
    private func loadProteinDetails() {
        Task {
            do {
                let details = try await fetchProteinDetails(pdbId: protein.id)
                await MainActor.run {
                    self.proteinDetails = details
                }
            } catch {
                print("Failed to load protein details: \(error)")
            }
        }
    }
    
    private func fetchProteinDetails(pdbId: String) async throws -> ProteinDetails {
        // PDB REST API에서 상세 정보 가져오기
        let entryUrl = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(pdbId.uppercased())")!
        let (entryData, _) = try await URLSession.shared.data(from: entryUrl)
        let entryResponse = try JSONDecoder().decode(EntryDetailsResponse.self, from: entryData)
        
        // PDB 파일에서 직접 체인 정보 파싱
        let pdbUrl = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
        let (pdbData, _) = try await URLSession.shared.data(from: pdbUrl)
        let pdbContent = String(data: pdbData, encoding: .utf8) ?? ""
        
        let chains = parseChainsFromPDB(pdbContent: pdbContent)
        
        // UniProt 정보 가져오기
        var uniprotAccession: String? = nil
        let cathClassification: String? = nil
        if let uniprotIds = entryResponse.rcsb_entry_container_identifiers?.polymer_entity_ids {
            for entityId in uniprotIds {
                let entityUrl = URL(string: "https://data.rcsb.org/rest/v1/core/polymer_entity/\(pdbId.uppercased())/\(entityId)")!
                let (entityData, _) = try await URLSession.shared.data(from: entityUrl)
                let entityResponse = try JSONDecoder().decode(PolymerEntityDetailsResponse.self, from: entityData)
                
                if let uniprotId = entityResponse.rcsb_polymer_entity?.rcsb_polymer_entity_container_identifiers?.uniprot_accession?.first {
                    uniprotAccession = uniprotId
                    break
                }
            }
        }
        
        return ProteinDetails(
            chains: chains,
            organism: entryResponse.`struct`?.pdbx_descriptor ?? "Unknown organism",
            gene: entryResponse.`struct`?.pdbx_gene_src_scientific_name ?? nil,
            expressionHost: entryResponse.`struct`?.pdbx_host_org_scientific_name ?? "Unknown host",
            resolution: entryResponse.refine?.first?.ls_d_res_high ?? 0.0,
            proteinFamily: entryResponse.`struct`?.pdbx_descriptor ?? "Unknown protein family",
            uniprotAccession: uniprotAccession,
            cathClassification: cathClassification
        )
    }
    
    private func parseChainsFromPDB(pdbContent: String) -> [ChainInfo] {
        var chainResidueCounts: [String: Set<Int>] = [:]
        let lines = pdbContent.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("ATOM") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 6 {
                    let chainId = components[4]
                    if let residueNumber = Int(components[5]) {
                        if chainResidueCounts[chainId] == nil {
                            chainResidueCounts[chainId] = Set<Int>()
                        }
                        chainResidueCounts[chainId]?.insert(residueNumber)
                    }
                }
            }
        }
        
        return chainResidueCounts.map { chainId, residueNumbers in
            ChainInfo(chainId: chainId, residueCount: residueNumbers.count)
        }.sorted { $0.chainId < $1.chainId }
    }
}

// MARK: - Data Models
struct ProteinDetails {
    let chains: [ChainInfo]
    let organism: String
    let gene: String?
    let expressionHost: String
    let resolution: Double
    let proteinFamily: String
    let uniprotAccession: String?
    let cathClassification: String?
}

struct ChainInfo {
    let chainId: String
    let residueCount: Int
}

struct EntryDetailsResponse: Codable {
    let rcsb_entry_container_identifiers: EntryContainerIdentifiers?
    let `struct`: StructInfo?
    let struct_keywords: StructKeywords?
    let rcsb_entry_info: RcsbEntryInfo?
    let refine: [RefineInfo]?
}

struct StructInfo: Codable {
    let pdbx_descriptor: String?
    let pdbx_gene_src_scientific_name: String?
    let pdbx_host_org_scientific_name: String?
    let title: String?
}

struct StructKeywords: Codable {
    let pdbx_keywords: String?
}

struct RcsbEntryInfo: Codable {
    let deposited_atom_count: Int?
}

struct RefineInfo: Codable {
    let ls_d_res_high: Double?
}

struct PolymerEntityDetailsResponse: Decodable {
    let entity_poly: EntityPoly?
    let rcsb_polymer_entity: RcsbPolymerEntity?
}

struct RcsbPolymerEntity: Codable {
    let rcsb_polymer_entity_container_identifiers: PolymerEntityContainerIdentifiers?
}

struct PolymerEntityContainerIdentifiers: Codable {
    let auth_asym_ids: [String]?
    let uniprot_accession: [String]?
}
