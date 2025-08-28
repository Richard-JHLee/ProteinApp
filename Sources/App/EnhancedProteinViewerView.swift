import SwiftUI
import SceneKit

// MARK: - RCSB API DTOs
struct RCSBEntityRoot: Decodable {
    let entityPoly: EntityPoly?
    let entitySrcGen: [EntitySrcGen]?
    let rcsbEntitySourceOrganism: [EntitySourceOrganism]?
    let rcsbEntityHostOrganism: [EntityHostOrganism]?
    let rcsbPolymerEntity: RCSBPolymerEntity?
    let rcsbGeneName: [RCSBGeneName]?
    let rcsbPolymerEntityAnnotation: [RCSBAnnotation]?
    
    enum CodingKeys: String, CodingKey {
        case entityPoly = "entity_poly"
        case entitySrcGen = "entity_src_gen"
        case rcsbEntitySourceOrganism = "rcsb_entity_source_organism"
        case rcsbEntityHostOrganism = "rcsb_entity_host_organism"
        case rcsbPolymerEntity = "rcsb_polymer_entity"
        case rcsbGeneName = "rcsb_gene_name"
        case rcsbPolymerEntityAnnotation = "rcsb_polymer_entity_annotation"
    }
}

struct EntityPoly: Decodable {
    let pdbxDescription: String?
    let pdbxFormula: String?
    let pdbxDetails: String?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case pdbxDescription = "pdbx_description"
        case pdbxFormula = "pdbx_formula"
        case pdbxDetails = "pdbx_details"
        case type
    }
}

struct EntitySrcGen: Decodable {
    let pdbxGeneSrcGene: String?
    let pdbxGeneSrcScientificName: String?
    let pdbxGeneSrcCommonName: String?
    
    enum CodingKeys: String, CodingKey {
        case pdbxGeneSrcGene = "pdbx_gene_src_gene"
        case pdbxGeneSrcScientificName = "pdbx_gene_src_scientific_name"
        case pdbxGeneSrcCommonName = "pdbx_gene_src_common_name"
    }
}

struct EntitySourceOrganism: Decodable {
    let scientificName: String?
    let commonName: String?
    let ncbiTaxonomyId: Int?
}

struct EntityHostOrganism: Decodable {
    let scientificName: String?
    let commonName: String?
    let ncbiTaxonomyId: Int?
}

struct RCSBPolymerEntity: Decodable {
    let pdbxDescription: String?
    let rcsbMacromolecularNamesCombined: [RCSBMacromolecularName]?
    
    enum CodingKeys: String, CodingKey {
        case pdbxDescription = "pdbx_description"
        case rcsbMacromolecularNamesCombined = "rcsb_macromolecular_names_combined"
    }
}

struct RCSBMacromolecularName: Decodable {
    let name: String?
    let provenanceCode: String?
    let provenanceSource: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case provenanceCode = "provenance_code"
        case provenanceSource = "provenance_source"
    }
}

struct RCSBGeneName: Decodable {
    let value: String?
    let provenanceSource: String?
    
    enum CodingKeys: String, CodingKey {
        case value
        case provenanceSource = "provenance_source"
    }
}

struct RCSBAnnotation: Decodable {
    let annotationId: String?
    let name: String?
    let type: String?
    let provenanceSource: String?
    
    enum CodingKeys: String, CodingKey {
        case annotationId = "annotation_id"
        case name
        case type
        case provenanceSource = "provenance_source"
    }
}

// MARK: - Position3D Type Definition
struct Position3D {
    let x: Double
    let y: Double
    let z: Double
    
    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - Enhanced Protein Viewer
struct EnhancedProteinViewerView: View {
    let protein: ProteinInfo
    
    @State private var structure: PDBStructure?
    @State private var isLoading = false
    @State private var loadingProgress = ""
    @State private var error: String?
    
    // Viewer States
    @State private var style: RenderStyle = .cartoon
    @State private var colorMode: ColorMode = .chain
    @State private var uniformColor: Color = .blue
    @State private var autoRotate = false
    @State private var selectedAtom: Atom?
    
    // Tab Selection
    // ✅ Tab Selection (주석 해제/복원)
    @State private var selectedTab: ViewerTab = .chains

    // ✅ 전역 enum 삭제하고, 이 중첩 enum만 사용
    enum ViewerTab: String, CaseIterable {
        case chains = "Chains"
        case residues = "Residues"
        case ligands = "Ligands"
        case pockets = "Pockets"
        case annotations = "Annotations"

        var title: String { rawValue }
        var icon: String {
            switch self {
            case .chains: return "link"
            case .residues: return "link.badge.plus"
            case .ligands: return "pills"
            case .pockets: return "scope"
            case .annotations: return "book"
            }
        }
        var color: Color {
            switch self {
            case .chains: return .blue
            case .residues: return .green
            case .ligands: return .purple
            case .pockets: return .orange
            case .annotations: return .red
            }
        }
    }
    // Data States
    @State private var ligandsData: [LigandModel] = []
    @State private var pocketsData: [PocketModel] = []
    @State private var annotationsData: AnnotationData?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Header
                enhancedHeaderView
                
