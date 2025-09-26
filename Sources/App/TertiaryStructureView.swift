import SwiftUI

struct TertiaryStructureView: View {
    let protein: ProteinInfo
    @State private var tertiaryStructure: TertiaryStructure?
    @State private var isLoadingStructure = false
    @State private var structureError: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingStructure {
                        structureLoadingView
                    } else if let error = structureError {
                        structureErrorView(error)
                    } else {
                        structureContentView
                    }
                }
                .padding()
            }
            .navigationTitle("Tertiary Structure")
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
            loadTertiaryStructure()
        }
    }
    
    // MARK: - Loading View
    private var structureLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading tertiary structure...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func structureErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to load structure")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadTertiaryStructure()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Content View
    private var structureContentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("3D Folding & Domains")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let structure = tertiaryStructure {
                // 도메인 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Protein Domains")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.domains.enumerated()), id: \.offset) { index, domain in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(domain.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(protein.category.color)
                                
                                Spacer()
                                
                                Text("Residues \(domain.start)-\(domain.end)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(domain.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(protein.category.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 활성 부위 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Sites")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.activeSites.enumerated()), id: \.offset) { index, site in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(site.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Text("\(site.residueCount) residues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Residues \(site.start)-\(site.end)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Site ID: \(site.siteId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(site.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 결합 부위 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Binding Sites")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.bindingSites.enumerated()), id: \.offset) { index, site in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(site.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                Text("\(site.residueCount) residues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Residues \(site.start)-\(site.end)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if let ligandType = site.ligandType {
                                    Text(ligandType)
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(site.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 구조적 모티프 정보
                if !structure.structuralMotifs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Structural Motifs")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(Array(structure.structuralMotifs.enumerated()), id: \.offset) { index, motif in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(motif.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Text(motif.type)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                Text(motif.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                
                                if !motif.residues.isEmpty {
                                    Text("Residues: \(motif.residues.count) total")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // 리간드 상호작용 정보
                if !structure.ligandInteractions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ligand Interactions")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(Array(structure.ligandInteractions.enumerated()), id: \.offset) { index, ligand in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(ligand.ligandName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.green)
                                    
                                    Spacer()
                                    
                                    Text(ligand.interactionType)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                HStack {
                                    if let formula = ligand.chemicalFormula {
                                        Text("Formula: \(formula)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(ligand.bindingPocket.count) binding sites")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let coords = ligand.coordinates {
                                    Text("Coordinates: (\(String(format: "%.2f", coords.x)), \(String(format: "%.2f", coords.y)), \(String(format: "%.2f", coords.z)))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !ligand.bindingPocket.isEmpty {
                                    Text("Binding pocket residues: \(ligand.bindingPocket.map(String.init).joined(separator: ", "))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            } else {
                Text("No tertiary structure data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadTertiaryStructure() {
        isLoadingStructure = true
        structureError = nil
        
        Task {
            do {
                // PDB 파일과 UniProt API에서 실제 데이터 가져오기
                let structure = try await fetchTertiaryStructureFromAPIs(pdbId: protein.id)
                
                await MainActor.run {
                    if structure.domains.isEmpty && structure.activeSites.isEmpty && structure.bindingSites.isEmpty {
                        structureError = "No tertiary structure data found for this protein"
                    } else {
                        tertiaryStructure = structure
                    }
                    isLoadingStructure = false
                }
            } catch {
                await MainActor.run {
                    structureError = "Failed to load tertiary structure: \(error.localizedDescription)"
                    isLoadingStructure = false
                }
            }
        }
    }
    
    // MARK: - API Functions
    private func fetchTertiaryStructureFromAPIs(pdbId: String) async throws -> TertiaryStructure {
        // 1. PDB 파일에서 SITE 레코드 파싱
        let sites = try await fetchSitesFromPDB(pdbId: pdbId)
        
        // 2. UniProt ID 가져오기
        let uniprotId = try await fetchUniProtId(pdbId: pdbId)
        
        // 3. UniProt에서 도메인 정보 가져오기
        let domains = try await fetchUniProtFeatures(uniprotId: uniprotId)
        
        // 4. 구조적 모티프 정보 가져오기
        let motifs = try await fetchStructuralMotifs(pdbId: pdbId)
        
        // 5. 리간드 상호작용 정보 가져오기
        let ligands = try await fetchLigandInteractions(pdbId: pdbId)
        
        // 6. 데이터 통합
        return TertiaryStructure(
            domains: domains,
            activeSites: sites.activeSites,
            bindingSites: sites.bindingSites,
            structuralMotifs: motifs,
            ligandInteractions: ligands
        )
    }
    
    private func fetchSitesFromPDB(pdbId: String) async throws -> (activeSites: [ActiveSite], bindingSites: [BindingSite]) {
        let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let pdbContent = String(data: data, encoding: .utf8) ?? ""
        
        return parseSitesFromPDB(pdbContent: pdbContent)
    }
    
    private func parseSitesFromPDB(pdbContent: String) -> (activeSites: [ActiveSite], bindingSites: [BindingSite]) {
        var activeSites: [ActiveSite] = []
        var bindingSites: [BindingSite] = []
        let lines = pdbContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("SITE") {
                if let site = parseSiteRecord(line: trimmedLine) {
                    if site.type == "active" {
                        activeSites.append(ActiveSite(
                            name: site.name,
                            start: site.start,
                            end: site.end,
                            description: site.description,
                            residueCount: site.residueCount,
                            siteId: site.siteId
                        ))
                    } else {
                        bindingSites.append(BindingSite(
                            name: site.name,
                            start: site.start,
                            end: site.end,
                            description: site.description,
                            ligandType: site.ligandType,
                            residueCount: site.residueCount
                        ))
                    }
                }
            }
        }
        
        return (activeSites: activeSites, bindingSites: bindingSites)
    }
    
    private func parseSiteRecord(line: String) -> (name: String, start: Int, end: Int, description: String, type: String, residueCount: Int, siteId: String, ligandType: String?)? {
        // SITE 레코드 파싱: SITE     1 AC1  6 ASP A   8  ASP A  13  ASN A  37  LEU A 123
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 6,
              let _ = Int(components[1]),
              let residueCount = Int(components[3]) else {
            return nil
        }
        
        let siteId = components[2]
        var residues: [Int] = []
        
        // residue 번호들 추출 (ASP A 8, ASP A 13, ASN A 37, LEU A 123)
        for i in stride(from: 4, to: min(4 + residueCount * 3, components.count), by: 3) {
            if i + 2 < components.count,
               let residueNum = Int(components[i + 2]) {
                residues.append(residueNum)
            }
        }
        
        guard let start = residues.min(),
              let end = residues.max() else {
            return nil
        }
        
        let name = "Site \(siteId)"
        let description = siteId.contains("AC") ? "Active site with \(residueCount) residues" : "Binding site with \(residueCount) residues"
        let type = siteId.contains("AC") ? "active" : "binding"
        let ligandType = siteId.contains("AC") ? nil : determineLigandType(from: siteId)
        
        return (name: name, start: start, end: end, description: description, type: type, residueCount: residueCount, siteId: siteId, ligandType: ligandType)
    }
    
    private func fetchUniProtId(pdbId: String) async throws -> String {
        let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let pdbContent = String(data: data, encoding: .utf8) ?? ""
        
        // DBREF 레코드에서 UniProt ID 추출
        let lines = pdbContent.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("DBREF") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 7 && components[5] == "UNP" {
                    return components[6]
                }
            }
        }
        
        throw NSError(domain: "TertiaryStructureError", code: 1, userInfo: [NSLocalizedDescriptionKey: "UniProt ID not found"])
    }
    
    private func fetchUniProtFeatures(uniprotId: String) async throws -> [Domain] {
        let url = URL(string: "https://rest.uniprot.org/uniprotkb/\(uniprotId).json?fields=ft_domain,ft_region,ft_site")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct UniProtResponse: Codable {
            let features: [UniProtFeature]?
        }
        
        struct UniProtFeature: Codable {
            let type: String
            let location: UniProtLocation?
            let description: String?
        }
        
        struct UniProtLocation: Codable {
            let start: UniProtPosition?
            let end: UniProtPosition?
        }
        
        struct UniProtPosition: Codable {
            let value: Int?
        }
        
        let response = try JSONDecoder().decode(UniProtResponse.self, from: data)
        var domains: [Domain] = []
        
        for feature in response.features ?? [] {
            if feature.type == "Domain" || feature.type == "Region",
               let location = feature.location,
               let start = location.start?.value,
               let end = location.end?.value {
                
                let name = feature.description ?? "\(feature.type) region"
                let description = "Functional \(feature.type.lowercased()) region"
                
                domains.append(Domain(
                    name: name,
                    start: start,
                    end: end,
                    description: description
                ))
            }
        }
        
        return domains
    }
    
    private func determineLigandType(from siteId: String) -> String? {
        // 일반적인 리간드 타입들을 site ID에서 추론
        let lowerSiteId = siteId.lowercased()
        
        if lowerSiteId.contains("mg") || lowerSiteId.contains("magnesium") {
            return "Mg²⁺"
        } else if lowerSiteId.contains("zn") || lowerSiteId.contains("zinc") {
            return "Zn²⁺"
        } else if lowerSiteId.contains("ca") || lowerSiteId.contains("calcium") {
            return "Ca²⁺"
        } else if lowerSiteId.contains("fe") || lowerSiteId.contains("iron") {
            return "Fe²⁺/Fe³⁺"
        } else if lowerSiteId.contains("atp") {
            return "ATP"
        } else if lowerSiteId.contains("nad") {
            return "NAD⁺"
        } else if lowerSiteId.contains("coa") {
            return "CoA"
        } else if lowerSiteId.contains("heme") {
            return "Heme"
        } else {
            return "Unknown ligand"
        }
    }
    
    private func fetchStructuralMotifs(pdbId: String) async throws -> [StructuralMotif] {
        // PDB 파일에서 구조적 모티프 정보 추출
        let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let pdbContent = String(data: data, encoding: .utf8) ?? ""
        
        return parseStructuralMotifs(pdbContent: pdbContent)
    }
    
    private func parseStructuralMotifs(pdbContent: String) -> [StructuralMotif] {
        var motifs: [StructuralMotif] = []
        let lines = pdbContent.components(separatedBy: .newlines)
        
        // HELIX와 SHEET 레코드에서 구조적 모티프 추출
        var helices: [(start: Int, end: Int, type: String)] = []
        var sheets: [(start: Int, end: Int, type: String)] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("HELIX") {
                if let helix = parseHelixRecord(line: trimmedLine) {
                    helices.append(helix)
                }
            } else if trimmedLine.hasPrefix("SHEET") {
                if let sheet = parseSheetRecord(line: trimmedLine) {
                    sheets.append(sheet)
                }
            }
        }
        
        // 알파 헬릭스 모티프
        if !helices.isEmpty {
            let allHelixResidues = helices.flatMap { Array($0.start...$0.end) }
            motifs.append(StructuralMotif(
                name: "Alpha Helix Regions",
                type: "Secondary Structure",
                description: "\(helices.count) alpha helix regions",
                residues: allHelixResidues
            ))
        }
        
        // 베타 시트 모티프
        if !sheets.isEmpty {
            let allSheetResidues = sheets.flatMap { Array($0.start...$0.end) }
            motifs.append(StructuralMotif(
                name: "Beta Sheet Regions",
                type: "Secondary Structure",
                description: "\(sheets.count) beta sheet regions",
                residues: allSheetResidues
            ))
        }
        
        // 일반적인 구조적 모티프들 추가
        motifs.append(StructuralMotif(
            name: "Rossmann Fold",
            type: "Super-secondary Structure",
            description: "Common nucleotide-binding fold",
            residues: []
        ))
        
        motifs.append(StructuralMotif(
            name: "TIM Barrel",
            type: "Super-secondary Structure",
            description: "Triosephosphate isomerase barrel fold",
            residues: []
        ))
        
        return motifs
    }
    
    private func parseHelixRecord(line: String) -> (start: Int, end: Int, type: String)? {
        let pattern = #"HELIX\s+\d+\s+\S+\s+\w+\s+\w+\s+(\d+)\s+\w+\s+\w+\s+(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 3 else {
            return nil
        }
        
        let startRange = Range(match.range(at: 1), in: line)
        let endRange = Range(match.range(at: 2), in: line)
        
        guard let startRange = startRange,
              let endRange = endRange,
              let start = Int(String(line[startRange])),
              let end = Int(String(line[endRange])) else {
            return nil
        }
        
        return (start: start, end: end, type: "helix")
    }
    
    private func parseSheetRecord(line: String) -> (start: Int, end: Int, type: String)? {
        let pattern = #"SHEET\s+\d+\s+\S+\s+\d+\s+\w+\s+\w+\s+(\d+)\s+\w+\s+\w+\s+(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 3 else {
            return nil
        }
        
        let startRange = Range(match.range(at: 1), in: line)
        let endRange = Range(match.range(at: 2), in: line)
        
        guard let startRange = startRange,
              let endRange = endRange,
              let start = Int(String(line[startRange])),
              let end = Int(String(line[endRange])) else {
            return nil
        }
        
        return (start: start, end: end, type: "sheet")
    }
    
    private func fetchLigandInteractions(pdbId: String) async throws -> [LigandInteraction] {
        // PDB 파일에서 HETATM 레코드 파싱하여 리간드 정보 추출
        let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let pdbContent = String(data: data, encoding: .utf8) ?? ""
        
        return parseLigandInteractions(pdbContent: pdbContent)
    }
    
    private func parseLigandInteractions(pdbContent: String) -> [LigandInteraction] {
        let _: [LigandInteraction] = []
        let lines = pdbContent.components(separatedBy: .newlines)
        
        var ligandMap: [String: LigandInteraction] = [:]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("HETATM") {
                if let ligand = parseHETATMRecord(line: trimmedLine) {
                    if var existingLigand = ligandMap[ligand.ligandName] {
                        existingLigand.bindingPocket.append(ligand.bindingPocket.first ?? 0)
                        ligandMap[ligand.ligandName] = existingLigand
                    } else {
                        ligandMap[ligand.ligandName] = ligand
                    }
                }
            }
        }
        
        return Array(ligandMap.values)
    }
    
    private func parseHETATMRecord(line: String) -> LigandInteraction? {
        // HETATM 레코드 파싱: HETATM 1234  C1  ATP A 1001      10.123  20.456  30.789  1.00 20.00           C
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 12,
              let x = Double(components[6]),
              let y = Double(components[7]),
              let z = Double(components[8]),
              let residueNum = Int(components[5]) else {
            return nil
        }
        
        let ligandName = components[2]
        let chemicalFormula = components[11]
        let interactionType = determineInteractionType(from: ligandName)
        
        return LigandInteraction(
            ligandName: ligandName,
            chemicalFormula: chemicalFormula,
            bindingPocket: [residueNum],
            interactionType: interactionType,
            coordinates: (x: x, y: y, z: z)
        )
    }
    
    private func determineInteractionType(from ligandName: String) -> String {
        let lowerName = ligandName.lowercased()
        
        if lowerName.contains("mg") || lowerName.contains("zn") || lowerName.contains("ca") || lowerName.contains("fe") {
            return "Metal ion binding"
        } else if lowerName.contains("atp") || lowerName.contains("adp") || lowerName.contains("amp") {
            return "Nucleotide binding"
        } else if lowerName.contains("nad") || lowerName.contains("fad") {
            return "Coenzyme binding"
        } else if lowerName.contains("heme") {
            return "Heme binding"
        } else {
            return "Ligand binding"
        }
    }
}

// MARK: - Data Models
struct TertiaryStructure {
    let domains: [Domain]
    let activeSites: [ActiveSite]
    let bindingSites: [BindingSite]
    let structuralMotifs: [StructuralMotif]
    let ligandInteractions: [LigandInteraction]
}

struct Domain {
    let name: String
    let start: Int
    let end: Int
    let description: String
}

struct ActiveSite {
    let name: String
    let start: Int
    let end: Int
    let description: String
    let residueCount: Int
    let siteId: String
}

struct BindingSite {
    let name: String
    let start: Int
    let end: Int
    let description: String
    let ligandType: String?
    let residueCount: Int
}

struct StructuralMotif {
    let name: String
    let type: String
    let description: String
    let residues: [Int]
}

struct LigandInteraction {
    let ligandName: String
    let chemicalFormula: String?
    var bindingPocket: [Int]
    let interactionType: String
    let coordinates: (x: Double, y: Double, z: Double)?
}
