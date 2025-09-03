import SwiftUI
import SceneKit
import UIKit
import simd

// MARK: - Advanced Geometry Cache for Performance Optimization
final class GeometryCache {
    static let shared = GeometryCache()
    
    // Cache for LOD spheres and cylinders with color-based materials
    private var lodSphereCache = [String: SCNGeometry]()
    private var lodCylinderCache = [String: SCNGeometry]()
    private var materialByColor = [UInt32: SCNMaterial]()
    
    private func colorKey(_ c: UIColor) -> UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Convert 8bit RGBA to 32bit key
        return (UInt32(r*255)<<24) | (UInt32(g*255)<<16) | (UInt32(b*255)<<8) | UInt32(a*255)
    }
    
    func material(color: UIColor) -> SCNMaterial {
        let k = colorKey(color)
        if let m = materialByColor[k] { return m }
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = color
        m.specular.contents = UIColor.white
        materialByColor[k] = m
        return m
    }
    
    func lodSphere(radius r: CGFloat, color: UIColor) -> SCNGeometry {
        let key = "S:\(r)-\(colorKey(color))"
        if let g = lodSphereCache[key] { return g }
        
        let hi = SCNSphere(radius: r); hi.segmentCount = 32
        let md = SCNSphere(radius: r); md.segmentCount = 16
        let lo = SCNSphere(radius: r); lo.segmentCount = 8
        
        let mat = material(color: color)
        [hi, md, lo].forEach { $0.firstMaterial = mat }
        
        let g = SCNSphere(radius: r)
        g.levelsOfDetail = [
            SCNLevelOfDetail(geometry: hi, screenSpaceRadius: 40.0),
            SCNLevelOfDetail(geometry: md, screenSpaceRadius: 20.0),
            SCNLevelOfDetail(geometry: lo, screenSpaceRadius: 8.0),
        ]
        g.firstMaterial = mat
        lodSphereCache[key] = g
        return g
    }
    
    // Cylinders have different heights for each bond, making reuse difficult.
    // Cache "unit cylinder (height=1)" and scale each bond with scale.y = distance.
    func unitLodCylinder(radius r: CGFloat, color: UIColor) -> SCNGeometry {
        let key = "C:\(r)-\(colorKey(color))"
        if let g = lodCylinderCache[key] { return g }
        
        let hi = SCNCylinder(radius: r, height: 1); hi.radialSegmentCount = 16
        let md = SCNCylinder(radius: r, height: 1); md.radialSegmentCount = 8
        let lo = SCNCylinder(radius: r, height: 1); lo.radialSegmentCount = 6
        
        let mat = material(color: color)
        [hi, md, lo].forEach { $0.firstMaterial = mat }
        
        let g = SCNCylinder(radius: r, height: 1)
        g.levelsOfDetail = [
            SCNLevelOfDetail(geometry: hi, screenSpaceRadius: 30.0),
            SCNLevelOfDetail(geometry: md, screenSpaceRadius: 15.0),
            SCNLevelOfDetail(geometry: lo, screenSpaceRadius: 6.0),
        ]
        g.firstMaterial = mat
        lodCylinderCache[key] = g
        return g
    }
    
    func clearCache() {
        lodSphereCache.removeAll()
        lodCylinderCache.removeAll()
        materialByColor.removeAll()
    }
}

enum RenderStyle: String, CaseIterable { 
    case spheres = "Spheres"
    case sticks = "Sticks" 
    case cartoon = "Cartoon"
    case surface = "Surface"
    
    var icon: String {
        switch self {
        case .spheres: return "circle.fill"
        case .sticks: return "line.3.horizontal"
        case .cartoon: return "waveform.path"
        case .surface: return "globe"
        }
    }
}

enum ColorMode: String, CaseIterable { 
    case element = "Element"
    case chain = "Chain" 
    case uniform = "Uniform"
    case secondaryStructure = "Secondary Structure"
    
    var icon: String {
        switch self {
        case .element: return "atom"
        case .chain: return "link"
        case .uniform: return "paintbrush"
        case .secondaryStructure: return "dna"
        }
    }
}

enum InfoTabType: String, CaseIterable {
    case overview = "Overview"
    case chains = "Chains"
    case residues = "Residues"
    case ligands = "Ligands"
    case pockets = "Pockets"
    case sequence = "Sequence"
    case annotations = "Annotations"
}

enum ViewMode {
    case viewer
    case info
}

enum FocusedElement: Equatable {
    case chain(String)
    case ligand(String)
    case pocket(String)
    case atom(Int)
    
    var displayName: String {
        switch self {
        case .chain(let chainId):
            return "Chain \(chainId)"
        case .ligand(let ligandName):
            return "Ligand \(ligandName)"
        case .pocket(let pocketName):
            return "Pocket \(pocketName)"
        case .atom(let atomId):
            return "Atom \(atomId)"
        }
    }
}

struct ProteinSceneContainer: View {
    let structure: PDBStructure?
    let proteinId: String?
    let proteinName: String?
    let onProteinLibraryTap: (() -> Void)?
    
    @State private var selectedStyle: RenderStyle = .spheres
    @State private var selectedColorMode: ColorMode = .element
    @State private var selectedTab: InfoTabType = .overview
    @State private var viewMode: ViewMode = .info
    @State private var showAdvancedControls = false
    @State private var showInfoBar = true
    
    // Chain highlight state management
    @State private var highlightedChains: Set<String> = []
    @State private var highlightedLigands: Set<String> = []
    @State private var highlightedPockets: Set<String> = []
    
    // Focus state management (enabled for testing)
    @State private var enableFocusFeature: Bool = true
    @State private var focusedElement: FocusedElement? = nil
    @State private var isFocused: Bool = false
    