                // Main 3D Viewer
                ZStack {
                    ProteinSceneView(
                        structure: structure,
                        style: style,
                        colorMode: colorMode,
                        uniformColor: UIColor(uniformColor),
                        autoRotate: autoRotate,
                        onSelectAtom: { atom in
                            selectedAtom = atom
                        }
                    )
                    .background(Color.black)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            VStack(spacing: 8) {
                                Text("Loading protein structure...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if !loadingProgress.isEmpty {
                                    Text(loadingProgress)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                } else {
                                    Text("Fetching data from RCSB, PDBe, and UniProt")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                    }
                    
                    if let error = error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            
                            VStack(spacing: 8) {
                                Text("Loading Error")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Button("Retry") {
                                Task { await loadStructure() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                    }
                }
                
                // Enhanced Bottom Panel (Tab 형식) - 로딩 중에도 표시
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Loading protein structure...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !loadingProgress.isEmpty {
                            Text(loadingProgress)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button("Retry") {
                            Task { await loadStructure() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                } else {
                    enhancedBottomPanel
                        .opacity(structure != nil ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.3), value: structure != nil)
                }
                
                // Data Status Indicator - 현재 선택된 탭에 따라 동적 표시
                if let structure = structure {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        
                        // 탭별 맞춤 정보 표시
                        switch selectedTab {
                        case .chains:
                            Text("Structure loaded: \(structure.atoms.count) atoms, \(structure.bonds.count) bonds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .residues:
                            let residueCount = Set(structure.atoms.map { "\($0.residueName)\($0.residueNumber)" }).count
                            Text("Residues: \(residueCount) unique amino acids")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .ligands:
                            Text("Ligands: \(ligandsData.count) molecules")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .pockets:
                            Text("Pockets: \(pocketsData.count) binding sites")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .annotations:
                            if let annotations = annotationsData {
                                Text("Annotations: \(annotations.goTerms.count) GO terms, \(annotations.pathways.count) pathways")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Annotations: No data available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // 현재 탭과 관련된 추가 정보만 표시
                        switch selectedTab {
                        case .ligands:
                            if !ligandsData.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "pills")
                                        .font(.caption)
                                    Text("\(ligandsData.count) ligands")
                                        .font(.caption)
                                }
                                .foregroundColor(.purple)
                            }
                        case .annotations:
                            if annotationsData != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "book")
                                        .font(.caption)
                                    Text("Annotations")
                                    .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task { await loadStructure() }
        }
    }
    
    // MARK: - Enhanced Header
    private var enhancedHeaderView: some View {
        HStack {
            // Back Button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(protein.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    // PDB ID
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(protein.id.uppercased())
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Resolution (Mock data)
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("2.1 Å")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Category with dynamic icon
                    HStack(spacing: 4) {
                        Image(systemName: protein.dynamicIcon)
                            .font(.caption)
                            .foregroundColor(protein.dynamicColor)
                        
                        Text(protein.category.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundColor(protein.dynamicColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(protein.dynamicColor.opacity(0.1), in: Capsule())
                }
            }
            
            Spacer()
            
            // Control Buttons
            HStack(spacing: 12) {
                // Rotate Toggle
                Button(action: { autoRotate.toggle() }) {
                    Image(systemName: autoRotate ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(autoRotate ? .orange : .blue)
                }
                
                // Share Button
                shareButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private var shareButton: some View {
        Menu {
            Button(action: { exportImage() }) {
                Label("Save Image", systemImage: "photo")
            }
            
            Button(action: { exportVideo() }) {
                Label("Export Video", systemImage: "video")
            }
            
            Button(action: { shareStructure() }) {
                Label("Share Structure", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Enhanced Bottom Panel
    private var enhancedBottomPanel: some View {
        VStack(spacing: 0) {
            // Tab Selector
            tabSelector
            
            // Tab Content
            TabView(selection: $selectedTab) {
                chainsTabView
                    .tag(ViewerTab.chains)
                
                residuesTabView
                    .tag(ViewerTab.residues)
                
                ligandsTabView
                    .tag(ViewerTab.ligands)
                
                pocketsTabView
                    .tag(ViewerTab.pockets)
                
                annotationsTabView
                    .tag(ViewerTab.annotations)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)
        }
        .background(.ultraThinMaterial)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ViewerTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                        
                        Text(tab.title)
                            .font(.caption.weight(.medium))
                            .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(selectedTab.color)
                .animation(.spring(response: 0.3), value: selectedTab),
            alignment: .bottom
        )
    }
    
    // MARK: - Chains Tab (기본 구현)
    private var chainsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("🧬 Protein Chains")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let structure = structure {
                        let uniqueChains = Set(structure.atoms.map { $0.chain })
                        Text("\(uniqueChains.count) chains")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Chain Information
                if let structure = structure {
                    let chainGroups = Dictionary(grouping: structure.atoms) { $0.chain }
                    ForEach(chainGroups.keys.sorted(), id: \.self) { chainId in
                        chainCard(chainId: chainId, atoms: chainGroups[chainId] ?? [])
                    }
                } else {
                    Text("No structure loaded")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }
    
    private func chainCard(chainId: String, atoms: [Atom]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chain Header
            HStack {
                // Chain Chip
                HStack(spacing: 6) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 12, height: 12)
                    
                    Text("Chain \(chainId)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.1), in: Capsule())
                
                Spacer()
                
                Text("\(atoms.count) atoms")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            // Chain Actions
            HStack(spacing: 8) {
                Button(action: { highlightChain() }) {
                    Label("Highlight", systemImage: "eye")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
                
                Button(action: { focusOnChain() }) {
                    Label("Focus", systemImage: "scope")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Residues Tab
    private var residuesTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("🧩 Secondary Structure")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("Color Legend")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Secondary Structure Legend
                secondaryStructureLegend
                
                // Secondary Structure Statistics
                if let structure = structure {
                    secondaryStructureStats(for: structure)
                } else {
                    Text("No structure loaded")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
                
                // Selected Residue Details
                selectedResidueDetails
            }
            .padding()
        }
    }
    
    private var secondaryStructureLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Secondary Structure Color Scheme")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                legendItem("Alpha Helix", color: .red, icon: "tornado", description: "Right-handed spiral structure")
                legendItem("Beta Sheet", color: .blue, icon: "rectangle.stack", description: "Extended strand structure")
                legendItem("Turn/Loop", color: .green, icon: "arrow.turn.up.right", description: "Connecting regions")
                legendItem("Random Coil", color: .gray, icon: "scribble", description: "Unstructured regions")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func legendItem(_ name: String, color: Color, icon: String, description: String) -> some View {
        HStack(spacing: 12) {
            // Color indicator and icon
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func secondaryStructureStats(for structure: PDBStructure) -> some View {
        let totalAtoms = structure.atoms.count
        let helixCount = structure.atoms.filter { $0.secondaryStructure == .helix }.count
        let sheetCount = structure.atoms.filter { $0.secondaryStructure == .sheet }.count
        let coilCount = structure.atoms.filter { $0.secondaryStructure == .coil }.count
        let unknownCount = structure.atoms.filter { $0.secondaryStructure == .unknown }.count
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Structure Distribution")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                if totalAtoms > 0 {
                    structureBar("Alpha Helix", count: helixCount, total: totalAtoms, color: .red)
                    structureBar("Beta Sheet", count: sheetCount, total: totalAtoms, color: .blue)
                    structureBar("Turn/Loop", count: coilCount, total: totalAtoms, color: .green)
                    structureBar("Random Coil", count: unknownCount, total: totalAtoms, color: .gray)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func structureBar(_ name: String, count: Int, total: Int, color: Color) -> some View {
        let percentage = total > 0 ? Int((Double(count) / Double(total)) * 100) : 0
        
        return VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(count) atoms (\(percentage)%)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(color)
            }
            
            ProgressView(value: Double(count), total: Double(total))
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 1.5)
        }
    }
    
    private var selectedResidueDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Residue Information")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            if let atom = selectedAtom {
                selectedResidueCard(atom)
            } else {
                Text("Tap on a residue in the 3D view to see details")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func selectedResidueCard(_ atom: Atom) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(atom.residueName) \(atom.residueNumber)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Chain \(atom.chain)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.gray.opacity(0.2), in: Capsule())
            }
            
            Text("Atom: \(atom.name) (\(atom.element))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Secondary Structure:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(secondaryStructureName(atom.secondaryStructure))
                    .font(.caption.weight(.medium))
                    .foregroundColor(secondaryStructureColor(atom.secondaryStructure))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(secondaryStructureColor(atom.secondaryStructure).opacity(0.1), in: Capsule())
            }
            
            Text("Position: (\(String(format: "%.1f", atom.position.x)), \(String(format: "%.1f", atom.position.y)), \(String(format: "%.1f", atom.position.z)))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(secondaryStructureColor(atom.secondaryStructure).opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func secondaryStructureName(_ ss: SecondaryStructure) -> String {
        switch ss {
        case .helix: return "Alpha Helix"
        case .sheet: return "Beta Sheet"
        case .coil: return "Turn/Loop"
        case .unknown: return "Random Coil"
        }
    }
    
    private func secondaryStructureColor(_ ss: SecondaryStructure) -> Color {
        switch ss {
        case .helix: return .red
        case .sheet: return .blue
        case .coil: return .green
        case .unknown: return .gray
        }
    }
    
    // MARK: - Ligands Tab
    private var ligandsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("💊 Ligands & Small Molecules")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(ligandsData.count) ligands")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if ligandsData.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "pills")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No ligands found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("This protein structure doesn't contain any ligands or small molecules")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // Ligand Cards
                    ForEach(ligandsData) { ligand in
                        LigandCard(ligand: ligand) {
                            focusOnLigand()
                        }
                    }
                    
                    // Ligand Analysis Summary
                    LigandAnalysisSummary(ligands: ligandsData)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Pockets Tab
    private var pocketsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("🔬 Binding Pockets")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(pocketsData.count) pockets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if pocketsData.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "scope")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No pockets detected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Pocket detection analysis hasn't been performed or no significant binding sites were found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // Pocket Cards
                    ForEach(pocketsData) { pocket in
                        PocketCard(pocket: pocket) {
                            viewPocket(pocket)
                        }
                    }
                    
                    // Pocket Analysis Summary
                    PocketAnalysisSummary(pockets: pocketsData)
                }
            }
            .padding()
        }
    }
    
    private func viewPocket(_ pocket: PocketModel) {
        print("Viewing pocket: \(pocket.name)")
        // TODO: Implement pocket visualization in 3D viewer
    }
    
    // MARK: - Annotations Tab
    private var annotationsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("📖 Protein Annotations")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                if let annotations = annotationsData {
                    VStack(spacing: 16) {
                        // Function Description
                        functionCard(annotations)
                        
                        // Gene Information
                        geneCard(annotations)
                        
                        // Organism Information
                        organismCard(annotations)
                        
                        // GO Terms
                        goTermsCard(annotations)
                        
                        // Pathways
                        pathwaysCard(annotations)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "book")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No annotations available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Annotation data is still being processed or not available for this protein")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Annotation Functions
    private func functionCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "function")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Protein Function")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(annotations.function)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func geneCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link.badge.plus")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Gene Information")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                Text("Gene Symbol:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Text(annotations.gene)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.1), in: Capsule())
            }
        }
        .padding(16)
        .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func organismCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Organism")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                Text("Species:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Text(annotations.organism)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .italic()
            }
        }
        .padding(16)
        .background(.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func goTermsCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Gene Ontology Terms")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(annotations.goTerms.count) terms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(annotations.goTerms, id: \.self) { term in
                    Text(term)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(16)
        .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func pathwaysCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text("Biological Pathways")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(annotations.pathways.count) pathways")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(annotations.pathways, id: \.self) { pathway in
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        
                        Text(pathway)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Placeholder Functions
    private func exportImage() {
        print("Exporting image...")
    }
    
    private func exportVideo() {
        print("Exporting video...")
    }
    
    private func shareStructure() {
        print("Sharing structure...")
    }
    
    private func highlightChain() {
        print("Highlighting chain...")
    }
    
    private func focusOnChain() {
        print("Focusing on chain...")
    }
    
    private func focusOnLigand() {
        print("Focusing on ligand...")
    }
    
    // MARK: - Functions
    /// 실제 로딩(병렬 호출) — 실제 API 데이터만 사용
    fileprivate func loadStructure() async {
        await MainActor.run { 
            isLoading = true 
            loadingProgress = "Initializing..."
            error = nil 
            // 기존 데이터 초기화
            structure = nil
            ligandsData = []
            pocketsData = []
            annotationsData = nil
        }

        do {
            // 1. RCSB에서 PDB 구조 로드
            await MainActor.run { loadingProgress = "Loading 3D structure from RCSB..." }
            let structure: PDBStructure
            do {
                structure = try await loadStructureFromRCSB(pdbId: protein.id)
                print("✅ Successfully loaded structure from RCSB for \(protein.id)")
                
                // 원자 그룹화 및 최적화
                let optimizedStructure = optimizeStructureForRendering(structure)
                print("🔧 Structure optimized: \(structure.atoms.count) atoms → \(optimizedStructure.atoms.count) groups")
                
                await MainActor.run { self.structure = optimizedStructure }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load protein structure from RCSB: \(error.localizedDescription)"
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                return
            }
            
            // 2. RCSB에서 엔티티 정보 로드 (리간드, 주석 등)
            await MainActor.run { loadingProgress = "Fetching protein annotations from RCSB..." }
            let rcsbEntity: RCSBEntityRoot?
            do {
                rcsbEntity = try await fetchEntityInfoFromRCSB(pdbId: protein.id)
                if let entity = rcsbEntity {
                    print("✅ Successfully loaded RCSB entity info for \(protein.id)")
                    print("🔍 Entity details: \(entity)")
                } else {
                    print("ℹ️ No RCSB entity info available for \(protein.id)")
                }
            } catch {
                print("⚠️ Failed to fetch RCSB entity info: \(error.localizedDescription)")
                rcsbEntity = nil
            }
            
            // 3. PDBe에서 리간드 메타데이터 로드
            await MainActor.run { loadingProgress = "Loading ligand information from PDBe..." }
            let ligMeta: [LigandModel]
            do {
                ligMeta = try await fetchLigandsMetaFromPDBe(pdbId: protein.id)
                print("✅ Successfully loaded ligand metadata from PDBe: \(ligMeta.count) ligands")
            } catch {
                print("⚠️ Failed to load ligand metadata: \(error.localizedDescription)")
                ligMeta = []
            }
            
            // 4. PDB to UniProt 매핑
            await MainActor.run { loadingProgress = "Mapping PDB to UniProt database..." }
            let uni: String?
            do {
                uni = try await mapPDBtoUniProt(pdbId: protein.id)
                if let uni = uni {
                    print("✅ Successfully mapped PDB \(protein.id) to UniProt \(uni)")
                } else {
                    print("ℹ️ No UniProt mapping found for \(protein.id)")
                }
            } catch {
                print("⚠️ Failed to map PDB to UniProt: \(error.localizedDescription)")
                uni = nil
            }
            
            // 5. UniProt에서 주석 데이터 로드
            var annotations: AnnotationData?
            if let uni = uni {
                await MainActor.run { loadingProgress = "Fetching protein annotations from UniProt..." }
                do {
                    annotations = try await fetchAnnotationsFromUniProt(uniprotId: uni)
                    print("✅ Successfully loaded annotations from UniProt")
                } catch {
                    print("⚠️ Failed to fetch annotations: \(error.localizedDescription)")
                    annotations = nil
                }
            } else {
                print("ℹ️ No UniProt ID available for annotations fetching")
                annotations = nil
            }

            // 6. RCSB 데이터로 주석 정보 보강
            await MainActor.run { loadingProgress = "Processing and combining annotation data..." }
            let enhancedAnnotations: AnnotationData?
            if let entity = rcsbEntity {
                enhancedAnnotations = createAnnotationsFromRCSB(entity: entity, uniprotAnnotations: annotations)
                print("✅ Enhanced annotations with RCSB data")
                print("🔍 Final annotations data:")
                print("  - Function: \(enhancedAnnotations?.function ?? "Unknown")")
                print("  - Gene: \(enhancedAnnotations?.gene ?? "Unknown")")
                print("  - Organism: \(enhancedAnnotations?.organism ?? "Unknown")")
                print("  - GO Terms: \(enhancedAnnotations?.goTerms.count ?? 0)")
                print("  - Pathways: \(enhancedAnnotations?.pathways.count ?? 0)")
            } else {
                enhancedAnnotations = annotations
                print("ℹ️ Using UniProt annotations only")
                if let annotations = annotations {
                    print("🔍 UniProt annotations:")
                    print("  - Function: \(annotations.function)")
                    print("  - Gene: \(annotations.gene)")
                    print("  - Organism: \(annotations.organism)")
                    print("  - GO Terms: \(annotations.goTerms.count)")
                    print("  - Pathways: \(annotations.pathways.count)")
                }
            }

            // 7. 최종 데이터 설정
            await MainActor.run {
                self.ligandsData = mergeLigands(meta: ligMeta, with: self.structure ?? structure)
                self.annotationsData = enhancedAnnotations
                self.pocketsData = generatePocketsFromStructure(self.structure ?? structure)
                self.isLoading = false
                self.loadingProgress = ""
                
                // 로그 추가
                if let annotations = enhancedAnnotations {
                    print("✅ Final annotations data: \(annotations)")
                } else {
                    print("⚠️ No annotations data available")
                }
                
                // 성공 메시지
                if let error = self.error {
                    print("⚠️ Data loaded with warnings: \(error)")
                } else {
                    print("🎉 All data loaded successfully!")
                }
            }
            
        } 
    }
    
    /// 원자 그룹화를 통한 렌더링 최적화
    private func optimizeStructureForRendering(_ originalStructure: PDBStructure) -> PDBStructure {
        let maxAtoms = 500 // 최대 원자 수 제한
        let maxGroups = 100 // 최대 그룹 수 제한
        
        if originalStructure.atoms.count <= maxAtoms {
            print("🔧 Structure already optimized (\(originalStructure.atoms.count) atoms)")
            return originalStructure
        }
        
        print("🔧 Optimizing structure: \(originalStructure.atoms.count) atoms → target: \(maxAtoms)")
        
        // 1. 체인별로 그룹화
        let chainGroups = Dictionary(grouping: originalStructure.atoms) { $0.chain }
        var optimizedAtoms: [Atom] = []
        var optimizedBonds: [Bond] = []
        
        for (chainId, atoms) in chainGroups {
            let chainAtoms = optimizeChainAtoms(atoms, maxAtoms: maxAtoms / chainGroups.count)
            optimizedAtoms.append(contentsOf: chainAtoms)
            
            // 해당 체인의 결합만 유지
            let chainBonds = originalStructure.bonds.filter { bond in
                chainAtoms.contains { $0.id == bond.atom1Id } && 
                chainAtoms.contains { $0.id == bond.atom2Id }
            }
            optimizedBonds.append(contentsOf: chainBonds)
        }
        
        // 2. 전체 원자 수가 여전히 많으면 추가 최적화
        if optimizedAtoms.count > maxAtoms {
            print("🔧 Further optimization needed: \(optimizedAtoms.count) atoms")
            optimizedAtoms = furtherOptimizeAtoms(optimizedAtoms, maxAtoms: maxAtoms)
            
            // 결합도 다시 필터링
            optimizedBonds = optimizedBonds.filter { bond in
                optimizedAtoms.contains { $0.id == bond.atom1Id } && 
                optimizedAtoms.contains { $0.id == bond.atom2Id }
            }
        }
        
        print("🔧 Optimization complete: \(originalStructure.atoms.count) → \(optimizedAtoms.count) atoms")
        
        return PDBStructure(
            atoms: optimizedAtoms,
            bonds: optimizedBonds,
            title: originalStructure.title,
            secondaryStructures: originalStructure.secondaryStructures
        )
    }
    
    /// 체인별 원자 최적화
    private func optimizeChainAtoms(_ atoms: [Atom], maxAtoms: Int) -> [Atom] {
        if atoms.count <= maxAtoms {
            return atoms
        }
        
        // 1. 2차 구조별로 그룹화
        let structureGroups = Dictionary(grouping: atoms) { $0.secondaryStructure }
        var optimizedAtoms: [Atom] = []
        
        for (structure, structureAtoms) in structureGroups {
            let groupSize = max(1, maxAtoms / structureGroups.count)
            let sampledAtoms = sampleAtomsFromGroup(structureAtoms, targetCount: groupSize)
            optimizedAtoms.append(contentsOf: sampledAtoms)
        }
        
        // 2. 여전히 많으면 균등 샘플링
        if optimizedAtoms.count > maxAtoms {
            optimizedAtoms = sampleAtomsEvenly(optimizedAtoms, targetCount: maxAtoms)
        }
        
        return optimizedAtoms
    }
    
    /// 그룹에서 원자 샘플링 (2차 구조 유지)
    private func sampleAtomsFromGroup(_ atoms: [Atom], targetCount: Int) -> [Atom] {
        if atoms.count <= targetCount {
            return atoms
        }
        
        // 균등 간격으로 샘플링하여 전체 구조를 대표
        let step = Double(atoms.count) / Double(targetCount)
        var sampledAtoms: [Atom] = []
        
        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            if index < atoms.count {
                sampledAtoms.append(atoms[index])
            }
        }
        
        return sampledAtoms
    }
    
    /// 균등 샘플링
    private func sampleAtomsEvenly(_ atoms: [Atom], targetCount: Int) -> [Atom] {
        if atoms.count <= targetCount {
            return atoms
        }
        
        let step = Double(atoms.count) / Double(targetCount)
        var sampledAtoms: [Atom] = []
        
        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            if index < atoms.count {
                sampledAtoms.append(atoms[index])
            }
        }
        
        return sampledAtoms
    }
    
