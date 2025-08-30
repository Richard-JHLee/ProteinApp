import SwiftUI
import SceneKit
import UIKit

// MARK: - Geometry Cache for Performance Optimization
final class GeometryCache {
    static let shared = GeometryCache()
    private var sphereHi = [CGFloat: SCNSphere]()   // 반경→구
    private var materialByColor = [UIColor: SCNMaterial]()
    
    func sphere(radius: CGFloat, segments: Int = 16) -> SCNSphere {
        if let s = sphereHi[radius] { return s }
        let s = SCNSphere(radius: radius)
        s.segmentCount = segments
        sphereHi[radius] = s
        return s
    }
    
    func material(color: UIColor) -> SCNMaterial {
        if let m = materialByColor[color] { return m }
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = color
        m.specular.contents = UIColor.white
        materialByColor[color] = m
        return m
    }
    
    func sphereWithLOD(radius r: CGFloat, baseColor: UIColor) -> SCNGeometry {
        // 고/중/저 분할 구 준비
        let hi = SCNSphere(radius: r)
        hi.segmentCount = 32
        let md = SCNSphere(radius: r)
        md.segmentCount = 16
        let lo = SCNSphere(radius: r)
        lo.segmentCount = 8
        
        // 같은 머티리얼 공유
        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.diffuse.contents = baseColor
        [hi, md, lo].forEach { $0.firstMaterial = mat }
        
        // 화면상 반지름이 특정 값 이하로 작아지면 더 저렴한 메쉬로
        let lods = [
            SCNLevelOfDetail(geometry: hi, screenSpaceRadius: 40),
            SCNLevelOfDetail(geometry: md, screenSpaceRadius: 20),
            SCNLevelOfDetail(geometry: lo, screenSpaceRadius: 8)
        ]
        
        // 어떤 지오메트리에 LOD를 달든 '같은 지오메트리 공유'가 핵심
        let g = SCNSphere(radius: r)
        g.levelsOfDetail = lods
        g.firstMaterial = mat
        return g
    }
    
    func cylinderWithLOD(radius r: CGFloat, height h: CGFloat, baseColor: UIColor) -> SCNGeometry {
        // 본드(실린더)도 동일하게 segmentCount를 16→8→6 등으로 줄인 3단계
        let hi = SCNCylinder(radius: r, height: h)
        hi.radialSegmentCount = 16
        let md = SCNCylinder(radius: r, height: h)
        md.radialSegmentCount = 8
        let lo = SCNCylinder(radius: r, height: h)
        lo.radialSegmentCount = 6
        
        // 같은 머티리얼 공유
        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.diffuse.contents = baseColor
        [hi, md, lo].forEach { $0.firstMaterial = mat }
        
        let lods = [
            SCNLevelOfDetail(geometry: hi, screenSpaceRadius: 30),
            SCNLevelOfDetail(geometry: md, screenSpaceRadius: 15),
            SCNLevelOfDetail(geometry: lo, screenSpaceRadius: 6)
        ]
        
        let g = SCNCylinder(radius: r, height: h)
        g.levelsOfDetail = lods
        g.firstMaterial = mat
        return g
    }
    
    func clearCache() {
        sphereHi.removeAll()
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
        case .secondaryStructure: return "link.badge.plus"
        }
    }
}

struct ProteinSceneView: UIViewRepresentable {
    let structure: PDBStructure?
    let style: RenderStyle
    let colorMode: ColorMode
    let uniformColor: UIColor
    let autoRotate: Bool
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
        fillLightNode.position = SCNVector3(-20, 20, -30)
        scene.rootNode.addChildNode(fillLightNode)
        
