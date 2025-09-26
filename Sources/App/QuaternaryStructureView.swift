import SwiftUI

struct QuaternaryStructureView: View {
    let protein: ProteinInfo
    @State private var quaternaryStructure: QuaternaryStructure?
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
            .navigationTitle("Quaternary Structure")
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
            loadQuaternaryStructure()
        }
    }
    
    // MARK: - Loading View
    private var structureLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading quaternary structure...")
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
                loadQuaternaryStructure()
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
                Text("Subunit Assembly")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let structure = quaternaryStructure {
                // 서브유닛 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Protein Subunits")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.subunits.enumerated()), id: \.offset) { index, subunit in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Subunit \(subunit.id)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(protein.category.color)
                                
                                Spacer()
                                
                                Text("\(subunit.residueCount) residues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(subunit.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(protein.category.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 조립 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Assembly Information")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Assembly Type:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(structure.assembly.type)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Symmetry:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(structure.assembly.symmetry)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Oligomeric Count:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(structure.assembly.oligomericCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Polymer Composition:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(structure.assembly.polymerComposition)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Total Mass:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(String(format: "%.2f", structure.assembly.totalMass)) kDa")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Atom Count:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(structure.assembly.atomCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let methodDetails = structure.assembly.methodDetails {
                            HStack {
                                Text("Method:")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(methodDetails)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let isCandidate = structure.assembly.isCandidateAssembly {
                            HStack {
                                Text("Biological Assembly:")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(isCandidate ? "Yes" : "No")
                                    .font(.subheadline)
                                    .foregroundColor(isCandidate ? .green : .red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // 대칭성 세부 정보
                if !structure.assembly.symmetryDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Symmetry Details")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(Array(structure.assembly.symmetryDetails.enumerated()), id: \.offset) { index, symmetry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(symmetry.symbol) (\(symmetry.kind))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Text(symmetry.oligomericState)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if !symmetry.stoichiometry.isEmpty {
                                    Text("Stoichiometry: \(symmetry.stoichiometry.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let rmsd = symmetry.avgRmsd {
                                    Text("RMSD: \(String(format: "%.2f", rmsd)) Å")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // 생물학적 의미
                if let relevance = structure.assembly.biologicalRelevance {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Biological Relevance")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text(relevance)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // 상호작용 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Subunit Interactions")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.interactions.enumerated()), id: \.offset) { index, interaction in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(interaction.subunit1) ↔ \(interaction.subunit2)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                Text("\(interaction.contactCount) contacts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(interaction.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No quaternary structure data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadQuaternaryStructure() {
        isLoadingStructure = true
        structureError = nil
        
        Task {
            do {
                // PDB Assembly API와 PDB 파일에서 실제 데이터 가져오기
                let structure = try await fetchQuaternaryStructureFromAPIs(pdbId: protein.id)
                
                await MainActor.run {
                    if structure.subunits.isEmpty {
                        structureError = "No quaternary structure data found for this protein"
                    } else {
                        quaternaryStructure = structure
                    }
                    isLoadingStructure = false
                }
            } catch {
                await MainActor.run {
                    structureError = "Failed to load quaternary structure: \(error.localizedDescription)"
                    isLoadingStructure = false
                }
            }
        }
    }
    
    // MARK: - API Functions
    private func fetchQuaternaryStructureFromAPIs(pdbId: String) async throws -> QuaternaryStructure {
        // 1. RCSB Assembly API에서 정확한 Assembly 정보 가져오기
        let assemblyInfo = try await fetchAssemblyInfo(pdbId: pdbId)
        
        // 2. PDB 파일에서 서브유닛 정보 파싱
        let subunits = try await fetchSubunitsFromAssembly(pdbId: pdbId)
        
        // 3. RCSB Interface API에서 상호작용 정보 가져오기 (있는 경우)
        let interactions = try await fetchInterfaceInfo(pdbId: pdbId, assemblyId: assemblyInfo.assemblyId)
        
        return QuaternaryStructure(
            subunits: subunits,
            assembly: assemblyInfo,
            interactions: interactions
        )
    }
    
    private func fetchAssemblyInfo(pdbId: String) async throws -> Assembly {
        // Entry 정보에서 assembly ID 가져오기
        let entryUrl = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(pdbId.uppercased())")!
        let (entryData, _) = try await URLSession.shared.data(from: entryUrl)
        let entryResponse = try JSONDecoder().decode(EntryResponse.self, from: entryData)
        
        guard let assemblyIds = entryResponse.rcsb_entry_container_identifiers?.assembly_ids,
              let firstAssemblyId = assemblyIds.first else {
            throw NSError(domain: "AssemblyError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No assembly information found"])
        }
        
        // Assembly 상세 정보 가져오기
        let assemblyUrl = URL(string: "https://data.rcsb.org/rest/v1/core/assembly/\(pdbId.uppercased())/\(firstAssemblyId)")!
        let (assemblyData, _) = try await URLSession.shared.data(from: assemblyUrl)
        let assemblyResponse = try JSONDecoder().decode(AssemblyResponse.self, from: assemblyData)
        
        let assemblyInfo = assemblyResponse.rcsb_assembly_info
        let symmetry = assemblyResponse.rcsb_struct_symmetry?.first
        
        // 대칭성 세부 정보 파싱
        let symmetryDetails = assemblyResponse.rcsb_struct_symmetry?.map { sym in
            SymmetryDetail(
                symbol: sym.symbol ?? "Unknown",
                type: sym.type ?? "Unknown",
                stoichiometry: sym.stoichiometry ?? [],
                oligomericState: sym.oligomeric_state ?? "Unknown",
                kind: sym.kind ?? "Unknown",
                rotationAxes: sym.rotation_axes?.map { axis in
                    RotationAxis(
                        start: axis.start ?? [],
                        end: axis.end ?? [],
                        order: axis.order ?? 0
                    )
                },
                avgRmsd: sym.avg_rmsd
            )
        } ?? []
        
        // 생물학적 의미 파악
        let biologicalRelevance = determineBiologicalRelevance(
            assembly: assemblyResponse.pdbx_struct_assembly,
            symmetryDetails: symmetryDetails
        )
        
        return Assembly(
            type: assemblyResponse.pdbx_struct_assembly?.oligomeric_details ?? "Unknown",
            symmetry: symmetry?.symbol ?? "Unknown",
            totalMass: assemblyInfo?.molecular_weight ?? 0.0,
            oligomericCount: assemblyResponse.pdbx_struct_assembly?.oligomeric_count ?? 1,
            polymerComposition: assemblyInfo?.polymer_composition ?? "Unknown",
            atomCount: assemblyInfo?.atom_count ?? 0,
            assemblyId: firstAssemblyId,
            methodDetails: assemblyResponse.pdbx_struct_assembly?.method_details,
            isCandidateAssembly: assemblyResponse.pdbx_struct_assembly?.rcsb_candidate_assembly == "Y",
            symmetryDetails: symmetryDetails,
            biologicalRelevance: biologicalRelevance
        )
    }
    
    private func fetchInterfaceInfo(pdbId: String, assemblyId: String) async throws -> [Interaction] {
        do {
            let interfaceUrl = URL(string: "https://data.rcsb.org/rest/v1/core/interface/\(pdbId.uppercased())/\(assemblyId)")!
            let (interfaceData, _) = try await URLSession.shared.data(from: interfaceUrl)
            let interfaceResponse = try JSONDecoder().decode(InterfaceResponse.self, from: interfaceData)
            
            return interfaceResponse.rcsb_interface_info?.map { interface in
                Interaction(
                    subunit1: interface.rcsb_interface_partner?.first?.interface_partner_identifier?.asym_id ?? "Unknown",
                    subunit2: interface.rcsb_interface_partner?.last?.interface_partner_identifier?.asym_id ?? "Unknown",
                    contactCount: interface.rcsb_interface_partner?.count ?? 0,
                    description: "Interface between subunits"
                )
            } ?? []
        } catch {
            // Interface 정보가 없으면 빈 배열 반환
            return []
        }
    }
    
    
    private func fetchSubunitsFromAssembly(pdbId: String) async throws -> [Subunit] {
        // 먼저 일반 PDB 파일에서 체인 정보 가져오기 (더 안정적)
        let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let pdbContent = String(data: data, encoding: .utf8) ?? ""
        
        return parseSubunitsFromPDB(pdbContent: pdbContent)
    }
    
    private func parseSubunitsFromPDB(pdbContent: String) -> [Subunit] {
        var subunits: [String: Set<Int>] = [:]
        let lines = pdbContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("ATOM") {
                if let chainInfo = parseAtomRecord(line: trimmedLine) {
                    if subunits[chainInfo.chainId] == nil {
                        subunits[chainInfo.chainId] = Set<Int>()
                    }
                    subunits[chainInfo.chainId]?.insert(chainInfo.residueNumber)
                }
            }
        }
        
        return subunits.map { (chainId, residueNumbers) in
            Subunit(
                id: chainId,
                residueCount: residueNumbers.count,
                description: "Chain \(chainId) subunit"
            )
        }.sorted { $0.id < $1.id }
    }
    
    private func parseAtomRecord(line: String) -> (chainId: String, residueNumber: Int)? {
        // ATOM 레코드 파싱: ATOM      1  N   THR A   1      17.047  14.099   3.625  1.00 13.79           N
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 6,
              let residueNumber = Int(components[5]) else {
            return nil
        }
        
        let chainId = components[4]
        return (chainId: chainId, residueNumber: residueNumber)
    }
    
    private func determineBiologicalRelevance(assembly: PdbxStructAssembly?, symmetryDetails: [SymmetryDetail]) -> String {
        guard let assembly = assembly else { return "Unknown biological relevance" }
        
        var relevance = ""
        
        // PISA 방법으로 결정된 경우
        if assembly.method_details?.contains("PISA") == true {
            relevance += "PISA analysis suggests this assembly is biologically relevant. "
        }
        
        // 후보 조립체인 경우
        if assembly.rcsb_candidate_assembly == "Y" {
            relevance += "This is a candidate assembly for biological function. "
        }
        
        // 대칭성 정보 기반 판단
        let globalSymmetry = symmetryDetails.first { $0.kind == "Global Symmetry" }
        let localSymmetry = symmetryDetails.first { $0.kind == "Local Symmetry" }
        
        if let global = globalSymmetry {
            if global.oligomericState.contains("Homo") {
                relevance += "Homomeric assembly suggests functional oligomerization. "
            } else if global.oligomericState.contains("Hetero") {
                relevance += "Heteromeric assembly indicates complex functional unit. "
            }
        }
        
        if localSymmetry != nil {
            relevance += "Local symmetry elements suggest functional domains. "
        }
        
        // 올리고머 수 기반 판단
        if let count = assembly.oligomeric_count {
            if count == 1 {
                relevance += "Monomeric form - may represent functional unit or crystallization artifact. "
            } else if count >= 2 && count <= 6 {
                relevance += "Small oligomer - likely represents functional assembly. "
            } else {
                relevance += "Large oligomer - may represent higher-order assembly or crystallization artifact. "
            }
        }
        
        return relevance.isEmpty ? "Biological relevance needs further analysis" : relevance
    }
    
    
}



// MARK: - Data Models
struct QuaternaryStructure {
    let subunits: [Subunit]
    let assembly: Assembly
    let interactions: [Interaction]
}

struct Subunit {
    let id: String
    let residueCount: Int
    let description: String
}

struct Assembly {
    let type: String
    let symmetry: String
    let totalMass: Double
    let oligomericCount: Int
    let polymerComposition: String
    let atomCount: Int
    let assemblyId: String
    let methodDetails: String?
    let isCandidateAssembly: Bool?
    let symmetryDetails: [SymmetryDetail]
    let biologicalRelevance: String?
}

struct SymmetryDetail {
    let symbol: String
    let type: String
    let stoichiometry: [String]
    let oligomericState: String
    let kind: String
    let rotationAxes: [RotationAxis]?
    let avgRmsd: Double?
}

struct RotationAxis {
    let start: [Double]
    let end: [Double]
    let order: Int
}

struct Interaction {
    let subunit1: String
    let subunit2: String
    let contactCount: Int
    let description: String
}

// MARK: - API Response Models

struct AssemblyResponse: Codable {
    let pdbx_struct_assembly: PdbxStructAssembly?
    let rcsb_assembly_info: RcsbAssemblyInfo?
    let rcsb_struct_symmetry: [RcsbStructSymmetry]?
}

struct PdbxStructAssembly: Codable {
    let oligomeric_details: String?
    let oligomeric_count: Int?
    let method_details: String?
    let rcsb_candidate_assembly: String?
}

struct RcsbAssemblyInfo: Codable {
    let molecular_weight: Double?
    let polymer_composition: String?
    let atom_count: Int?
}

struct RcsbStructSymmetry: Codable {
    let symbol: String?
    let type: String?
    let oligomeric_state: String?
    let stoichiometry: [String]?
    let kind: String?
    let rotation_axes: [RotationAxisResponse]?
    let avg_rmsd: Double?
}

struct RotationAxisResponse: Codable {
    let start: [Double]?
    let end: [Double]?
    let order: Int?
}

struct InterfaceResponse: Codable {
    let rcsb_interface_info: [RcsbInterfaceInfo]?
}

struct RcsbInterfaceInfo: Codable {
    let rcsb_interface_partner: [RcsbInterfacePartner]?
}

struct RcsbInterfacePartner: Codable {
    let interface_partner_identifier: InterfacePartnerIdentifier?
}

struct InterfacePartnerIdentifier: Codable {
    let asym_id: String?
}