    /// 추가 원자 최적화
    private func furtherOptimizeAtoms(_ atoms: [Atom], maxAtoms: Int) -> [Atom] {
        if atoms.count <= maxAtoms {
            return atoms
        }
        
        // 1. 중요도 기반 샘플링 (2차 구조가 있는 원자 우선)
        let importantAtoms = atoms.filter { $0.secondaryStructure != .unknown }
        let regularAtoms = atoms.filter { $0.secondaryStructure == .unknown }
        
        let importantCount = min(importantAtoms.count, maxAtoms / 2)
        let regularCount = maxAtoms - importantCount
        
        var optimizedAtoms: [Atom] = []
        
        // 중요 원자들 추가
        if importantCount > 0 {
            let sampledImportant = sampleAtomsEvenly(importantAtoms, targetCount: importantCount)
            optimizedAtoms.append(contentsOf: sampledImportant)
        }
        
        // 일반 원자들 추가
        if regularCount > 0 && regularAtoms.count > 0 {
            let sampledRegular = sampleAtomsEvenly(regularAtoms, targetCount: regularCount)
            optimizedAtoms.append(contentsOf: sampledRegular)
        }
        
        return optimizedAtoms
    }

    // MARK: - Pockets (lightweight heuristic)
    // 목적: 구조 내 원자 밀도와 리간드 인접성을 이용해 간단히 포켓 후보를 생성
    func generatePocketsFromStructure(_ structure: PDBStructure) -> [PocketModel] {
        // 체인 단위로 그룹핑
        let chains = Dictionary(grouping: structure.atoms, by: { $0.chain })
        var pockets: [PocketModel] = []

        for (idx, pair) in chains.enumerated() {
            let chainId = pair.key
            let atoms = pair.value
            guard atoms.count >= 12 else { continue }

            // 중심점(centroid)과 평균 거리로 밀도 근사
            let center = atoms.reduce(SIMD3<Float>(0,0,0)) { $0 + $1.position } / Float(atoms.count)
            let avgDist = atoms.map { length($0.position - center) }.reduce(0,+) / Float(atoms.count)
            let densityScore = max(0.0, min(1.0, 1.0 / Double(avgDist + 0.001)))   // 거리가 작을수록 조밀 → 점수↑
            let volume = Int(max(300, min(1800, Double(atoms.count) * Double(avgDist) * 8.0)))

            let score = min(0.95, 0.55 + densityScore * 0.4)
            let druggability = score > 0.85 ? "High" : (score > 0.7 ? "Medium" : "Low")

            pockets.append(
                PocketModel(
                    name: "Binding Site \(idx + 1) – Chain \(chainId)",
                    score: score,
                    volume: volume,
                    description: "Heuristic pocket near chain \(chainId) centroid",
                    druggability: druggability
                )
            )
        }
        return pockets
    }
}

// MARK: - Supporting Enums
enum ViewerTab: String, CaseIterable {
    case chains = "Chains"
    case residues = "Residues"
    case ligands = "Ligands"
    case pockets = "Pockets"
    case annotations = "Annotations"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .chains: return "link"
        case .residues: return "link.badge.plus"
        case .ligands: return "pills"
        case .pockets: return "scope"
        case .annotations: return "book"
        }
    }
    
    var color: Color {
        switch self {
        case .chains: return .blue
        case .residues: return .green
        case .ligands: return .purple
        case .pockets: return .orange
        case .annotations: return .red
        }
    }
}