        let rimLight = SCNLight()
        rimLight.type = .directional
        rimLight.intensity = 300
        rimLight.color = UIColor(red: 1.0, green: 1.0, blue: 0.95, alpha: 1.0)
        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(0, -20, 20)
        rimLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLightNode)

        guard let structure = structure else {
            view.scene = scene
            return
        }

        let proteinNode = SCNNode()
        
        for atom in structure.atoms {
            let atomNode = createAtomNode(atom: atom, style: style, colorMode: colorMode, uniformColor: uniformColor)
            proteinNode.addChildNode(atomNode)
        }
        
        if style == .sticks || style == .cartoon {
            for bond in structure.bonds {
                let bondNode = createBondNode(bond: bond, atoms: structure.atoms, colorMode: colorMode, uniformColor: uniformColor)
                proteinNode.addChildNode(bondNode)
            }
        }
        
        scene.rootNode.addChildNode(proteinNode)
        view.scene = scene
        
        // Auto-fit camera
        let boundingBox = proteinNode.boundingBox
        let boundingSize = SCNVector3(
            boundingBox.max.x - boundingBox.min.x,
            boundingBox.max.y - boundingBox.min.y,
            boundingBox.max.z - boundingBox.min.z
        )
        let maxDimension = max(boundingSize.x, boundingSize.y, boundingSize.z)
        let cameraDistance = maxDimension * 2.5
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, cameraDistance)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        view.defaultCameraController.target = SCNVector3(0, 0, 0)
        // Note: SCNCameraController doesn't have a 'distance' property
        // The camera position is already set above
    }
    
    private func createAtomNode(atom: Atom, style: RenderStyle, colorMode: ColorMode, uniformColor: UIColor) -> SCNNode {
        let node = SCNNode()
        let color = getAtomColor(atom: atom, colorMode: colorMode, uniformColor: uniformColor)
        
        switch style {
        case .spheres:
            let radius = getAtomRadius(atom: atom)
            let geometry = GeometryCache.shared.sphereWithLOD(radius: radius, baseColor: color)
            node.geometry = geometry
            
        case .sticks:
            let geometry = GeometryCache.shared.sphereWithLOD(radius: 0.1, baseColor: color)
            node.geometry = geometry
            
        case .cartoon:
            let geometry = GeometryCache.shared.sphereWithLOD(radius: 0.15, baseColor: color)
            node.geometry = geometry
            
        case .surface:
            let radius = getAtomRadius(atom: atom) * 1.2
            let geometry = GeometryCache.shared.sphereWithLOD(radius: radius, baseColor: color)
            // 투명도는 별도로 설정
            if let material = geometry.firstMaterial {
                material.transparency = 0.3
            }
            node.geometry = geometry
        }
        
        node.position = SCNVector3(atom.position.x, atom.position.y, atom.position.z)
        node.name = "atom_\(atom.id)"
        
        return node
    }
    
    private func createBondNode(bond: Bond, atoms: [Atom], colorMode: ColorMode, uniformColor: UIColor) -> SCNNode {
        guard let atom1 = atoms.first(where: { $0.id == bond.a }),
              let atom2 = atoms.first(where: { $0.id == bond.b }) else {
            return SCNNode()
        }
        
        let start = SCNVector3(atom1.position.x, atom1.position.y, atom1.position.z)
        let end = SCNVector3(atom2.position.x, atom2.position.y, atom2.position.z)
        
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2) + pow(end.z - start.z, 2))
        let cylinder = SCNCylinder(radius: 0.05, height: CGFloat(distance))
        
        let color = getBondColor(atom1: atom1, atom2: atom2, colorMode: colorMode, uniformColor: uniformColor)
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2) + pow(end.z - start.z, 2))
        
        // LOD가 적용된 실린더 지오메트리 사용
        let geometry = GeometryCache.shared.cylinderWithLOD(radius: 0.05, height: CGFloat(distance), baseColor: color)
        
        let node = SCNNode(geometry: geometry)
        
        // Position and rotate cylinder
        let midPoint = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
        node.position = midPoint
        
        let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        
        // Calculate rotation to align cylinder with bond direction
        if direction.y != 0 || direction.x != 0 {
            let angle = atan2(sqrt(direction.x * direction.x + direction.y * direction.y), direction.z)
            let rotationNode = SCNNode()
            rotationNode.eulerAngles = SCNVector3(angle, 0, 0)
            node.addChildNode(rotationNode)
        }
        
        return node
    }
    
    private func getAtomRadius(atom: Atom) -> CGFloat {
        let radii: [String: CGFloat] = [
            "H": 0.31, "C": 0.76, "N": 0.71, "O": 0.66, "S": 1.05,
            "P": 1.07, "F": 0.57, "Cl": 1.02, "Br": 1.20, "I": 1.39
        ]
        return radii[atom.element] ?? 0.5
    }
    
    private func getAtomColor(atom: Atom, colorMode: ColorMode, uniformColor: UIColor) -> UIColor {
        switch colorMode {
        case .element:
            return getElementColor(atom.element)
        case .chain:
            return getChainColor(atom.chain)
        case .uniform:
            return uniformColor
        case .secondaryStructure:
            return getSecondaryStructureColor(atom)
        }
    }
    
    private func getBondColor(atom1: Atom, atom2: Atom, colorMode: ColorMode, uniformColor: UIColor) -> UIColor {
        switch colorMode {
        case .element:
            return UIColor.systemGray
        case .chain:
            return getChainColor(atom1.chain)
        case .uniform:
            return uniformColor
        case .secondaryStructure:
            return UIColor.systemGray
        }
    }
    
    private func getElementColor(_ element: String) -> UIColor {
        let colors: [String: UIColor] = [
            "H": .white, "C": .darkGray, "N": .blue, "O": .red, "S": .yellow,
            "P": .orange, "F": .green, "Cl": .green, "Br": .systemRed, "I": .systemPurple
        ]
        return colors[element] ?? .lightGray
    }
    
    private func getChainColor(_ chain: String) -> UIColor {
        let colors: [String: UIColor] = [
            "A": .systemBlue, "B": .systemRed, "C": .systemGreen, "D": .systemOrange,
            "E": .systemPurple, "F": .systemPink, "G": .systemTeal, "H": .systemIndigo
        ]
        return colors[chain] ?? .systemGray
    }
    
    private func getSecondaryStructureColor(_ atom: Atom) -> UIColor {
        // For now, use chain color as fallback
        return getChainColor(atom.chain)
    }
    
    class Coordinator: NSObject {
        let parent: ProteinSceneView
        
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

struct ProteinSceneContainer: View {
    let structure: PDBStructure?
    @State private var selectedStyle: RenderStyle = .spheres
    @State private var selectedColorMode: ColorMode = .element
    @State private var selectedUniformColor: Color = .blue
    @State private var autoRotate: Bool = false
    @State private var showControls: Bool = true
    @State private var selectedChain: String? = nil
    @State private var error: String? = nil
    @State private var pdbId: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedTab: InfoTabType = .overview
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header Section (Always visible)
            if let structure = structure, !structure.atoms.isEmpty {
                proteinInfoHeader(structure: structure)
                chainSelectionTabs(structure: structure)
            }
            
            // Main 3D Viewer (Fixed position)
            ProteinSceneView(
                structure: structure,
                style: selectedStyle,
                colorMode: selectedColorMode,
                uniformColor: UIColor(selectedUniformColor),
                autoRotate: autoRotate,
                onSelectAtom: { atom in
                    // Handle atom selection
                    print("Selected atom: \(atom.element) in chain \(atom.chain)")
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Selected Chain Information (Fixed position)
            if let selectedChain = selectedChain, let structure = structure {
                selectedChainInfoView(structure: structure, chain: selectedChain)
            }
            
            // Controls Section (Animated, doesn't affect layout)
            VStack(spacing: 0) {
                // Toggle button (always visible)
                controlsToggleButton
                    .padding(.top, 16)
                
                // Controls content with animation
                if showControls {
                    controlsContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showControls)
        }
        .padding(.top, 20)
        .background(Color(.systemBackground))
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }
    
    // MARK: - UI Components
    
    private func proteinInfoHeader(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Main protein info
            VStack(spacing: 8) {
                Text("Protein Structure")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(structure.atoms.count)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.blue)
                        Text("atoms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        let chains = Array(Set(structure.atoms.map { $0.chain }))
                        Text("\(chains.count)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.green)
                        Text("chains")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        let residues = Array(Set(structure.atoms.map { $0.residueName }))
                        Text("\(residues.count)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.orange)
                        Text("residues")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60) // Increased top padding to avoid navigation bar overlap
    }
    
    private func chainSelectionTabs(structure: PDBStructure) -> some View {
        let chains = Array(Set(structure.atoms.map { $0.chain })).sorted()
        
        return VStack(spacing: 16) {
            // Info Tab Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(InfoTabType.allCases, id: \.self) { tabType in
                        InfoTabButton(
                            type: tabType,
                            isSelected: selectedTab == tabType
                        ) {
                            selectedTab = tabType
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Content based on selected tab
            switch selectedTab {
            case .overview:
                overviewContent(structure: structure)
            case .chains:
                chainsContent(structure: structure, chains: chains)
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
        .padding(.top, 20)
    }
    
    private func overviewContent(structure: PDBStructure) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Total Atoms", value: "\(structure.atoms.count)", color: .blue)
                StatCard(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", color: .green)
                StatCard(title: "Residues", value: "\(Set(structure.atoms.map { $0.residueName }).count)", color: .orange)
                StatCard(title: "Backbone", value: "\(structure.atoms.filter { $0.isBackbone }.count)", color: .purple)
                StatCard(title: "Ligands", value: "\(structure.atoms.filter { $0.isLigand }.count)", color: .red)
                StatCard(title: "Pockets", value: "\(structure.atoms.filter { $0.isPocket }.count)", color: .brown)
            }
            
            // Secondary Structure Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Secondary Structure")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    VStack {
                        Text("\(structure.atoms.filter { $0.secondaryStructure == .helix }.count)")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.purple)
                        Text("Helix")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(structure.atoms.filter { $0.secondaryStructure == .sheet }.count)")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.red)
                        Text("Sheet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(structure.atoms.filter { $0.secondaryStructure == .coil }.count)")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.gray)
                        Text("Coil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func chainsContent(structure: PDBStructure, chains: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chains")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(chains, id: \.self) { chain in
                        ChainDetailCard(
                            chain: chain,
                            atomCount: structure.atoms.filter { $0.chain == chain }.count,
                            isSelected: selectedChain == chain
                        ) {
                            selectedChain = selectedChain == chain ? nil : chain
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func residuesContent(structure: PDBStructure) -> some View {
        let residues = Array(Set(structure.atoms.map { $0.residueName })).sorted()
        let residueCounts = Dictionary(grouping: structure.atoms, by: { $0.residueName })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Residues")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Amino acid composition")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(residueCounts.prefix(20), id: \.key) { residue, count in
                    VStack(spacing: 4) {
                        Text(String(residue))
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                        
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if residues.count > 20 {
                Text("+ \(residues.count - 20) more residues")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func ligandsContent(structure: PDBStructure) -> some View {
        let ligands = Array(Set(structure.atoms.filter { $0.isLigand }.map { $0.residueName })).sorted()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Ligands")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            if ligands.isEmpty {
                Text("No ligands found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ligands, id: \.self) { ligand in
                            Text(String(ligand))
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func pocketsContent(structure: PDBStructure) -> some View {
        let pocketAtoms = structure.atoms.filter { $0.isPocket }
        let pocketResidues = Array(Set(pocketAtoms.map { $0.residueName })).sorted()
        let pocketChains = Array(Set(pocketAtoms.map { $0.chain })).sorted()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Pockets")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Binding sites and surface regions")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if pocketAtoms.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 40))
                        .foregroundColor(.purple.opacity(0.6))
                    
                    Text("No pockets detected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Pockets are surface regions that may serve as binding sites for ligands or other molecules.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(pocketAtoms.count)")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.purple)
                            Text("Pocket Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(pocketResidues.count)")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.purple)
                            Text("Residues")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chains with pockets:")
                            .font(.subheadline.weight(.medium))
                        
                        HStack(spacing: 8) {
                            ForEach(pocketChains, id: \.self) { chain in
                                Text(chain)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func sequenceContent(structure: PDBStructure) -> some View {
        let residues = Array(Set(structure.atoms.map { $0.residueName })).sorted()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Sequence")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(residues, id: \.self) { residue in
                        Text(String(residue))
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brown)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func annotationsContent(structure: PDBStructure) -> some View {
        let annotations = structure.annotations.map { $0.type.rawValue }.sorted()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Annotations")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(annotations, id: \.self) { annotation in
                        Text(annotation)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var controlsToggleButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
        }) {
            HStack {
                Image(systemName: showControls ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Text(showControls ? "Hide Controls" : "Show Controls")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var controlsContent: some View {
        VStack(spacing: 16) {
            // Style Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Render Style")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
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
            }
            
            // Color Mode Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Color Mode")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
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
            }
            
            // Uniform Color Picker (only for uniform mode)
            if selectedColorMode == .uniform {
                HStack {
                    Text("Color")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    ColorPicker("", selection: $selectedUniformColor)
                        .labelsHidden()
                }
            }
            
            // Auto-rotate Toggle
            HStack {
                Text("Auto-rotate")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $autoRotate)
                    .labelsHidden()
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func selectedChainInfoView(structure: PDBStructure, chain: String) -> some View {
        let atomsInChain = structure.atoms.filter { $0.chain == chain }
        let residuesInChain = Array(Set(atomsInChain.map { $0.residueName })).sorted()
        let uniqueResidues = residuesInChain.map { $0.prefix(3) }
        
        // Calculate chain statistics
        let backboneAtoms = atomsInChain.filter { $0.isBackbone }
        let sideChainAtoms = atomsInChain.filter { !$0.isBackbone }
        let helixResidues = atomsInChain.filter { $0.secondaryStructure == .helix }
        let sheetResidues = atomsInChain.filter { $0.secondaryStructure == .sheet }
        
        return VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chain \(chain)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("\(atomsInChain.count) atoms • \(uniqueResidues.count) residues")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Deselect") {
                    selectedChain = nil
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Statistics Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Total Atoms", value: "\(atomsInChain.count)", color: .blue)
                StatCard(title: "Backbone", value: "\(backboneAtoms.count)", color: .green)
                StatCard(title: "Side Chain", value: "\(sideChainAtoms.count)", color: .orange)
                StatCard(title: "Helix", value: "\(helixResidues.count)", color: .purple)
                StatCard(title: "Sheet", value: "\(sheetResidues.count)", color: .red)
                StatCard(title: "Coil", value: "\(atomsInChain.count - helixResidues.count - sheetResidues.count)", color: .gray)
            }
            
            // Residue Composition
            VStack(alignment: .leading, spacing: 8) {
                Text("Residue Composition")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(uniqueResidues, id: \.self) { residue in
                            Text(String(residue))
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: selectedChain)
    }
    
    private func StatCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Supporting Views

struct ChainDetailCard: View {
    let chain: String
    let atomCount: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text("Chain \(chain)")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(atomCount) atoms")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                
                HStack(spacing: 8) {
                    Button("Highlight") {
                        // Highlight chain functionality
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSelected ? .white.opacity(0.2) : .blue.opacity(0.1))
                    .clipShape(Capsule())
                    
                    Button("Focus") {
                        // Focus chain functionality
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSelected ? .white.opacity(0.2) : .green.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(16)
            .background {
                if isSelected {
                    LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color(.systemGray6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? .blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct StyleButton: View {
    let style: RenderStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: style.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(style.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 60, height: 60)
            .background {
                if isSelected {
                    LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color(.systemGray6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? .blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct ColorModeButton: View {
    let mode: ColorMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .primary)
                Text(mode.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 60, height: 60)
            .background {
                if isSelected {
                    LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color(.systemGray6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? .blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct AtomInfoView: View {
    let atom: Atom
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Atom")
                    .font(.headline.weight(.bold))
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ELEMENT")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(atom.element)
                        .font(.title2.weight(.bold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("NAME")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(atom.name)
                        .font(.title2.weight(.bold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("CHAIN")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(atom.chain)
                        .font(.title2.weight(.bold))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("RESIDUE")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("\(atom.residueName) \(atom.residueNumber)")
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct InfoTabButton: View {
    let type: InfoTabType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(type.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color(.systemGray6)
                }
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? .blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
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
    
    var icon: String {
        switch self {
        case .overview: return "info.circle"
        case .chains: return "link"
        case .residues: return "atom"
        case .ligands: return "pills"
        case .pockets: return "target"
        case .sequence: return "textformat"
        case .annotations: return "note.text"
        }
    }
}

