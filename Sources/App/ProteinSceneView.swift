import SwiftUI
import SceneKit
import UIKit
import simd

// MARK: - Advanced Geometry Cache for Performance Optimization
final class GeometryCache {
    static let shared = GeometryCache()
    
    // (반경, 색상HEX) → 공유 Geometry
    private var lodSphereCache = [String: SCNGeometry]()
    private var lodCylinderCache = [String: SCNGeometry]()
    private var materialByColor = [UInt32: SCNMaterial]() // 빠른 키
    
    private func colorKey(_ c: UIColor) -> UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        // 8bit RGBA → 32bit 키
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
    
    // 실린더는 높이가 개본 본드마다 달라 재사용이 어렵습니다.
    // "단위 실린더(height=1)"를 캐시하고 각 본드는 scale.y = distance 로 해결하세요.
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
    
    var body: some View {
        ZStack {
            if viewMode == .viewer {
                ProteinSceneView(
                    structure: structure,
                    style: selectedStyle,
                    colorMode: selectedColorMode,
                    uniformColor: .systemBlue,
                    autoRotate: false,
                    showInfoBar: $showInfoBar
                )
                .ignoresSafeArea()
                
                // Viewer mode overlay
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        // Top navigation bar
                        HStack {
                            Button(action: {
                                viewMode = .info
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
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                viewMode = .info
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        
                        // Control panel
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                StylePicker(selectedStyle: $selectedStyle)
                                ColorModePicker(selectedColorMode: $selectedColorMode)
                            }
                            
                            if showAdvancedControls {
                                AdvancedControlsView()
                            }
                            
                            Button(action: {
                                showAdvancedControls.toggle()
                            }) {
                                HStack {
                                    Image(systemName: showAdvancedControls ? "chevron.up" : "chevron.down")
                                    Text(showAdvancedControls ? "Less Options" : "More Options")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                }
        } else {
                // Info mode
                VStack(spacing: 0) {
                    // Fixed header with navigation and tabs
                    VStack(spacing: 0) {
                        // Info mode header
                        HStack {
                            Button(action: {
                                // Back action
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
                        
                        // Info tab buttons
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
                                showInfoBar: .constant(false)
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
                            // Highlight chain action
                        }) {
                            HStack {
                                Image(systemName: "highlighter")
                                Text("Highlight")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Button(action: {
                            // Focus chain action
                        }) {
                            HStack {
                                Image(systemName: "scope")
                                Text("Focus")
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
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
                                // Highlight ligand action
                            }) {
                                HStack {
                                    Image(systemName: "highlighter")
                                    Text("Highlight")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                // Focus ligand action
                            }) {
                                HStack {
                                    Image(systemName: "scope")
                                    Text("Focus")
                                }
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
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
                                // Highlight pocket action
                            }) {
                                HStack {
                                    Image(systemName: "highlighter")
                                    Text("Highlight")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                // Focus pocket action
                            }) {
                                HStack {
                                    Image(systemName: "scope")
                                    Text("Focus")
                                }
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
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
    var showInfoBar: Binding<Bool>? = nil
    var onSelectAtom: ((Atom) -> Void)? = nil

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
        rebuild(view: uiView)
        
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

    private func rebuild(view: SCNView) {
        let scene = SCNScene()
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }

        // Professional lighting setup
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1000
        keyLight.color = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        keyLight.castsShadow = true
        keyLight.shadowRadius = 8
        keyLight.shadowColor = UIColor.black.withAlphaComponent(0.3)
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(20, 30, 40)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)
        
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 400
        fillLight.color = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-20, 20, -20)
        scene.rootNode.addChildNode(fillLightNode)
        
        let rimLight = SCNLight()
        rimLight.type = .directional
        rimLight.intensity = 300
        rimLight.color = UIColor(red: 1.0, green: 1.0, blue: 0.95, alpha: 1.0)
        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(0, -30, 0)
        rimLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLightNode)

        if let structure = structure {
            print("Creating protein node with \(structure.atoms.count) atoms and \(structure.bonds.count) bonds")
            
            let proteinNode = createProteinNode(from: structure)
            scene.rootNode.addChildNode(proteinNode)
            
            // Calculate bounding box and center
            let boundingBox = proteinNode.boundingBox
            let center = SCNVector3(
                (boundingBox.min.x + boundingBox.max.x) / 2,
                (boundingBox.min.y + boundingBox.max.y) / 2,
                (boundingBox.min.z + boundingBox.max.z) / 2
            )
            
            let maxDimension = max(boundingBox.max.x - boundingBox.min.x,
                                 boundingBox.max.y - boundingBox.min.y,
                                 boundingBox.max.z - boundingBox.min.z)
            
            print("Bounding box: min=\(boundingBox.min), max=\(boundingBox.max)")
            print("Center: \(center), maxDimension: \(maxDimension)")
            
            // Center the protein at origin
            proteinNode.position = SCNVector3(-center.x, -center.y, -center.z)
            
            // Set up camera with proper distance
            let camera = SCNCamera()
            camera.fieldOfView = 60
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            
            // Position camera at appropriate distance
            let cameraDistance = max(maxDimension * 2.5, 50.0) // Ensure minimum distance
            cameraNode.position = SCNVector3(0, 0, cameraDistance)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            
            print("Camera positioned at distance: \(cameraDistance)")
            
            scene.rootNode.addChildNode(cameraNode)
            
            // Set the camera as the point of view
            view.pointOfView = cameraNode
        } else {
            print("No structure provided to ProteinSceneView")
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
                print("Bond \(index): \(bond.a) - \(bond.b)")
            }
        }
        
        return rootNode
    }
    
    private func createAtomNode(_ atom: Atom) -> SCNNode {
        let radius: CGFloat
        let color: UIColor
        
        switch colorMode {
        case .element:
            radius = atom.element.atomicRadius * 2.0 // Make atoms larger
            color = atom.element.color
        case .chain:
            radius = 2.0 // Make atoms larger
            color = UIColor(hue: CGFloat(atom.chain.hashValue % 10) / 10.0, saturation: 0.7, brightness: 0.8, alpha: 1.0)
        case .uniform:
            radius = 2.0 // Make atoms larger
            color = uniformColor
        case .secondaryStructure:
            radius = 2.0 // Make atoms larger
            color = atom.secondaryStructure.color
        }
        
        let geometry: SCNGeometry
        switch style {
        case .spheres:
            geometry = GeometryCache.shared.lodSphere(radius: radius, color: color)
        case .sticks:
            geometry = GeometryCache.shared.lodSphere(radius: radius * 0.3, color: color)
        case .cartoon:
            geometry = GeometryCache.shared.lodSphere(radius: radius * 0.5, color: color)
        case .surface:
            geometry = GeometryCache.shared.lodSphere(radius: radius * 0.8, color: color)
        }
        
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(atom.position.x, atom.position.y, atom.position.z)
        node.name = "atom_\(atom.id)"
        
        return node
    }
    
    private func createBondNode(_ bond: Bond, atoms: [Atom]) -> SCNNode {
        guard let atom1 = atoms.first(where: { $0.id == bond.a }),
              let atom2 = atoms.first(where: { $0.id == bond.b }) else {
            return SCNNode()
        }
        
        let start = atom1.position
        let end = atom2.position
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2) + pow(end.z - start.z, 2))
        
        let cylinder = GeometryCache.shared.unitLodCylinder(radius: 0.3, color: .gray) // Make bonds thicker
        let node = SCNNode(geometry: cylinder)
        
        // Position and orient the cylinder
        let midPoint = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
        node.position = midPoint
        
        // Calculate rotation to align with bond direction
        let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let up = SCNVector3(0, 1, 0)
        
        if abs(direction.y) > 0.9 {
            let right = SCNVector3(1, 0, 0)
            let rotationMatrix = SCNMatrix4MakeRotation(Float.pi/2, right.x, right.y, right.z)
            node.transform = SCNMatrix4Mult(SCNMatrix4MakeScale(1, distance, 1), rotationMatrix)
        } else {
            let rotationMatrix = SCNMatrix4MakeRotation(Float.pi/2, up.x, up.y, up.z)
            node.transform = SCNMatrix4Mult(SCNMatrix4MakeScale(1, distance, 1), rotationMatrix)
        }
        
        return node
    }

    class Coordinator: NSObject {
        var parent: ProteinSceneView
        
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

// MARK: - UI Components
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