// MARK: - Ligand Model
struct LigandModel: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    var position: SIMD3<Float>
    let molecularWeight: Double // in kDa
    let charge: Double
    let type: String
}

// MARK: - Ligand Card View
struct LigandCard: View {
    let ligand: LigandModel
    let onFocus: () -> Void
    
    var body: some View {
        Button(action: onFocus) {
            HStack(spacing: 12) {
                // Ligand Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "pills.fill")
                        .font(.title3)
                        .foregroundColor(Color.purple)
                }
                
                // Ligand Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(ligand.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(ligand.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Label("Position", systemImage: "location")
                            .font(.caption)
                            .foregroundColor(Color.blue)
                        
                        Text("(\(String(format: "%.1f", ligand.position.x)), \(String(format: "%.1f", ligand.position.y)), \(String(format: "%.1f", ligand.position.z)))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    // Molecular Properties
                    HStack(spacing: 8) {
                        PropertyTag(text: "MW: \(ligand.molecularWeight)kDa", color: Color.green)
                        PropertyTag(text: "Charge: \(ligand.charge)", color: Color.orange)
                    }
                }
                
                Spacer()
                
                // Focus Button
                VStack(spacing: 4) {
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundColor(Color.purple)
                    
                    Text("Focus")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color.purple)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Property Tag View
struct PropertyTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Ligand Analysis Summary View
struct LigandAnalysisSummary: View {
    let ligands: [LigandModel]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ligand Analysis Summary")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total MW", 
                    value: "\(String(format: "%.1f", ligands.reduce(0.0) { $0 + $1.molecularWeight }))kDa", 
                    color: Color.blue
                )
                StatCard(
                    title: "Avg Charge", 
                    value: String(format: "%.1f", ligands.isEmpty ? 0.0 : ligands.reduce(0.0) { $0 + $1.charge } / Double(ligands.count)), 
                    color: Color.green
                )
                StatCard(
                    title: "Types", 
                    value: "\(Set(ligands.map { $0.type }).count)", 
                    color: Color.orange
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Card View
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pocket Model
struct PocketModel: Identifiable {
    let id = UUID()
    let name: String
    let score: Double // 0.0 to 1.0
    let volume: Int // in Ų
    let description: String
    let druggability: String // "High", "Medium", "Low"
}

// MARK: - Pocket Card View
struct PocketCard: View {
    let pocket: PocketModel
    let onView: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pocket Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pocket.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(pocket.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Score Gauge
                ZStack {
                    Circle()
                        .stroke(.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: pocket.score)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(pocket.score * 100))")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary)
                }
            }
            
            // Pocket Details
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(pocket.volume) Ų")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.2f", pocket.score))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(pocket.score > 0.7 ? .green : pocket.score > 0.5 ? .orange : .red)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Druggability")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(pocket.druggability)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DruggabilityHelper.color(for: pocket.druggability))
                }
                