    var body: some View {
        ZStack {
            if viewMode == .viewer {
                ProteinSceneView(
                    structure: structure,
                    style: selectedStyle,
                    colorMode: selectedColorMode,
                    uniformColor: .systemBlue,
                    autoRotate: false,
                    isInfoMode: false,
                    showInfoBar: $showInfoBar,
                    highlightedChains: highlightedChains,
                    highlightedLigands: highlightedLigands,
                    highlightedPockets: highlightedPockets,
                    focusedElement: focusedElement,
                    onFocusRequest: { element in
                        focusedElement = element
                        isFocused = true
                    }
                )
                .ignoresSafeArea()
                
                // Viewer mode overlay
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        // Simplified navigation header
                        HStack {
                            Button(action: {
                                viewMode = .info
                            }) {
                                Text("Back")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Title centered
                            VStack(spacing: 2) {
                                if let id = proteinId {
                                    Text(id)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                if let name = proteinName {
                                    Text(name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(name.count > 40 ? 1 : 2)  // 동적 길이 조정
                                        .truncationMode(.tail)               // "..." 표시
                                        .minimumScaleFactor(0.9)             // 필요시 텍스트 크기 축소
                                        .multilineTextAlignment(.center)     // 중앙 정렬
                                }
                            }
                            
                            Spacer()
                            
                            // Settings or additional functionality
                            Button(action: {
                                // Settings action
                            }) {
                                Image(systemName: "gear")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
                    }
                }
                .overlay(alignment: .bottom) {
                    // Tab-based control layout
                    TabBasedViewerControls(
                        selectedStyle: $selectedStyle,
                        selectedColorMode: $selectedColorMode
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
        } else {
                // Info mode
                VStack(spacing: 0) {
                    // Fixed header with navigation and tabs
                    VStack(spacing: 0) {
                        // Info mode header
                        HStack {
                            Button(action: {
                                // Back to previous screen action
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 2) {
                                if let id = proteinId {
                                    Text(id)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                if let name = proteinName {
                                    Text(name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(name.count > 40 ? 1 : 2)  // 동적 길이 조정
                                        .truncationMode(.tail)               // "..." 표시
                                        .minimumScaleFactor(0.9)             // 필요시 텍스트 크기 축소
                                        .multilineTextAlignment(.center)     // 중앙 정렬
                                }
                            }
                            
                            Spacer()
                            
                            if let onProteinLibraryTap = onProteinLibraryTap {
                                Button(action: onProteinLibraryTap) {
                                    Text("Library")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Button(action: {
                                viewMode = .viewer
                            }) {
                                Image(systemName: "eye")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                                                    .padding(.horizontal, 16)
                            .padding(.top, 44) // 시스템 상태바 높이
                            .padding(.bottom, 8)
                            .background(.ultraThinMaterial)
                        
                        // Info tab buttons with clear highlights button
                        HStack {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(InfoTabType.allCases, id: \.self) { tab in
                                        InfoTabButton(
                                            title: tab.rawValue,
                                            isSelected: selectedTab == tab
                                        ) {
                                            selectedTab = tab
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Focus status indicator
                            if let focusElement = focusedElement {
                                HStack(spacing: 4) {
                                    Image(systemName: "scope.fill")
                                        .foregroundColor(.green)
                                    Text("Focused: \(focusElement.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // Clear highlights and focus button
                            if !highlightedChains.isEmpty || !highlightedLigands.isEmpty || !highlightedPockets.isEmpty || isFocused {
                                Button(action: {
                                    highlightedChains.removeAll()
                                    highlightedLigands.removeAll()
                                    highlightedPockets.removeAll()
                                    focusedElement = nil
                                    isFocused = false
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Clear")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .cornerRadius(12)
                                }
                                .padding(.trailing, 16)
                            }
                        }
                        .padding(.bottom, 8)
                        .background(.ultraThinMaterial)
                        .overlay(Divider(), alignment: .bottom)
                                            }
                    
                    // 3D Structure Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3D Structure Preview")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        if let structure = structure {
                            ProteinSceneView(
                                structure: structure,
                                style: selectedStyle,
                                colorMode: selectedColorMode,
                                uniformColor: .systemBlue,
                                autoRotate: false,
                                isInfoMode: true,
                                showInfoBar: .constant(false),
                                highlightedChains: highlightedChains,
                                highlightedLigands: highlightedLigands,
                                highlightedPockets: highlightedPockets,
                                focusedElement: focusedElement,
                                onFocusRequest: { element in
                                    focusedElement = element
                                    isFocused = true
                                }
                            )
                            .frame(height: 200)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(.systemBackground))
                    
                    // Scrollable tab content area below fixed elements
                    ScrollView {
                        VStack(spacing: 16) {
                            if let structure = structure {
                                switch selectedTab {
                                case .overview:
                                    overviewContent(structure: structure)
                                case .chains:
                                    chainsContent(structure: structure)
                                case .residues:
                                    residuesContent(structure: structure)
                                case .ligands:
                                    ligandsContent(structure: structure)
                                case .pockets:
                                    pocketsContent(structure: structure)
                                case .sequence:
                                    sequenceContent(structure: structure)
                                case .annotations:
                                    annotationsContent(structure: structure)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .background(Color(.systemBackground))
                                    }
                    .background(Color(.systemBackground))
                    .ignoresSafeArea(.all, edges: .top)
            }
        }
        .background(Color(.systemBackground))
    }
    
    // Content functions
    private func overviewContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Basic statistics with enhanced information
            HStack(spacing: 16) {
                StatCard(title: "Atoms", value: "\(structure.atoms.count)", color: .blue)
                StatCard(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", color: .green)
                StatCard(title: "Residues", value: "\(Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count)", color: .orange)
            }
            
            // Structure Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Structure Information")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "PDB ID", value: proteinId ?? "Unknown", description: "Protein Data Bank identifier - unique code for this structure")
                    InfoRow(title: "Total Atoms", value: "\(structure.atoms.count)", description: "All atoms in the structure including protein and ligands")
                    InfoRow(title: "Total Bonds", value: "\(structure.bonds.count)", description: "Chemical bonds connecting atoms in the structure")
                    InfoRow(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", description: "Number of polypeptide chains in the protein")
                    
                    let uniqueElements = Set(structure.atoms.map { $0.element })
                    InfoRow(title: "Elements", value: "\(uniqueElements.count)", description: "Number of different chemical elements present")
                    
                    let elementTypes = Array(uniqueElements).sorted().joined(separator: ", ")
                    InfoRow(title: "Element Types", value: elementTypes, description: "Chemical elements found in this structure")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Chemical Composition
            VStack(alignment: .leading, spacing: 12) {
                Text("Chemical Composition")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueResidues = Set(structure.atoms.map { $0.residueName })
                    InfoRow(title: "Residue Types", value: "\(uniqueResidues.count)", description: "Number of different amino acid types present")
                    
                    let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
                    InfoRow(title: "Total Residues", value: "\(totalResidues)", description: "Total number of amino acid residues across all chains")
                    
                    let chainList = Array(Set(structure.atoms.map { $0.chain })).sorted()
                    InfoRow(title: "Chain IDs", value: chainList.joined(separator: ", "), description: "Identifiers for each polypeptide chain")
                    
                    let hasLigands = structure.atoms.contains { $0.isLigand }
                    InfoRow(title: "Ligands", value: hasLigands ? "Present" : "None", description: hasLigands ? "Small molecules or ions bound to the protein" : "No small molecules detected in this structure")
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Experimental Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Experimental Details")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "Structure Type", value: "Protein", description: "This is a protein structure determined by experimental methods")
                    InfoRow(title: "Data Source", value: "PDB", description: "Protein Data Bank - worldwide repository of 3D structure data")
                    InfoRow(title: "Quality", value: "Experimental", description: "Structure determined through experimental techniques like X-ray crystallography")
                    
                    if let firstAtom = structure.atoms.first {
                        InfoRow(title: "First Residue", value: firstAtom.residueName, description: "Chain \(firstAtom.chain)")
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func chainsContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            let chains = Set(structure.atoms.map { $0.chain })
            
            ForEach(Array(chains).sorted(), id: \.self) { chain in
                let chainAtoms = structure.atoms.filter { $0.chain == chain }
                let residues = Set(chainAtoms.map { "\($0.chain):\($0.residueNumber)" })
                let uniqueResidues = Set(chainAtoms.map { $0.residueName })
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chain \(chain)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Chain overview
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Length")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(residues.count) residues")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(chainAtoms.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Residue Types")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(uniqueResidues.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    
                    // Sequence information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sequence Information")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        let sortedResidues = Array(Set(chainAtoms.map { $0.residueNumber })).sorted()
                        let sequence = sortedResidues.map { resNum in
                            let resName = chainAtoms.first { $0.residueNumber == resNum }?.residueName ?? "X"
                            return residue3to1(resName)
                        }.joined()
                        
                        Text("Length: \(sequence.count) amino acids")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(sequence)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Structural characteristics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Structural Characteristics")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        let backboneAtoms = chainAtoms.filter { $0.isBackbone }
                        let sidechainAtoms = chainAtoms.filter { !$0.isBackbone }
                        
                        HStack {
                            Text("Backbone atoms: \(backboneAtoms.count)")
                                .font(.caption)
                            Spacer()
                            Text("Side chain atoms: \(sidechainAtoms.count)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        // Secondary structure elements
                        let helixAtoms = chainAtoms.filter { $0.secondaryStructure == .helix }
                        let sheetAtoms = chainAtoms.filter { $0.secondaryStructure == .sheet }
                        let coilAtoms = chainAtoms.filter { $0.secondaryStructure == .coil }
                        
                        HStack {
                            Text("α-helix: \(helixAtoms.count) atoms")
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                            Text("β-sheet: \(sheetAtoms.count) atoms")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Spacer()
                            Text("Coil: \(coilAtoms.count) atoms")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Interactive buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            // Toggle chain highlight
                            if highlightedChains.contains(chain) {
                                highlightedChains.remove(chain)
                            } else {
                                highlightedChains.insert(chain)
                            }
                        }) {
                            HStack {
                                Image(systemName: highlightedChains.contains(chain) ? "highlighter.fill" : "highlighter")
                                Text(highlightedChains.contains(chain) ? "Unhighlight" : "Highlight")
                            }
                            .font(.caption)
                            .foregroundColor(highlightedChains.contains(chain) ? .white : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(highlightedChains.contains(chain) ? Color.blue : Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Button(action: {
                            // Toggle chain focus
                            if let currentFocus = focusedElement,
                               case .chain(let currentChain) = currentFocus,
                               currentChain == chain {
                                // Unfocus if already focused on this chain
                                focusedElement = nil
                                isFocused = false
                            } else {
                                // Focus on this chain
                                focusedElement = .chain(chain)
                                isFocused = true
                            }
                        }) {
                            let isCurrentlyFocused = {
                                if let currentFocus = focusedElement,
                                   case .chain(let currentChain) = currentFocus {
                                    return currentChain == chain
                                }
                                return false
                            }()
                            
                            HStack {
                                Image(systemName: isCurrentlyFocused ? "scope.fill" : "scope")
                                Text(isCurrentlyFocused ? "Unfocus" : "Focus")
                            }
                            .font(.caption)
                            .foregroundColor(isCurrentlyFocused ? .white : .green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isCurrentlyFocused ? Color.green : Color.green.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func residuesContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Residue composition overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Residue Composition")
                    .font(.headline)
                
                let residueCounts = Dictionary(grouping: structure.atoms, by: { $0.residueName })
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }
                
                let totalResidues = residueCounts.map { $0.value }.reduce(0, +)
                
                VStack(spacing: 8) {
                    ForEach(Array(residueCounts.prefix(15)), id: \.key) { residue, count in
                        HStack {
                            Text(residue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .leading)
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            Spacer()
                            
                            let percentage = Double(count) / Double(totalResidues) * 100
                            Rectangle()
                                .fill(residueColor(residue))
                                .frame(width: CGFloat(percentage) * 3, height: 20)
                                .cornerRadius(4)
                            
                            Text("\(String(format: "%.1f", percentage))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Physical-chemical properties
            VStack(alignment: .leading, spacing: 12) {
                Text("Physical-Chemical Properties")
                    .font(.headline)
                
                let hydrophobicResidues = ["ALA", "VAL", "ILE", "LEU", "MET", "PHE", "TRP", "PRO"]
                let polarResidues = ["SER", "THR", "ASN", "GLN", "TYR", "CYS"]
                let chargedResidues = ["LYS", "ARG", "HIS", "ASP", "GLU"]
                
                let hydrophobicCount = structure.atoms.filter { hydrophobicResidues.contains($0.residueName) }.count
                let polarCount = structure.atoms.filter { polarResidues.contains($0.residueName) }.count
                let chargedCount = structure.atoms.filter { chargedResidues.contains($0.residueName) }.count
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Hydrophobic")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(hydrophobicCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Polar")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(polarCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Charged")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(chargedCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Structural roles
            VStack(alignment: .leading, spacing: 12) {
                Text("Structural Roles")
                    .font(.headline)
                
                let backboneAtoms = structure.atoms.filter { $0.isBackbone }
                let sidechainAtoms = structure.atoms.filter { !$0.isBackbone }
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Backbone")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                        Spacer()
                        Text("\(backboneAtoms.count) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Side Chain")
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("\(sidechainAtoms.count) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // Helper function for residue color coding
    private func residueColor(_ residue: String) -> Color {
        let hydrophobicResidues = ["ALA", "VAL", "ILE", "LEU", "MET", "PHE", "TRP", "PRO"]
        let polarResidues = ["SER", "THR", "ASN", "GLN", "TYR", "CYS"]
        let chargedResidues = ["LYS", "ARG", "HIS", "ASP", "GLU"]
        
        if hydrophobicResidues.contains(residue) {
            return .orange
        } else if polarResidues.contains(residue) {
            return .blue
        } else if chargedResidues.contains(residue) {
            return .red
        } else {
            return .gray
        }
    }
    
    private func ligandsContent(structure: PDBStructure) -> some View {
                                    VStack(spacing: 16) {
            let ligands = structure.atoms.filter { $0.isLigand }
            let ligandGroups = Dictionary(grouping: ligands, by: { $0.residueName })
            
            if ligands.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "molecule")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Ligands Detected")
                                            .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This structure does not contain any small molecules or ions bound to the protein.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Ligand overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ligand Overview")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Ligands")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(ligandGroups.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(ligands.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Individual ligands
                ForEach(Array(ligandGroups.keys).sorted(), id: \.self) { ligandName in
                    let ligandAtoms = ligandGroups[ligandName] ?? []
                    let uniqueChains = Set(ligandAtoms.map { $0.chain })
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ligandName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Ligand information
                        VStack(spacing: 8) {
                            HStack {
                                Text("Atoms")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(ligandAtoms.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Chains")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Array(uniqueChains).sorted().joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // Element composition
                            let elementCounts = Dictionary(grouping: ligandAtoms, by: { $0.element })
                                .mapValues { $0.count }
                                .sorted { $0.value > $1.value }
                            
                            HStack {
                                Text("Elements")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(elementCounts.map { "\($0.key)\($0.value)" }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Binding information
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Binding Information")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("Binding Sites")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(uniqueChains.count) chain(s)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Molecular Weight")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("~\(ligandAtoms.count * 12) Da")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Interactive buttons
                            HStack(spacing: 12) {
                            Button(action: {
                                // Toggle ligand highlight
                                if highlightedLigands.contains(ligandName) {
                                    highlightedLigands.remove(ligandName)
                                } else {
                                    highlightedLigands.insert(ligandName)
                                }
                            }) {
                                HStack {
                                    Image(systemName: highlightedLigands.contains(ligandName) ? "highlighter.fill" : "highlighter")
                                    Text(highlightedLigands.contains(ligandName) ? "Unhighlight" : "Highlight")
                                }
                                .font(.caption)
                                .foregroundColor(highlightedLigands.contains(ligandName) ? .white : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(highlightedLigands.contains(ligandName) ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                // Toggle ligand focus
                                if let currentFocus = focusedElement,
                                   case .ligand(let currentLigand) = currentFocus,
                                   currentLigand == ligandName {
                                    // Unfocus if already focused on this ligand
                                    focusedElement = nil
                                    isFocused = false
                                } else {
                                    // Focus on this ligand
                                    focusedElement = .ligand(ligandName)
                                    isFocused = true
                                }
                            }) {
                                let isCurrentlyFocused = {
                                    if let currentFocus = focusedElement,
                                       case .ligand(let currentLigand) = currentFocus {
                                        return currentLigand == ligandName
                                    }
                                    return false
                                }()
                                
                                HStack {
                                    Image(systemName: isCurrentlyFocused ? "scope.fill" : "scope")
                                    Text(isCurrentlyFocused ? "Unfocus" : "Focus")
                                }
                                .font(.caption)
                                .foregroundColor(isCurrentlyFocused ? .white : .green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isCurrentlyFocused ? Color.green : Color.green.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func pocketsContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            let pockets = structure.atoms.filter { $0.isPocket }
            let pocketGroups = Dictionary(grouping: pockets, by: { $0.residueName })
            
            if pockets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Binding Pockets Detected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This structure does not contain any identified binding pockets or active sites.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Pocket overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Binding Pocket Overview")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Pockets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pocketGroups.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pockets.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
                
                // Individual pockets
                ForEach(Array(pocketGroups.keys).sorted(), id: \.self) { pocketName in
                    let pocketAtoms = pocketGroups[pocketName] ?? []
                    let uniqueChains = Set(pocketAtoms.map { $0.chain })
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(pocketName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Pocket information
                        VStack(spacing: 8) {
                    HStack {
                                Text("Atoms")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                        Spacer()
                                Text("\(pocketAtoms.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Chains")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Array(uniqueChains).sorted().joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // Element composition
                            let elementCounts = Dictionary(grouping: pocketAtoms, by: { $0.element })
                                .mapValues { $0.count }
                                .sorted { $0.value > $1.value }
                            
                            HStack {
                                Text("Elements")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(elementCounts.map { "\($0.key)\($0.value)" }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Pocket characteristics
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pocket Characteristics")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("Accessibility")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                    Spacer()
                                Text("Surface exposed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Size")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(pocketAtoms.count) atoms")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Depth")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Medium")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Functional importance
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Functional Importance")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("Binding Potential")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("High")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Conservation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Unknown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Interactive buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                // Toggle pocket highlight
                                if highlightedPockets.contains(pocketName) {
                                    highlightedPockets.remove(pocketName)
                                } else {
                                    highlightedPockets.insert(pocketName)
                                }
                            }) {
                                HStack {
                                    Image(systemName: highlightedPockets.contains(pocketName) ? "highlighter.fill" : "highlighter")
                                    Text(highlightedPockets.contains(pocketName) ? "Unhighlight" : "Highlight")
                                }
                                .font(.caption)
                                .foregroundColor(highlightedPockets.contains(pocketName) ? .white : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(highlightedPockets.contains(pocketName) ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                // Toggle pocket focus
                                if let currentFocus = focusedElement,
                                   case .pocket(let currentPocket) = currentFocus,
                                   currentPocket == pocketName {
                                    // Unfocus if already focused on this pocket
                                    focusedElement = nil
                                    isFocused = false
                                } else {
                                    // Focus on this pocket
                                    focusedElement = .pocket(pocketName)
                                    isFocused = true
                                }
                            }) {
                                let isCurrentlyFocused = {
                                    if let currentFocus = focusedElement,
                                       case .pocket(let currentPocket) = currentFocus {
                                        return currentPocket == pocketName
                                    }
                                    return false
                                }()
                                
                                HStack {
                                    Image(systemName: isCurrentlyFocused ? "scope.fill" : "scope")
                                    Text(isCurrentlyFocused ? "Unfocus" : "Focus")
                                }
                                .font(.caption)
                                .foregroundColor(isCurrentlyFocused ? .white : .green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isCurrentlyFocused ? Color.green : Color.green.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func sequenceContent(structure: PDBStructure) -> some View {
        let chains = Set(structure.atoms.map { $0.chain })
        let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
        
        return VStack(spacing: 16) {
            // Sequence overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Sequence Overview")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chains")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(chains.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Residues")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalResidues)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Individual chain sequences
            ForEach(Array(chains).sorted(), id: \.self) { chain in
                let chainAtoms = structure.atoms
                    .filter { $0.chain == chain }
                    .sorted { $0.residueNumber < $1.residueNumber }
                
                let uniqueResidues = Array(Set(chainAtoms.map { $0.residueNumber })).sorted()
                let sequence = uniqueResidues.map { resNum in
                    let resName = chainAtoms.first { $0.residueNumber == resNum }?.residueName ?? "X"
                    return residue3to1(resName)
                }.joined()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chain \(chain) Sequence")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Sequence information
                    HStack {
                        Text("Length: \(sequence.count) amino acids")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Residues: \(uniqueResidues.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Full sequence display
                    ScrollView {
                        Text(sequence)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                    
                    // Sequence composition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sequence Composition")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        let chainResidues = chainAtoms.map { $0.residueName }
                        let composition = Dictionary(grouping: chainResidues, by: { $0 })
                            .mapValues { $0.count }
                            .sorted { $0.value > $1.value }
                        
                        ForEach(Array(composition.prefix(10)), id: \.key) { residue, count in
                            HStack {
                                Text(residue)
                                    .font(.caption)
                                    .frame(width: 50, alignment: .leading)
                                
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                Spacer()
                                
                                let percentage = Double(count) / Double(chainResidues.count) * 100
                                Rectangle()
                                    .fill(residueColor(residue))
                                    .frame(width: CGFloat(percentage) * 2, height: 16)
                                    .cornerRadius(2)
                                
                                Text("\(String(format: "%.1f", percentage))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Overall sequence analysis
            VStack(alignment: .leading, spacing: 12) {
                Text("Overall Sequence Analysis")
                    .font(.headline)
                
                let allResidues = structure.atoms.map { $0.residueName }
                let composition = Dictionary(grouping: allResidues, by: { $0 })
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }
                
                // Most common residues
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Common Residues")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(composition.prefix(5)), id: \.key) { residue, count in
                        HStack {
                            Text(residue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .leading)
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            Spacer()
                            
                            let percentage = Double(count) / Double(allResidues.count) * 100
                            Rectangle()
                                .fill(residueColor(residue))
                                .frame(width: CGFloat(percentage) * 3, height: 20)
                                .cornerRadius(4)
                            
                            Text("\(String(format: "%.1f", percentage))%")
                    .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // Sequence statistics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sequence Statistics")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Unique Residue Types")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(composition.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Average Residue Frequency")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", Double(allResidues.count) / Double(composition.count)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func annotationsContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Structure Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Structure Information")
                    .font(.headline)
                
            VStack(spacing: 8) {
                    InfoRow(title: "PDB ID", value: proteinId ?? "Unknown", description: "Protein Data Bank identifier - unique code for this structure")
                    InfoRow(title: "Total Atoms", value: "\(structure.atoms.count)", description: "All atoms in the structure including protein and ligands")
                    InfoRow(title: "Total Bonds", value: "\(structure.bonds.count)", description: "Chemical bonds connecting atoms in the structure")
                    InfoRow(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", description: "Number of polypeptide chains in the protein")
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // Chemical Composition
            VStack(alignment: .leading, spacing: 12) {
                Text("Chemical Composition")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueElements = Set(structure.atoms.map { $0.element })
                    InfoRow(title: "Elements", value: "\(uniqueElements.count)", description: "Number of different chemical elements present")
                    
                    let elementList = Array(uniqueElements).sorted().joined(separator: ", ")
                    InfoRow(title: "Element Types", value: elementList, description: "Chemical elements found in this structure")
                    
                    let chainList = Array(Set(structure.atoms.map { $0.chain })).sorted()
                    InfoRow(title: "Chain IDs", value: chainList.joined(separator: ", "), description: "Identifiers for each polypeptide chain")
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // Protein Classification
            VStack(alignment: .leading, spacing: 12) {
                Text("Protein Classification")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueResidues = Set(structure.atoms.map { $0.residueName })
                    InfoRow(title: "Residue Types", value: "\(uniqueResidues.count)", description: "Number of different amino acid types present")
                    
                    let residueList = Array(uniqueResidues).sorted().joined(separator: ", ")
                    InfoRow(title: "Residue Names", value: residueList, description: "Three-letter codes of amino acids in this protein")
                    
                    let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
                    InfoRow(title: "Total Residues", value: "\(totalResidues)", description: "Total number of amino acid residues across all chains")
                }
            }
            .padding()
            .background(Color.cyan.opacity(0.1))
            .cornerRadius(12)
            
            // Biological Context
            VStack(alignment: .leading, spacing: 12) {
                Text("Biological Context")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "Structure Type", value: "Protein", description: "This is a protein structure determined by experimental methods")
                    InfoRow(title: "Data Source", value: "PDB", description: "Protein Data Bank - worldwide repository of 3D structure data")
                    InfoRow(title: "Quality", value: "Experimental", description: "Structure determined through experimental techniques like X-ray crystallography")
                    
                    let hasLigands = structure.atoms.contains { $0.isLigand }
                    InfoRow(title: "Ligands", value: hasLigands ? "Present" : "None", description: hasLigands ? "Small molecules or ions bound to the protein" : "No small molecules detected in this structure")
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Show original annotations if available
            if !structure.annotations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Additional Annotations")
                        .font(.headline)
                    
                    ForEach(structure.annotations, id: \.type) { annotation in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(annotation.type.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(annotation.value)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !annotation.description.isEmpty {
                                Text(annotation.description)
                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // Helper function for amino acid conversion
    private func residue3to1(_ code: String) -> String {
        switch code.uppercased() {
        case "ALA": return "A"
        case "ARG": return "R"
        case "ASN": return "N"
        case "ASP": return "D"
        case "CYS": return "C"
        case "GLN": return "Q"
        case "GLU": return "E"
        case "GLY": return "G"
        case "HIS": return "H"
        case "ILE": return "I"
        case "LEU": return "L"
        case "LYS": return "K"
        case "MET": return "M"
        case "PHE": return "F"
        case "PRO": return "P"
        case "SER": return "S"
        case "THR": return "T"
        case "TRP": return "W"
        case "TYR": return "Y"
        case "VAL": return "V"
        default: return "X"
        }
    }
    

}

struct ProteinSceneView: UIViewRepresentable {
    let structure: PDBStructure?
    let style: RenderStyle
    let colorMode: ColorMode
    let uniformColor: UIColor
    let autoRotate: Bool
    let isInfoMode: Bool
    var showInfoBar: Binding<Bool>? = nil
    var onSelectAtom: ((Atom) -> Void)? = nil
    
    // Highlight parameters
    let highlightedChains: Set<String>
    let highlightedLigands: Set<String>
    let highlightedPockets: Set<String>
    
    // Focus parameters
    let focusedElement: FocusedElement?
    var onFocusRequest: ((FocusedElement) -> Void)? = nil

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        rebuild(view: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Always rebuild for now to maintain existing functionality
        // Focus feature is disabled by default for safety
        rebuild(view: uiView)
        
        // Focus functionality will be added later when needed
        // For now, just maintain existing functionality
        
        if autoRotate {
            let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8.0)
            let repeatAction = SCNAction.repeatForever(rotateAction)
            uiView.scene?.rootNode.runAction(repeatAction, forKey: "autoRotate")
        } else {
            uiView.scene?.rootNode.removeAction(forKey: "autoRotate")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // Improved rebuild method for ProteinSceneView
    private func rebuild(view: SCNView) {
        let scene = SCNScene()
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }

        // Improved lighting setup
        setupLighting(scene: scene)

        if let structure = structure {
            print("Creating protein node with \(structure.atoms.count) atoms and \(structure.bonds.count) bonds")
            
            let proteinNode = createProteinNode(from: structure)
            scene.rootNode.addChildNode(proteinNode)
            
            // Calculate bounds based on focus state
            let (center, boundingSize): (SCNVector3, Float)
            if let focusElement = focusedElement {
                (center, boundingSize) = calculateFocusBounds(structure: structure, focusElement: focusElement)
                print("Focus bounds - center: \(center), size: \(boundingSize)")
            } else {
                (center, boundingSize) = calculateProteinBounds(structure: structure)
                print("Protein center: \(center), bounding size: \(boundingSize)")
            }
            
            // Move protein to origin
            proteinNode.position = SCNVector3(-center.x, -center.y, -center.z)
            
            // Improved camera setup
            setupCamera(scene: scene, view: view, boundingSize: boundingSize)
            
        } else {
            print("No structure provided to ProteinSceneView")
            // Default camera setup
            setupDefaultCamera(scene: scene, view: view)
        }

        view.scene = scene
    }

    private func createProteinNode(from structure: PDBStructure) -> SCNNode {
        let rootNode = SCNNode()
        
        print("Creating \(structure.atoms.count) atoms...")
        
        // Create atoms
        for (index, atom) in structure.atoms.enumerated() {
            let atomNode = createAtomNode(atom)
            rootNode.addChildNode(atomNode)
            
            if index < 5 { // Log first 5 atoms for debugging
                print("Atom \(index): \(atom.element) at position \(atom.position)")
            }
        }
        
        print("Creating \(structure.bonds.count) bonds...")
        
        // Create bonds
        for (index, bond) in structure.bonds.enumerated() {
            let bondNode = createBondNode(bond, atoms: structure.atoms)
            rootNode.addChildNode(bondNode)
            
            if index < 5 { // Log first 5 bonds for debugging
                print("Bond \(index): \(bond.atomA) - \(bond.atomB)")
            }
        }
        
        return rootNode
    }
    
    // Improved bounding box calculation
    private func calculateProteinBounds(structure: PDBStructure) -> (center: SCNVector3, size: Float) {
        guard !structure.atoms.isEmpty else {
            return (SCNVector3Zero, 10.0)
        }
        
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        for atom in structure.atoms {
            minX = min(minX, atom.position.x)
            maxX = max(maxX, atom.position.x)
            minY = min(minY, atom.position.y)
            maxY = max(maxY, atom.position.y)
            minZ = min(minZ, atom.position.z)
            maxZ = max(maxZ, atom.position.z)
        }
        
        let center = SCNVector3(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )
        
        let sizeX = maxX - minX
        let sizeY = maxY - minY
        let sizeZ = maxZ - minZ
        let maxSize = max(sizeX, max(sizeY, sizeZ))
        
        return (center, maxSize)
    }
    
    // Focus-specific bounding box calculations
    private func calculateFocusBounds(structure: PDBStructure, focusElement: FocusedElement) -> (center: SCNVector3, size: Float) {
        let atoms: [Atom]
        
        switch focusElement {
        case .chain(let chainId):
            atoms = structure.atoms.filter { $0.chain == chainId }
        case .ligand(let ligandName):
            atoms = structure.atoms.filter { $0.residueName == ligandName }
        case .pocket(let pocketName):
            atoms = structure.atoms.filter { $0.residueName == pocketName }
        case .atom(let atomId):
            atoms = structure.atoms.filter { $0.id == atomId }
        }
        
        guard !atoms.isEmpty else {
            return calculateProteinBounds(structure: structure)
        }
        
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        for atom in atoms {
            minX = min(minX, atom.position.x)
            maxX = max(maxX, atom.position.x)
            minY = min(minY, atom.position.y)
            maxY = max(maxY, atom.position.y)
            minZ = min(minZ, atom.position.z)
            maxZ = max(maxZ, atom.position.z)
        }
        
        let center = SCNVector3(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )
        
        let sizeX = maxX - minX
        let sizeY = maxY - minY
        let sizeZ = maxZ - minZ
        let maxSize = max(sizeX, max(sizeY, sizeZ))
        
        return (center, maxSize)
    }
    
    // Improved camera setup
    private func setupCamera(scene: SCNScene, view: SCNView, boundingSize: Float) {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 1000
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        // Calculate appropriate camera distance
        // Info 모드일 때는 카메라를 2배 가깝게 (3.0 → 1.5)하여 이미지를 2배 크게 보이게 함
        let multiplier: Float = isInfoMode ? 1.5 : 3.0
        let baseCameraDistance: Float = max(boundingSize * multiplier, 20.0)
        let cameraDistance = min(baseCameraDistance, 200.0) // Maximum value limit
        
        cameraNode.position = SCNVector3(0, 0, cameraDistance)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        
        print("Camera positioned at distance: \(cameraDistance), bounding size: \(boundingSize), isInfoMode: \(isInfoMode)")
        
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode
    }
    
    // Default camera setup (when no structure is available)
    private func setupDefaultCamera(scene: SCNScene, view: SCNView) {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 1000
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 50)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode
    }
    
    // Separated lighting setup
    private func setupLighting(scene: SCNScene) {
        // Key light (main lighting)
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 800 // Slightly reduced
        keyLight.color = UIColor.white
        keyLight.castsShadow = false // Disable shadows for performance improvement
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(10, 20, 30)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)
        
        // Fill light
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 300
        fillLight.color = UIColor(white: 0.8, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-15, 15, -15)
        scene.rootNode.addChildNode(fillLightNode)
        
        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 200
        ambientLight.color = UIColor(white: 0.4, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
    }
    
    // Improved atom node creation
    private func createAtomNode(_ atom: Atom) -> SCNNode {
        let baseRadius: CGFloat = 1.0 // Smaller base size
        let radius: CGFloat
        let color: UIColor
        
        // Check if atom should be highlighted
        let isHighlighted = highlightedChains.contains(atom.chain) || 
                           highlightedLigands.contains(atom.residueName) || 
                           highlightedPockets.contains(atom.residueName)
        
        // Check if atom is in focus
        let isInFocus = isAtomInFocus(atom)
        
        // Determine opacity based on focus and highlight state
        let opacity: CGFloat
        if isInFocus {
            opacity = 1.0 // Full opacity for focused atoms
        } else if isHighlighted {
            opacity = 0.9 // High opacity for highlighted atoms
        } else if focusedElement != nil {
            opacity = 0.2 // Low opacity for non-focused atoms when something is focused
        } else {
            opacity = 0.4 // Normal opacity when nothing is focused
        }
        
        if isHighlighted {
            // Highlighted atoms: brighter colors and slightly larger
            radius = baseRadius * 1.2 * (atom.element.atomicRadius / 0.7)
            switch colorMode {
            case .element:
                color = atom.element.color.withAlphaComponent(opacity)
            case .chain:
                color = chainColor(for: atom.chain).withAlphaComponent(opacity)
            case .uniform:
                color = uniformColor.withAlphaComponent(opacity)
            case .secondaryStructure:
                color = atom.secondaryStructure.color.withAlphaComponent(opacity)
            }
        } else {
            // Normal atoms: standard colors with appropriate opacity
            radius = baseRadius * (atom.element.atomicRadius / 0.7)
            switch colorMode {
            case .element:
                color = atom.element.color.withAlphaComponent(opacity)
            case .chain:
                color = chainColor(for: atom.chain).withAlphaComponent(opacity)
            case .uniform:
                color = uniformColor.withAlphaComponent(opacity)
            case .secondaryStructure:
                color = atom.secondaryStructure.color.withAlphaComponent(opacity)
            }
        }
        
        // Size adjustment based on style
        let finalRadius = radius * styleSizeMultiplier()
        
        let geometry: SCNGeometry
        switch style {
        case .spheres:
            geometry = GeometryCache.shared.lodSphere(radius: finalRadius, color: color)
        case .sticks:
            geometry = GeometryCache.shared.lodSphere(radius: finalRadius * 0.4, color: color)
        case .cartoon:
            geometry = GeometryCache.shared.lodSphere(radius: finalRadius * 0.6, color: color)
        case .surface:
            geometry = GeometryCache.shared.lodSphere(radius: finalRadius * 0.8, color: color)
        }
        
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(atom.position.x, atom.position.y, atom.position.z)
        node.name = "atom_\(atom.id)"
        
        return node
    }
    
    // Improved bond node creation
    private func createBondNode(_ bond: Bond, atoms: [Atom]) -> SCNNode {
        guard let atom1 = atoms.first(where: { $0.id == bond.atomA }),
              let atom2 = atoms.first(where: { $0.id == bond.atomB }) else {
            return SCNNode()
        }
        
        let start = atom1.position
        let end = atom2.position
        
        // Vector calculation
        let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let distance = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        
        // Skip if distance is too small
        guard distance > 0.01 else { return SCNNode() }
        
        let bondRadius: CGFloat = style == .sticks ? 0.2 : 0.1
        let cylinder = GeometryCache.shared.unitLodCylinder(radius: bondRadius, color: .lightGray)
        let node = SCNNode(geometry: cylinder)
        
        // Midpoint position
        let midPoint = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        node.position = midPoint
        
        // Improved rotation calculation
        let normalizedDirection = SCNVector3(
            direction.x / distance,
            direction.y / distance,
            direction.z / distance
        )
        
        // Calculate angle with Y-axis
        let yAxis = SCNVector3(0, 1, 0)
        let rotationAxis = SCNVector3(
            yAxis.y * normalizedDirection.z - yAxis.z * normalizedDirection.y,
            yAxis.z * normalizedDirection.x - yAxis.x * normalizedDirection.z,
            yAxis.x * normalizedDirection.y - yAxis.y * normalizedDirection.x
        )
        
        let dotProduct = yAxis.y * normalizedDirection.y
        let angle = acos(max(-1, min(1, dotProduct)))
        
        if abs(angle) > 0.001 {
            node.rotation = SCNVector4(rotationAxis.x, rotationAxis.y, rotationAxis.z, angle)
        }
        
        // Apply scale (adjust height only)
        node.scale = SCNVector3(1, distance, 1)
        
        return node
    }
    
    // Style-based size multiplier
    private func styleSizeMultiplier() -> CGFloat {
        switch style {
        case .spheres: return 1.0
        case .sticks: return 0.8
        case .cartoon: return 1.2
        case .surface: return 0.9
        }
    }
    
    // Improved chain-specific color generation
    private func chainColor(for chain: String) -> UIColor {
        let hue = CGFloat(abs(chain.hashValue) % 360) / 360.0
        return UIColor(hue: hue, saturation: 0.7, brightness: 0.8, alpha: 1.0)
    }
    
    // Check if atom is in focus
    private func isAtomInFocus(_ atom: Atom) -> Bool {
        guard let focusElement = focusedElement else { return false }
        
        switch focusElement {
        case .chain(let chainId):
            return atom.chain == chainId
        case .ligand(let ligandName):
            return atom.residueName == ligandName
        case .pocket(let pocketName):
            return atom.residueName == pocketName
        case .atom(let atomId):
            return atom.id == atomId
        }
    }
    
    // Animate camera to focus on specific element
    private func animateCameraToFocus(view: SCNView, target: SCNVector3, boundingSize: Float) {
        guard let camera = view.pointOfView else { return }
        
        // Calculate new camera position
        let distance = boundingSize * 2.5
        let newPosition = SCNVector3(
            target.x,
            target.y + distance * 0.5,
            target.z + distance
        )
        
        // Animate camera movement
        let moveAction = SCNAction.move(to: newPosition, duration: 1.0)
        moveAction.timingMode = .easeInEaseOut
        
        camera.runAction(moveAction)
        
        // Look at target
        let lookAtAction = SCNAction.rotateTo(x: CGFloat(-Float.pi / 6), y: 0, z: 0, duration: 1.0)
        lookAtAction.timingMode = .easeInEaseOut
        camera.runAction(lookAtAction)
    }
    
    // Bounding box visualization for debugging (optional)
    private func addBoundingBoxVisualization(to scene: SCNScene, center: SCNVector3, size: Float) {
        let box = SCNBox(width: CGFloat(size), height: CGFloat(size), length: CGFloat(size), chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red.withAlphaComponent(0.2)
        material.isDoubleSided = true
        box.materials = [material]
        
        let boxNode = SCNNode(geometry: box)
        boxNode.position = SCNVector3(-center.x, -center.y, -center.z)
        scene.rootNode.addChildNode(boxNode)
    }

    class Coordinator: NSObject {
        var parent: ProteinSceneView
        var lastStructure: PDBStructure?
        var lastFocusElement: FocusedElement?
        
        init(parent: ProteinSceneView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let view = gesture.view as! SCNView
            let location = gesture.location(in: view)
            
            let hitResults = view.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .ignoreHiddenNodes: true
            ])
            
            if let result = hitResults.first,
               let nodeName = result.node.name,
               nodeName.hasPrefix("atom_"),
               let atomId = Int(nodeName.replacingOccurrences(of: "atom_", with: "")),
               let atom = parent.structure?.atoms.first(where: { $0.id == atomId }) {
                parent.onSelectAtom?(atom)
            }
        }
    }
}

// MARK: - Improved Control Components
struct ImprovedStylePicker: View {
    @Binding var selectedStyle: RenderStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rendering Style")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RenderStyle.allCases, id: \.self) { style in
                        StyleButton(
                            style: style,
                            isSelected: selectedStyle == style
                        ) {
                            selectedStyle = style
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct StyleButton: View {
    let style: RenderStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: style.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(style.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ImprovedColorModePicker: View {
    @Binding var selectedColorMode: ColorMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Scheme")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        ColorModeButton(
                            mode: mode,
                            isSelected: selectedColorMode == mode
                        ) {
                            selectedColorMode = mode
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct ColorModeButton: View {
    let mode: ColorMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(mode.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Advanced Controls
struct EnhancedAdvancedControlsView: View {
    @Binding var autoRotate: Bool
    @Binding var showBonds: Bool
    @Binding var transparency: Double
    @Binding var atomSize: Double
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    
    // Callbacks for actions
    let onResetView: () -> Void
    let onScreenshot: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Quick Actions Row
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "arrow.clockwise",
                    title: "Reset View",
                    color: .blue
                ) {
                    onResetView()
                }
                
                QuickActionButton(
                    icon: "camera",
                    title: "Screenshot",
                    color: .green
                ) {
                    onScreenshot()
                }
                
                QuickActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    color: .orange
                ) {
                    onShare()
                }
                
                Spacer()
            }
            
            // Detailed Controls
            VStack(spacing: 12) {
                // Auto-rotate toggle
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text("Auto Rotate")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoRotate)
                        .scaleEffect(0.8)
                }
                
                // Show bonds toggle
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    
                    Text("Show Bonds")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $showBonds)
                        .scaleEffect(0.8)
                }
                
                // Transparency slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "opacity")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        
                        Text("Transparency")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(Int(transparency * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $transparency, in: 0.1...1.0)
                        .accentColor(.purple)
                }
                
                // Atom size slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle.grid.cross")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        
                        Text("Atom Size")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(Int(atomSize * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $atomSize, in: 0.5...2.0)
                        .accentColor(.orange)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tab-based Control Layout
struct TabBasedViewerControls: View {
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @State private var selectedTab: ControlTab = .style
    @State private var showAdvancedControls = false
    
    // Advanced controls state
    @State private var autoRotate = false
    @State private var showBonds = true
    @State private var transparency: Double = 1.0
    @State private var atomSize: Double = 1.0
    
    enum ControlTab: String, CaseIterable {
        case style = "Rendering Style"
        case color = "Color Scheme"
        
        var title: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selection
            HStack(spacing: 0) {
                ForEach(ControlTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: selectedTab == tab ? "largecircle.fill.circle" : "circle")
                                .font(.title3)
                                .foregroundColor(selectedTab == tab ? .blue : .gray)
                            
                            Text(tab.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedTab == tab ? .blue : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Selected tab's options
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if selectedTab == .style {
                            ForEach(RenderStyle.allCases, id: \.self) { style in
                                TabOptionButton(
                                    title: style.rawValue,
                                    icon: style.icon,
                                    isSelected: selectedStyle == style,
                                    color: .blue
                                ) {
                                    selectedStyle = style
                                }
                            }
                        } else {
                            ForEach(ColorMode.allCases, id: \.self) { mode in
                                TabOptionButton(
                                    title: mode.rawValue,
                                    icon: mode.icon,
                                    isSelected: selectedColorMode == mode,
                                    color: .green
                                ) {
                                    selectedColorMode = mode
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Advanced controls (collapsible)
                if showAdvancedControls {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    EnhancedAdvancedControlsView(
                        autoRotate: $autoRotate,
                        showBonds: $showBonds,
                        transparency: $transparency,
                        atomSize: $atomSize,
                        selectedStyle: $selectedStyle,
                        selectedColorMode: $selectedColorMode,
                        onResetView: {
                            // Reset camera to default position
                            print("Reset View - Camera position reset")
                        },
                        onScreenshot: {
                            // Take screenshot of 3D view
                            print("Screenshot - Capturing 3D view")
                        },
                        onShare: {
                            // Share protein structure
                            print("Share - Sharing protein structure")
                        }
                    )
                    .transition(.opacity.combined(with: .slide))
                }
            }
            .padding(.bottom, 12)
            
            // Expand/Collapse button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAdvancedControls.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showAdvancedControls ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(showAdvancedControls ? "Less Options" : "More Options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .padding(.top, 8)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TabOptionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legacy UpdatedViewerControls (for backward compatibility)
struct UpdatedViewerControls: View {
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @State private var showAdvancedControls = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main controls panel
            VStack(spacing: 16) {
                // Style and Color pickers in horizontal layout
                HStack(alignment: .top, spacing: 20) {
                    ImprovedStylePicker(selectedStyle: $selectedStyle)
                    ImprovedColorModePicker(selectedColorMode: $selectedColorMode)
                }
                
                // Advanced controls (collapsible)
                if showAdvancedControls {
                    Divider()
                        .padding(.horizontal, -16)
                    
                    EnhancedAdvancedControlsView(
                        autoRotate: .constant(false),
                        showBonds: .constant(true),
                        transparency: .constant(1.0),
                        atomSize: .constant(1.0),
                        selectedStyle: $selectedStyle,
                        selectedColorMode: $selectedColorMode,
                        onResetView: {
                            print("Reset View - Camera position reset")
                        },
                        onScreenshot: {
                            print("Screenshot - Capturing 3D view")
                        },
                        onShare: {
                            print("Share - Sharing protein structure")
                        }
                    )
                    .transition(.opacity.combined(with: .slide))
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // Expand/Collapse button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAdvancedControls.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showAdvancedControls ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(showAdvancedControls ? "Less Options" : "More Options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Legacy UI Components (for backward compatibility)
struct StylePicker: View {
    @Binding var selectedStyle: RenderStyle
    
    var body: some View {
        Picker("Style", selection: $selectedStyle) {
            ForEach(RenderStyle.allCases, id: \.self) { style in
                Label(style.rawValue, systemImage: style.icon)
                    .tag(style)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

struct ColorModePicker: View {
    @Binding var selectedColorMode: ColorMode
    
    var body: some View {
        Picker("Color", selection: $selectedColorMode) {
            ForEach(ColorMode.allCases, id: \.self) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

struct AdvancedControlsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Advanced Controls")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Auto-rotate")
                Spacer()
                Toggle("", isOn: .constant(false))
            }
            .font(.caption)
        }
    }
}

struct InfoTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(20)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
            VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}





// MARK: - Extensions
extension String {
    var atomicRadius: CGFloat {
        switch self.uppercased() {
        case "H": return 0.3
        case "C": return 0.7
        case "N": return 0.65
        case "O": return 0.6
        case "S": return 1.0
        case "P": return 1.0
        default: return 0.8
        }
    }
    
    var color: UIColor {
        switch self.uppercased() {
        case "H": return .white
        case "C": return .gray
        case "N": return .blue
        case "O": return .red
        case "S": return .yellow
        case "P": return .orange
        default: return .purple
        }
    }
}

extension SecondaryStructure {
    var color: UIColor {
        switch self {
        case .helix: return .red
        case .sheet: return .yellow
        case .coil: return .gray
        case .unknown: return .lightGray
        }
    }
}



