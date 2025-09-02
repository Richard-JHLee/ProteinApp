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
            // Basic statistics
            HStack(spacing: 16) {
                StatCard(title: "Atoms", value: "\(structure.atoms.count)", color: .blue)
                StatCard(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", color: .green)
                StatCard(title: "Residues", value: "\(Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count)", color: .orange)
            }
            
            // Protein Information (based on RCSB API data structure)
            VStack(alignment: .leading, spacing: 12) {
                Text("Protein Information")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "Total Atoms", value: "\(structure.atoms.count)", description: "All atoms in structure")
                    InfoRow(title: "Unique Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", description: "Number of polypeptide chains")
                    InfoRow(title: "Residue Count", value: "\(Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count)", description: "Amino acid residues")
                    InfoRow(title: "Bond Count", value: "\(structure.bonds.count)", description: "Chemical bonds")
                    
                    let uniqueElements = Set(structure.atoms.map { $0.element })
                    InfoRow(title: "Elements", value: "\(uniqueElements.count)", description: "Unique chemical elements")
                    
                    if let firstAtom = structure.atoms.first {
                        InfoRow(title: "First Residue", value: firstAtom.residueName, description: "Chain \(firstAtom.chain)")
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Experimental Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Experimental Details")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "PDB ID", value: proteinId ?? "Unknown", description: "Protein Data Bank identifier")
                    
                    let elementTypes = Array(Set(structure.atoms.map { $0.element })).sorted()
                    InfoRow(title: "Element Types", value: elementTypes.joined(separator: ", "), description: "Chemical elements present")
                    
                    let chainList = Array(Set(structure.atoms.map { $0.chain })).sorted()
                    InfoRow(title: "Chains", value: chainList.joined(separator: ", "), description: "Polypeptide chain identifiers")
                    
                    if let firstAtom = structure.atoms.first {
                        InfoRow(title: "First Atom", value: "\(firstAtom.element)\(firstAtom.id)", description: "Chain \(firstAtom.chain)")
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func chainsContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            let chains = Set(structure.atoms.map { $0.chain })
            
            ForEach(Array(chains).sorted(), id: \.self) { chain in
                let chainAtoms = structure.atoms.filter { $0.chain == chain }
                let residues = Set(chainAtoms.map { "\($0.chain):\($0.residueNumber)" })
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chain \(chain)")
                        .font(.headline)
                    
                    HStack {
                        Text("Residues: \(residues.count)")
                        Spacer()
                        Text("Atoms: \(chainAtoms.count)")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private func residuesContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            let residueCounts = Dictionary(grouping: structure.atoms, by: { $0.residueName })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            ForEach(Array(residueCounts.prefix(20)), id: \.key) { residue, count in
                HStack {
                    Text(residue)
                        .font(.headline)
                        .frame(width: 80, alignment: .leading)
                    
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Simple bar chart
                    Rectangle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: CGFloat(count) * 2, height: 20)
                        .cornerRadius(4)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func ligandsContent(structure: PDBStructure) -> some View {
                                    VStack(spacing: 16) {
            let ligands = structure.atoms.filter { $0.isLigand }
            let ligandGroups = Dictionary(grouping: ligands, by: { "\($0.residueName):\($0.chain)" })
            
            ForEach(Array(ligandGroups.keys).sorted(), id: \.self) { key in
                let comps = key.split(separator: ":")
                let resName = comps.first.map(String.init) ?? "?"
                let chain = comps.count > 1 ? String(comps[1]) : "?"
                
                HStack {
                    Text(resName)
                                            .font(.headline)
                        .frame(width: 60, alignment: .leading)
                    Text("Chain: \(chain.isEmpty ? "-" : chain)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Atoms: \((ligandGroups[key]?.count ?? 0))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func pocketsContent(structure: PDBStructure) -> some View {
                    VStack(spacing: 16) {
            let pockets = structure.atoms.filter { $0.isPocket }
            let pocketGroups = Dictionary(grouping: pockets, by: { "\($0.residueName):\($0.chain)" })
            
            ForEach(Array(pocketGroups.keys).sorted(), id: \.self) { key in
                let comps = key.split(separator: ":")
                let resName = comps.first.map(String.init) ?? "?"
                let chain = comps.count > 1 ? String(comps[1]) : "?"
                
                HStack {
                    Text(resName)
                        .font(.headline)
                        .frame(width: 60, alignment: .leading)
                    Text("Chain: \(chain.isEmpty ? "-" : chain)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Atoms: \((pocketGroups[key]?.count ?? 0))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func sequenceContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Generate sequence from actual structure data
            let chains = Set(structure.atoms.map { $0.chain })
            
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
                    
                    Text("Length: \(sequence.count) residues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Residue composition from actual structure
            VStack(alignment: .leading, spacing: 12) {
                Text("Residue Composition")
                    .font(.headline)
                
                let allResidues = structure.atoms.map { $0.residueName }
                let composition = Dictionary(grouping: allResidues, by: { $0 })
                    .mapValues { $0.count }
                
                ForEach(composition.sorted(by: { $0.value > $1.value }), id: \.key) { residue, count in
                    HStack {
                        Text(residue)
                            .font(.headline)
                            .frame(width: 60, alignment: .leading)
                        
                        Text("\(count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Spacer()
                        
                        let percentage = Double(count) / Double(allResidues.count) * 100
                        Rectangle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: CGFloat(percentage) * 2, height: 20)
                            .cornerRadius(4)
                        
                        Text("\(String(format: "%.1f", percentage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func annotationsContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Based on RCSB API data structure
            VStack(alignment: .leading, spacing: 12) {
                Text("Biological Information")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "PDB ID", value: proteinId ?? "Unknown", description: "Protein Data Bank identifier")
                    InfoRow(title: "Total Atoms", value: "\(structure.atoms.count)", description: "All atoms in structure")
                    InfoRow(title: "Total Bonds", value: "\(structure.bonds.count)", description: "Chemical bonds")
                    InfoRow(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", description: "Polypeptide chains")
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Expression Information")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueElements = Set(structure.atoms.map { $0.element })
                    InfoRow(title: "Elements", value: "\(uniqueElements.count)", description: "Unique chemical elements")
                    
                    let elementList = Array(uniqueElements).sorted().joined(separator: ", ")
                    InfoRow(title: "Element Types", value: elementList, description: "Present in structure")
                    
                    let chainList = Array(Set(structure.atoms.map { $0.chain })).sorted()
                    InfoRow(title: "Chain IDs", value: chainList.joined(separator: ", "), description: "Chain identifiers")
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Protein Classification")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueResidues = Set(structure.atoms.map { $0.residueName })
                    InfoRow(title: "Residue Types", value: "\(uniqueResidues.count)", description: "Unique amino acid types")
                    
                    let residueList = Array(uniqueResidues).sorted().joined(separator: ", ")
                    InfoRow(title: "Residue Names", value: residueList, description: "Amino acid residues present")
                    
                    let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
                    InfoRow(title: "Total Residues", value: "\(totalResidues)", description: "Total amino acid residues")
                }
            }
            .padding()
            .background(Color.cyan.opacity(0.1))
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
            let proteinNode = createProteinNode(from: structure)
            scene.rootNode.addChildNode(proteinNode)
            
            // Auto-adjust camera
            let boundingBox = proteinNode.boundingBox
            let maxDimension = max(boundingBox.max.x - boundingBox.min.x,
                                 boundingBox.max.y - boundingBox.min.y,
                                 boundingBox.max.z - boundingBox.min.z)
            
            let camera = SCNCamera()
            camera.fieldOfView = 60
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, maxDimension * 2)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)
        }

        view.scene = scene
    }

    private func createProteinNode(from structure: PDBStructure) -> SCNNode {
        let rootNode = SCNNode()
        
        // Create atoms
        for atom in structure.atoms {
            let atomNode = createAtomNode(atom)
            rootNode.addChildNode(atomNode)
        }
        
        // Create bonds
        for bond in structure.bonds {
            let bondNode = createBondNode(bond, atoms: structure.atoms)
            rootNode.addChildNode(bondNode)
        }
        
        return rootNode
    }
    
    private func createAtomNode(_ atom: Atom) -> SCNNode {
        let radius: CGFloat
        let color: UIColor
        
        switch colorMode {
        case .element:
            radius = atom.element.atomicRadius
            color = atom.element.color
        case .chain:
            radius = 1.0
            color = UIColor(hue: CGFloat(atom.chain.hashValue % 10) / 10.0, saturation: 0.7, brightness: 0.8, alpha: 1.0)
        case .uniform:
            radius = 1.0
            color = uniformColor
        case .secondaryStructure:
            radius = 1.0
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
        
        let cylinder = GeometryCache.shared.unitLodCylinder(radius: 0.1, color: .gray)
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