                Spacer()
                
                // View Button
                Button(action: onView) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                        Text("View")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pocket Analysis Summary View
struct PocketAnalysisSummary: View {
    let pockets: [PocketModel]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pocket Analysis Summary")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Volume", 
                    value: "\(pockets.reduce(0) { $0 + $1.volume }) Ų", 
                    color: Color.blue
                )
                StatCard(
                    title: "Avg Score", 
                    value: String(format: "%.2f", pockets.isEmpty ? 0.0 : pockets.reduce(0.0) { $0 + $1.score } / Double(pockets.count)), 
                    color: Color.green
                )
                StatCard(
                    title: "Best Score", 
                    value: String(format: "%.2f", pockets.max(by: { $0.score < $1.score })?.score ?? 0.0), 
                    color: Color.orange
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Druggability Helper
struct DruggabilityHelper {
    static func color(for druggability: String) -> Color {
        switch druggability.lowercased() {
        case "high": return .green
        case "medium": return .orange
        case "low": return .red
        default: return .gray
        }
    }
}

// MARK: - Annotation Data Model
struct AnnotationData {
    let function: String
    let gene: String
    let organism: String
    let goTerms: [String]
    let pathways: [String]
}

// MARK: - Networking
private enum NetError: Error { case badURL, badStatus(Int), badData }

private struct Net {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static func getText(_ url: URL) async throws -> String {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse else { throw NetError.badData }
        guard (200..<300).contains(http.statusCode) else { throw NetError.badStatus(http.statusCode) }
        guard let text = String(data: data, encoding: .utf8) else { throw NetError.badData }
        return text
    }

    static func getJSON<T: Decodable>(_ url: URL, as: T.Type) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse else { throw NetError.badData }
        guard (200..<300).contains(http.statusCode) else { throw NetError.badStatus(http.statusCode) }
        return try decoder.decode(T.self, from: data)
    }
}
// MARK: - External DTOs
private struct PDBeLigandRoot: Decodable { let ligandMonomers: [PDBeLigand]? }
private struct PDBeLigand: Decodable {
    let chemCompId: String?
    let moleculeName: [String]?
    let formulaWeight: Double?
    let charge: Int?
}

// 새로운 PDBe 리간드 API 구조체
private struct PDBeLigandNew: Decodable {
    let chainId: String?
    let chemCompId: String?
    let chemCompName: String?
    let weight: Double?
    let entityId: Int?
    
    enum CodingKeys: String, CodingKey {
        case chainId = "chain_id"
        case chemCompId = "chem_comp_id"
        case chemCompName = "chem_comp_name"
        case weight
        case entityId = "entity_id"
    }
}

private struct PDBeUniProtMapRoot: Decodable { let uniprotIds: [String]? }

private struct UniProtDTO: Decodable {
    struct ProteinDescription: Decodable {
        struct RecName: Decodable { struct NameText: Decodable { let value: String? }; let fullName: NameText? }
        let recommendedName: RecName?
    }
    struct Organism: Decodable { let scientificName: String? }
    struct DBRef: Decodable { let type: String?; let id: String? }

    let primaryAccession: String?
    let proteinDescription: ProteinDescription?
    let organism: Organism?
    let genes: [Gene]?
    let comments: [Comment]?
    let uniProtKBCrossReferences: [DBRef]?

    struct Gene: Decodable { struct GeneName: Decodable { let value: String? }; let geneName: GeneName? }
    struct Comment: Decodable { let commentType: String?; let texts: [Text]?; struct Text: Decodable { let value: String? } }
}

// MARK: - Live Data Loader
extension EnhancedProteinViewerView {

    /// RCSB에서 PDB 파일(.pdb) 내려받아 파싱
    private func loadStructureFromRCSB(pdbId: String) async throws -> PDBStructure {
        let id = pdbId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://files.rcsb.org/download/\(id).pdb") else { throw NetError.badURL }
        let pdbText = try await Net.getText(url)
        return PDBParser.parse(pdbText: pdbText) // 프로젝트에 있는 파서 사용
    }

    /// RCSB에서 엔티티 정보 가져오기 (리간드, 주석 등)
    private func fetchEntityInfoFromRCSB(pdbId: String) async throws -> RCSBEntityRoot? {
        let id = pdbId.uppercased()
        guard let url = URL(string: "https://data.rcsb.org/rest/v1/core/polymer_entity/\(id)/1") else { throw NetError.badURL }
        
        do {
            let data = try await URLSession.shared.data(from: url).0
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 RCSB Entity API Response: \(jsonString)")
            }
            
            let entity = try JSONDecoder().decode(RCSBEntityRoot.self, from: data)
            return entity
        } catch {
            print("⚠️ Failed to fetch RCSB entity info: \(error.localizedDescription)")
            return nil
        }
    }

    /// RCSB 데이터로 주석 정보 생성
    private func createAnnotationsFromRCSB(entity: RCSBEntityRoot, uniprotAnnotations: AnnotationData?) -> AnnotationData {
        print("🔍 RCSB Entity Debug Info:")
        print("  - entityPoly: \(entity.entityPoly != nil)")
        print("  - entitySrcGen: \(entity.entitySrcGen?.count ?? 0)")
        print("  - rcsbEntitySourceOrganism: \(entity.rcsbEntitySourceOrganism?.count ?? 0)")
        print("  - rcsbPolymerEntity: \(entity.rcsbPolymerEntity != nil)")
        print("  - rcsbGeneName: \(entity.rcsbGeneName?.count ?? 0)")
        print("  - rcsbPolymerEntityAnnotation: \(entity.rcsbPolymerEntityAnnotation?.count ?? 0)")
        
        // Protein Function - RCSB에서 우선 추출
        var function = "Unknown"
        if let rcsbDesc = entity.rcsbPolymerEntity?.pdbxDescription, !rcsbDesc.isEmpty {
            function = rcsbDesc
            print("✅ Found RCSB function: \(rcsbDesc)")
        } else if let entityDesc = entity.entityPoly?.pdbxDescription, !entityDesc.isEmpty {
            function = entityDesc
            print("✅ Found entity function: \(entityDesc)")
        } else if let uniprotFunction = uniprotAnnotations?.function, uniprotFunction != "Unknown" {
            function = uniprotFunction
            print("✅ Using UniProt function: \(uniprotFunction)")
        }
        
        // Gene Information - RCSB에서 우선 추출
        var gene = "Unknown"
        if let rcsbGene = entity.rcsbGeneName?.first?.value, !rcsbGene.isEmpty {
            gene = rcsbGene
            print("✅ Found RCSB gene: \(rcsbGene)")
        } else if let srcGene = entity.entitySrcGen?.first?.pdbxGeneSrcGene, !srcGene.isEmpty {
            gene = srcGene
            print("✅ Found entity gene: \(srcGene)")
        } else if let uniprotGene = uniprotAnnotations?.gene, uniprotGene != "Unknown" {
            gene = uniprotGene
            print("✅ Using UniProt gene: \(uniprotGene)")
        }
        
        // Organism Information - RCSB에서 우선 추출
        var organism = "Unknown"
        if let sourceOrg = entity.rcsbEntitySourceOrganism?.first?.scientificName, !sourceOrg.isEmpty {
            organism = sourceOrg
            print("✅ Found RCSB organism: \(sourceOrg)")
        } else if let uniprotOrg = uniprotAnnotations?.organism, uniprotOrg != "Unknown" {
            organism = uniprotOrg
            print("✅ Using UniProt organism: \(uniprotOrg)")
        }
        
        // GO Terms and Pathways - UniProt에서 가져오되, RCSB 주석도 추가
        var goTerms = uniprotAnnotations?.goTerms ?? []
        var pathways = uniprotAnnotations?.pathways ?? []
        
        // RCSB에서 GO terms와 InterPro 추출
        if let annotations = entity.rcsbPolymerEntityAnnotation {
            for annotation in annotations {
                if annotation.type == "GO", let id = annotation.annotationId {
                    if !goTerms.contains(id) {
                        goTerms.append(id)
                    }
                }
                // InterPro도 pathways에 추가 (도메인 정보)
                if annotation.type == "InterPro", let id = annotation.annotationId {
                    if !pathways.contains(id) {
                        pathways.append(id)
                    }
                }
            }
        }
        
        print("🔍 RCSB Data Summary:")
        print("  - Function: \(function)")
        print("  - Gene: \(gene)")
        print("  - Organism: \(organism)")
        print("  - GO Terms: \(goTerms.count)")
        print("  - Pathways: \(pathways.count)")
        
        return AnnotationData(
            function: function,
            gene: gene,
            organism: organism,
            goTerms: goTerms,
            pathways: pathways
        )
    }

    /// PDBe: 리간드 메타 (이름/분자량/전하)
    private func fetchLigandsMetaFromPDBe(pdbId: String) async throws -> [LigandModel] {
        let id = pdbId.lowercased()
        guard let url = URL(string: "https://www.ebi.ac.uk/pdbe/api/pdb/entry/ligand_monomers/\(id)") else { throw NetError.badURL }
        do {
            let data = try await URLSession.shared.data(from: url).0
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 PDBe Ligand API Response: \(jsonString)")
            }
            
            // 새로운 JSON 구조에 맞춰 파싱
            let dict = try JSONDecoder().decode([String: [PDBeLigandNew]].self, from: data)
            let rows = dict[id] ?? []

            return rows.map { r in
                LigandModel(
                    name: r.chemCompId ?? "Unknown",
                    description: r.chemCompName ?? "No description",
                    position: .zero,
                    molecularWeight: (r.weight ?? 0) / 1000,
                    charge: 0.0, // PDBe API에서는 전하 정보가 없음
                    type: "Ligand"
                )
            }
        } catch {
            print("⚠️ JSON decoding error: \(error.localizedDescription)")
            throw NetError.badData
        }
    }

    private func fetchAnnotationsFromUniProt(uniprotId: String) async throws -> AnnotationData {
        guard let url = URL(string: "https://rest.uniprot.org/uniprotkb/\(uniprotId)") else { throw NetError.badURL }
        
        do {
            let data = try await URLSession.shared.data(from: url).0
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 UniProt API Response: \(jsonString)")
            }
            
            let uniprot = try JSONDecoder().decode(UniProtDTO.self, from: data)
            
            let function = uniprot.proteinDescription?.recommendedName?.fullName?.value ?? "Unknown"
            let gene = uniprot.genes?.first?.geneName?.value ?? "Unknown"
            let organism = uniprot.organism?.scientificName ?? "Unknown"
            
            // GO terms and pathways from cross-references
            var goTerms: [String] = []
            var pathways: [String] = []
            
            if let crossRefs = uniprot.uniProtKBCrossReferences {
                for ref in crossRefs {
                    if ref.type == "GO" {
                        if let id = ref.id {
                            goTerms.append(id)
                        }
                    } else if ref.type == "KEGG" {
                        if let id = ref.id {
                            pathways.append(id)
                        }
                    }
                }
            }
            
            print("🔍 UniProt Data Extracted:")
            print("  - Function: \(function)")
            print("  - Gene: \(gene)")
            print("  - Organism: \(organism)")
            print("  - GO Terms: \(goTerms.count)")
            print("  - Pathways: \(pathways.count)")
            
            return AnnotationData(
                function: function,
                gene: gene,
                organism: organism,
                goTerms: goTerms,
                pathways: pathways
            )
        } catch {
            print("⚠️ Failed to fetch UniProt annotations: \(error.localizedDescription)")
            throw NetError.badData
        }
    }

    private func mergeLigands(meta: [LigandModel], with structure: PDBStructure) -> [LigandModel] {
        var mergedLigands = meta
        
        // PDB 구조에서 HETATM 레코드로 리간드 위치 정보 추출
        let hetatoms = structure.atoms.filter { atom in
            // HETATM은 보통 리간드 원자들
            !["ATOM"].contains(atom.name) && atom.residueName != "HOH" && atom.residueName != "WAT"
        }
        
        // 리간드별로 그룹핑
        let ligandGroups = Dictionary(grouping: hetatoms) { atom in
            "\(atom.chain)_\(atom.residueName)_\(atom.residueNumber)"
        }
        
        // 메타데이터와 위치 정보 결합
        for (_, atoms) in ligandGroups {
            if mergedLigands
                .first(where: { $0.name == atoms.first?.residueName }) != nil {
                // 기존 리간드에 위치 정보 추가
                let center = atoms.reduce(SIMD3<Float>(0,0,0)) { $0 + $1.position } / Float(atoms.count)
                
                if let index = mergedLigands.firstIndex(where: { $0.name == atoms.first?.residueName }) {
                    // SIMD3<Float> 타입으로 직접 할당
                    mergedLigands[index].position = center
                }
            } else {
                // 새로운 리간드 생성
                let center = atoms.reduce(SIMD3<Float>(0,0,0)) { $0 + $1.position } / Float(atoms.count)
                
                let newLigand = LigandModel(
                    name: atoms.first?.residueName ?? "Unknown",
                    description: "Ligand from PDB structure",
                    position: center,
                    molecularWeight: 0.0, // PDB에서는 분자량 정보가 없음
                    charge: 0.0,
                    type: "Ligand"
                )
                mergedLigands.append(newLigand)
            }
        }
        
        return mergedLigands
    }

    private func mapPDBtoUniProt(pdbId: String) async throws -> String? {
        let id = pdbId.lowercased()
        guard let url = URL(string: "https://www.ebi.ac.uk/pdbe/api/mappings/uniprot/\(id)") else { return nil }
        
        do {
            let responseData = try await URLSession.shared.data(from: url).0
            if let jsonString = String(data: responseData, encoding: .utf8) {
                print("🔍 PDBe UniProt Mapping API Response: \(jsonString)")
            }
            
            let mappingData = try JSONDecoder().decode([String: [String: PDBeUniProtMapRoot]].self, from: responseData)
            let uniprotId = mappingData[id]?["UniProt"]?.uniprotIds?.first
            
            if let uniprotId = uniprotId {
                print("✅ Found UniProt mapping: \(pdbId) → \(uniprotId)")
            } else {
                print("ℹ️ No UniProt mapping found for \(pdbId)")
            }
            
            return uniprotId
        } catch {
            print("⚠️ Failed to map PDB to UniProt: \(error.localizedDescription)")
            return nil
        }
    }
}
