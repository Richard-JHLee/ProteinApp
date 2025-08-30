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
    @Binding var showInfoBar: Bool
    var onSelectAtom: ((Atom) -> Void)? = nil
    var highlightedChain: String? = nil
    var onChainHighlight: ((String?) -> Void)? = nil
    var onChainFocus: ((String?) -> Void)? = nil

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        view.antialiasingMode = .multisampling2X // 기본값을 2X로 설정
        view.preferredFramesPerSecond = 60
        
        // AA 동적 전환을 위한 delegate 설정
        view.defaultCameraController.delegate = context.coordinator
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        
        // 초기 씬 설정 (라이트와 카메라 포함)
        setupInitialScene(view: view)
        
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Coordinator에 현재 view 설정
        context.coordinator.currentView = uiView
        
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

    private func setupInitialScene(view: SCNView) {
        let scene = SCNScene()
        
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
        
        // 기본 카메라 설정
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 30) // 더 가까운 위치로 설정
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        view.scene = scene
        view.defaultCameraController.target = SCNVector3(0, 0, 0)
    }
    
    private func rebuild(view: SCNView) {
        // 씬이 없으면 초기 설정
        if view.scene == nil {
            setupInitialScene(view: view)
        }
        
        guard let structure = structure, !structure.atoms.isEmpty else {
            // 구조가 없거나 원자가 없으면 protein 노드만 제거
            view.scene?.rootNode.childNodes.forEach { node in
                if node.name == "proteinNode" {
                    node.removeFromParentNode()
                }
            }
            return
        }
        
        // 기존 protein 노드 제거 (라이트는 유지)
        view.scene?.rootNode.childNodes.forEach { node in
            if node.name == "proteinNode" {
                node.removeFromParentNode()
            }
        }
        
        let proteinNode = SCNNode()
        proteinNode.name = "proteinNode" // 식별을 위한 이름 설정
        
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
        
        view.scene?.rootNode.addChildNode(proteinNode)
        
        // Auto-fit camera (protein 노드가 변경된 후에만)
        let boundingBox = proteinNode.boundingBox
        let boundingSize = SCNVector3(
            boundingBox.max.x - boundingBox.min.x,
            boundingBox.max.y - boundingBox.min.y,
            boundingBox.max.z - boundingBox.min.z
        )
        let maxDimension = max(boundingSize.x, boundingSize.y, boundingSize.z)
        
        // 카메라 거리 조정 (너무 멀거나 가깝지 않게)
        let cameraDistance = max(maxDimension * 1.5, 20.0) // 최소 20.0 거리 보장
        
        // 기존 카메라 노드 찾기 및 위치 업데이트
        if let existingCamera = view.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) {
            existingCamera.position = SCNVector3(0, 0, cameraDistance)
        }
        
        // 카메라 컨트롤러 타겟 설정
        view.defaultCameraController.target = SCNVector3(0, 0, 0)
    }
    
    private func createAtomNode(atom: Atom, style: RenderStyle, colorMode: ColorMode, uniformColor: UIColor) -> SCNNode {
        let node = SCNNode()
        let color = getAtomColor(atom: atom, colorMode: colorMode, uniformColor: uniformColor)
        
        switch style {
        case .spheres:
            let radius = getAtomRadius(atom: atom)
            let geometry = GeometryCache.shared.lodSphere(radius: radius, color: color)
            node.geometry = geometry
            
        case .sticks:
            let geometry = GeometryCache.shared.lodSphere(radius: 0.1, color: color)
            node.geometry = geometry
            
        case .cartoon:
            let geometry = GeometryCache.shared.lodSphere(radius: 0.15, color: color)
            node.geometry = geometry
            
        case .surface:
            let radius = getAtomRadius(atom: atom) * 1.2
            let base = GeometryCache.shared.lodSphere(radius: radius, color: color)
            let g = base.copy() as! SCNGeometry
            let m = (base.firstMaterial?.copy() as? SCNMaterial) ?? SCNMaterial()
            m.transparency = 0.3
            g.firstMaterial = m
            node.geometry = g
        }
        
        // 안전장치: position 값이 유효한지 확인
        let pos = atom.position
        guard pos.x.isFinite && pos.y.isFinite && pos.z.isFinite else {
            print("Warning: Invalid position for atom \(atom.id): \(pos)")
            return SCNNode()
        }
        node.position = SCNVector3(pos.x, pos.y, pos.z)
        node.name = "atom_\(atom.id)"
        
        // 체인 하이라이트 적용
        if let highlightedChain = highlightedChain, atom.chain == highlightedChain {
            applyChainHighlight(to: node)
        }
        
        return node
    }
    
    // MARK: - Chain Highlight Functions
    private func applyChainHighlight(to node: SCNNode) {
        // Glow 효과를 위한 emission material 추가
        if let geometry = node.geometry {
            let material = geometry.firstMaterial ?? SCNMaterial()
            material.emission.contents = UIColor.yellow
            material.emission.intensity = 0.3
            
            // Outline 효과를 위한 stroke material
            let strokeMaterial = SCNMaterial()
            strokeMaterial.diffuse.contents = UIColor.yellow
            strokeMaterial.transparency = 0.8
            
            // 원본 geometry에 stroke material 추가
            geometry.materials = [material, strokeMaterial]
        }
        
        // 추가적인 시각적 강조를 위한 scale
        node.scale = SCNVector3(1.1, 1.1, 1.1)
    }
    
    private func createBondNode(bond: Bond, atoms: [Atom], colorMode: ColorMode, uniformColor: UIColor) -> SCNNode {
        guard let atom1 = atoms.first(where: { $0.id == bond.a }),
              let atom2 = atoms.first(where: { $0.id == bond.b }) else {
            return SCNNode()
        }
        
        // 안전장치: position 값이 유효한지 확인
        let pos1 = atom1.position
        let pos2 = atom2.position
        guard pos1.x.isFinite && pos1.y.isFinite && pos1.z.isFinite &&
              pos2.x.isFinite && pos2.y.isFinite && pos2.z.isFinite else {
            print("Warning: Invalid position for bond between atoms \(atom1.id) and \(atom2.id)")
            return SCNNode()
        }
        
        let start = SCNVector3(Float(pos1.x), Float(pos1.y), Float(pos1.z))
        let end = SCNVector3(Float(pos2.x), Float(pos2.y), Float(pos2.z))
        
        let direction = SCNVector3(
            Float(end.x - start.x),
            Float(end.y - start.y),
            Float(end.z - start.z)
        )
        let len = Float(sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z))
        guard len > 0.0001 else { return SCNNode() }
        
        let color = getBondColor(atom1: atom1, atom2: atom2, colorMode: colorMode, uniformColor: uniformColor)
        
        // 단위 LOD 실린더 공유
        let node = SCNNode(geometry: GeometryCache.shared.unitLodCylinder(radius: 0.05, color: color))
        node.position = SCNVector3(
            Float((start.x + end.x) / 2),
            Float((start.y + end.y) / 2),
            Float((start.z + end.z) / 2)
        )
        node.scale = SCNVector3(1, Float(len), 1) // height=1 → 길이를 스케일로
        
        // 로컬 Y축(0,1,0)을 dir로 회전: 쿼터니언 생성 (NaN 방지)
        let yAxis = simd_float3(0, 1, 0)
        let v = simd_normalize(simd_float3(direction.x/len, direction.y/len, direction.z/len))
        let crossV = simd_cross(yAxis, v)
        let axisLen = simd_length(crossV)
        let dot = simd_dot(yAxis, v)
        let angle = acos(max(-1, min(1, dot)))
        
        if angle.isFinite && angle > 0.0001 && axisLen > 0.0001 {
            let axis = crossV / axisLen
            let halfAngle = angle / 2
            node.orientation = SCNQuaternion(
                Float(axis.x * sin(halfAngle)),
                Float(axis.y * sin(halfAngle)),
                Float(axis.z * sin(halfAngle)),
                Float(cos(halfAngle))
            )
        } else {
            node.orientation = SCNQuaternion(0, 0, 0, 1) // 평행: 회전 없음
        }
        
        // 체인 하이라이트 적용 (bond도 하이라이트)
        if let highlightedChain = highlightedChain, 
           (atom1.chain == highlightedChain || atom2.chain == highlightedChain) {
            applyChainHighlight(to: node)
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
    
    class Coordinator: NSObject, SCNCameraControllerDelegate {
        let parent: ProteinSceneView
        weak var currentView: SCNView?
        
        init(parent: ProteinSceneView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let view = gesture.view as! SCNView
            let location = gesture.location(in: view)
            
            let hitResults = view.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest,
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
        
        // MARK: - AA 동적 전환 (4×↔2×)
        func cameraInertiaWillStart(for cameraController: SCNCameraController) {
            currentView?.antialiasingMode = .multisampling2X
            // 카메라 제스처 시작 시 정보 패널 자동 숨김
            DispatchQueue.main.async {
                self.parent.showInfoBar = false
            }
        }
        
        func cameraInertiaDidEnd(for cameraController: SCNCameraController) {
            currentView?.antialiasingMode = .multisampling4X
            // 카메라 제스처 종료 후 2초 뒤 정보 패널 자동 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.parent.showInfoBar = true
            }
        }
        
        // 카메라 제스처 시작 감지
        func cameraControllerWillBeginCameraChange(_ cameraController: SCNCameraController) {
            DispatchQueue.main.async {
                self.parent.showInfoBar = false
            }
        }
        
        // 카메라 제스처 종료 감지
        func cameraControllerDidEndCameraChange(_ cameraController: SCNCameraController) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.parent.showInfoBar = true
            }
        }
    }
}

// MARK: - View Mode Enum
enum ViewMode {
    case info      // 정보 탭과 상세 정보 표시
    case viewer    // 3D 뷰어만 표시
}

struct ProteinSceneContainer: View {
    let structure: PDBStructure?
    @State private var viewMode: ViewMode = .info
    @State private var selectedStyle: RenderStyle = .spheres
    @State private var selectedColorMode: ColorMode = .element
    @State private var selectedUniformColor: Color = .blue
    @State private var autoRotate: Bool = false
    @State private var showControls: Bool = true
    @State private var showInfoBar: Bool = true
    @State private var selectedChain: String? = nil
    @State private var highlightedChain: String? = nil
    @State private var error: String? = nil
    @State private var pdbId: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedTab: InfoTabType = .overview
    
    var body: some View {
        ZStack {
            // Main 3D Viewer (Full screen, ignores safe area) - 뷰어 모드에서만 표시
            if viewMode == .viewer {
                ProteinSceneView(
                    structure: structure,
                    style: selectedStyle,
                    colorMode: selectedColorMode,
                    uniformColor: UIColor(selectedUniformColor),
                    autoRotate: autoRotate,
                    showInfoBar: $showInfoBar,
                    onSelectAtom: { atom in
                        // Handle atom selection
                        print("Selected atom: \(atom.element) in chain \(atom.chain)")
                    },
                    highlightedChain: highlightedChain,
                    onChainHighlight: { chain in
                        highlightedChain = chain
                    },
                    onChainFocus: onChainFocus
                )
                .ignoresSafeArea()
                
                // Controls Section (Bottom right, fixed) - 모든 모드에서 표시
                HStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // 항상 보이는 색상 슬라이더
                        colorSliderContent
                            .padding(.bottom, 16)
                        
                        // 토글 가능한 컨트롤들
                        if showControls {
                            toggleableControlsContent
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        controlsToggleButton
                            .padding(.bottom, 16)
                    }
                    .padding(.trailing, 16)
                }
                .animation(.easeInOut(duration: 0.3), value: showControls)
                
                // 정보 모드로 돌아가는 버튼 (Top left, floating)
                VStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewMode = .info
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14, weight: .medium))
                            Text("Info")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.top, 20)
            }
        }
        .safeAreaInset(edge: .top) {
            if viewMode == .info, let structure = structure, !structure.atoms.isEmpty {
                VStack(spacing: 0) {
                    proteinInfoHeader(structure: structure)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    chainSelectionTabs(structure: structure, highlightedChain: highlightedChain, onChainFocus: onChainFocus, onChainHighlight: onChainHighlight)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
                .background(.ultraThinMaterial)
                .overlay(Divider(), alignment: .bottom)
            }
        }
        .background(Color(.systemBackground))
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }
    
    // MARK: - UI Components
    
    private func proteinInfoHeader(structure: PDBStructure) -> some View {
        VStack(spacing: 12) {
            // Main protein info
            VStack(spacing: 6) {
                Text("Protein Structure")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("\(structure.atoms.count)")
                            .font(.title.weight(.bold))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("atoms")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary.opacity(0.8))
                            .textCase(.uppercase)
                    }
                    
                    VStack(spacing: 6) {
                        let chains = Array(Set(structure.atoms.map { $0.chain }))
                        Text("\(chains.count)")
                            .font(.title.weight(.bold))
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("chains")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary.opacity(0.8))
                            .textCase(.uppercase)
                    }
                    
                    VStack(spacing: 6) {
                        let residues = Array(Set(structure.atoms.map { $0.residueName }))
                        Text("\(residues.count)")
                            .font(.title.weight(.bold))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("residues")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary.opacity(0.8))
                            .textCase(.uppercase)
                    }
                    
                    Spacer()
                    
                    // 모드 전환 버튼 (정보 ↔ 뷰어)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewMode = (viewMode == .info) ? .viewer : .info
                        }
                    }) {
                        Image(systemName: viewMode == .info ? "eye" : "list.bullet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(viewMode == .info ? "Switch to 3D Viewer" : "Switch to Info View")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12) // Reduced padding since safeAreaInset handles top positioning
    }
    
    @ViewBuilder
    private func chainSelectionTabs(structure: PDBStructure, highlightedChain: String?, onChainFocus: ((String?) -> Void)?, onChainHighlight: ((String?) -> Void)?) -> some View {
        let chains = Array(Set(structure.atoms.map { $0.chain })).sorted()
        
        VStack(spacing: 16) {
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
        
        // Selected Chain Information (if any chain is selected)
        if let selectedChain = selectedChain {
            selectedChainInfoView(structure: structure, chain: selectedChain, highlightedChain: highlightedChain, onChainFocus: onChainFocus, onChainHighlight: onChainHighlight)
                .padding(.top, 16)
        }
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
            .map { (key: $0.key, value: $0.value) }
        
        let totalAtoms = structure.atoms.count
        let maxCount = residueCounts.map { $0.value }.max() ?? 1
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Residues")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Amino acid composition with relative abundance")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Top residues with bar charts - Scrollable container
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Residues")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 8) {
                        ForEach(residueCounts, id: \.key) { residue, count in
                            HStack(spacing: 12) {
                                // Residue name with color-coded background
                                Text(String(residue))
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(residueGroupColor(for: String(residue)))
                                    .clipShape(Capsule())
                                    .frame(width: 50, alignment: .center)
                                
                                // Bar chart showing relative abundance
                                GeometryReader { geometry in
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .fill(residueGroupColor(for: String(residue)))
                                            .frame(width: geometry.size.width * CGFloat(count) / CGFloat(maxCount))
                                        
                                        Spacer()
                                    }
                                }
                                .frame(height: 20)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                // Count and percentage
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(count)")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("\(Int(Double(count) / Double(totalAtoms) * 100))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.trailing, 4) // 스크롤바 공간 확보
                }
                .frame(maxHeight: 300) // 최대 높이 제한으로 스크롤 가능하게
            }
            
            // Summary statistics
            VStack(alignment: .leading, spacing: 8) {
                Text("Residue Groups")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    residueGroupSummary(title: "Hydrophobic", color: .blue, count: hydrophobicResidueCount(structure))
                    residueGroupSummary(title: "Polar", color: .green, count: polarResidueCount(structure))
                    residueGroupSummary(title: "Charged", color: .orange, count: chargedResidueCount(structure))
                }
            }
            .padding(.top, 8)
            
            if residues.count > 15 {
                Text("+ \(residues.count - 15) more residues")
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
                                .background(
                                    // 🟧 Orange → Side chain/Ligand (변동성)
                                    Color.orange
                                )
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
                            .background(
                                // 🟦 Blue → 수량/전체 (Sequence는 전체 구조)
                                Color.blue
                            )
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
    
    // MARK: - Controls Components
    
    // 항상 보이는 색상 슬라이더
    private var colorSliderContent: some View {
        VStack(spacing: 16) {
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
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // 토글 가능한 컨트롤들
    private var toggleableControlsContent: some View {
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
    
    private func selectedChainInfoView(structure: PDBStructure, chain: String, highlightedChain: String?, onChainFocus: ((String?) -> Void)?, onChainHighlight: ((String?) -> Void)?) -> some View {
        let atomsInChain = structure.atoms.filter { $0.chain == chain }
        let residuesInChain = Array(Set(atomsInChain.map { $0.residueName })).sorted()
        let uniqueResidues = residuesInChain.map { $0.prefix(3) }
        
        // Calculate chain statistics
        let backboneAtoms = atomsInChain.filter { $0.isBackbone }
        let sideChainAtoms = atomsInChain.filter { !$0.isBackbone }
        let helixResidues = atomsInChain.filter { $0.secondaryStructure == .helix }
        let sheetResidues = atomsInChain.filter { $0.secondaryStructure == .sheet }
        
        return selectedChainInfoContent(
            chain: chain,
            atomsInChain: atomsInChain,
            uniqueResidues: uniqueResidues,
            backboneAtoms: backboneAtoms,
            sideChainAtoms: sideChainAtoms,
            helixResidues: helixResidues,
            sheetResidues: sheetResidues,
            highlightedChain: highlightedChain,
            onChainFocus: onChainFocus
        )
    }
    
    private func selectedChainInfoContent(
        chain: String,
        atomsInChain: [Atom],
        uniqueResidues: [String.SubSequence],
        backboneAtoms: [Atom],
        sideChainAtoms: [Atom],
        helixResidues: [Atom],
        sheetResidues: [Atom],
        highlightedChain: String?,
        onChainFocus: ((String?) -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            selectedChainHeader(chain: chain, atomsInChain: atomsInChain, uniqueResidues: uniqueResidues, highlightedChain: highlightedChain, onChainFocus: onChainFocus, onChainHighlight: onChainHighlight)
            selectedChainStatistics(atomsInChain: atomsInChain, backboneAtoms: backboneAtoms, sideChainAtoms: sideChainAtoms, helixResidues: helixResidues, sheetResidues: sheetResidues)
            selectedChainResidues(uniqueResidues: uniqueResidues)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.blue.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: selectedChain)
    }
    
    private func selectedChainHeader(
        chain: String,
        atomsInChain: [Atom],
        uniqueResidues: [String.SubSequence],
        highlightedChain: String?,
        onChainFocus: ((String?) -> Void)?,
        onChainHighlight: ((String?) -> Void)?
    ) -> some View {
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
            
            selectedChainActionButtons(chain: chain, highlightedChain: highlightedChain, onChainFocus: onChainFocus, onChainHighlight: onChainHighlight)
        }
    }
    
        private func selectedChainActionButtons(
        chain: String,
        highlightedChain: String?,
        onChainFocus: ((String?) -> Void)?,
        onChainHighlight: ((String?) -> Void)?
    ) -> some View {
        HStack(spacing: 8) {
            // Highlight Button
            Button(action: {
                if highlightedChain == chain {
                    onChainHighlight?(nil) // 하이라이트 해제
                } else {
                    onChainHighlight?(chain) // 하이라이트 적용
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: highlightedChain == chain ? "sparkles" : "sparkles.slash")
                        .font(.caption2)
                    Text(highlightedChain == chain ? "Unhighlight" : "Highlight")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(highlightedChain == chain ? .orange : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((highlightedChain == chain ? Color.orange : Color.blue).opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Focus Button
            Button(action: {
                onChainFocus?(chain)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text("Focus")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Deselect Button
            Button("Deselect") {
                selectedChain = nil
                onChainHighlight?(nil) // 체인 선택 해제 시 하이라이트도 해제
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    private func selectedChainStatistics(
        atomsInChain: [Atom],
        backboneAtoms: [Atom],
        sideChainAtoms: [Atom],
        helixResidues: [Atom],
        sheetResidues: [Atom]
    ) -> some View {
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
    }
    
    private func selectedChainResidues(uniqueResidues: [String.SubSequence]) -> some View {
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
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
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

// MARK: - Color Utility Functions
/// Residue 타입에 따른 의미 있는 색상 반환
private func residueColor(for residue: String) -> Color {
    switch residue.uppercased() {
    // 🟦 Blue → 수량/전체 (기본)
    case "ALA", "MET", "PHE", "TRP":
        return .blue // 소수성 아미노산 (안정적)
    
    // 🟩 Green → 안정적 요소 (Backbone)
    case "SER", "CYS", "ASN", "GLN":
        return .green // 극성 아미노산 (안정적)
    
    // 🟧 Orange → Side chain (변동성)
    case "ASP", "GLU", "LYS", "ARG", "HIS":
        return .orange // 전하를 띤 아미노산 (변동성)
    
    // 🟪 Purple → Helix (특수 구조)
    case "PRO", "GLY":
        return .purple // 특수 구조 형성
    
    // 🔴 Red → Sheet (강한 구조)
    case "VAL", "ILE", "THR":
        return .red // 베타 시트 선호
    
    // 🟦 Blue → 수량/전체 (기본)
    case "LEU":
        return .blue // 소수성 아미노산 (안정적)
    
    // ⚪ Gray → Coil (유연한 구조)
    default:
        return .gray // 유연한 구조
    }
}

/// Residue 그룹별 색상 반환 (친수성/소수성/극성)
private func residueGroupColor(for residue: String) -> Color {
    switch residue.uppercased() {
    // 🟦 Blue → Hydrophobic (소수성)
    case "ALA", "VAL", "LEU", "ILE", "MET", "PHE", "TRP", "PRO":
        return .blue
    
    // 🟩 Green → Polar (극성, 친수성)
    case "GLY", "SER", "THR", "CYS", "ASN", "GLN":
        return .green
    
    // 🟧 Orange → Charged (전하를 띤, 극성)
    case "ASP", "GLU", "LYS", "ARG", "HIS":
        return .orange
    
    default:
        return .gray
    }
}

/// 친수성 아미노산 개수 계산
private func hydrophobicResidueCount(_ structure: PDBStructure) -> Int {
    let hydrophobicResidues = ["ALA", "VAL", "LEU", "ILE", "MET", "PHE", "TRP", "PRO"]
    return structure.atoms.filter { hydrophobicResidues.contains($0.residueName.uppercased()) }.count
}

/// 극성 아미노산 개수 계산
private func polarResidueCount(_ structure: PDBStructure) -> Int {
    let polarResidues = ["GLY", "SER", "THR", "CYS", "ASN", "GLN"]
    return structure.atoms.filter { polarResidues.contains($0.residueName.uppercased()) }.count
}

/// 전하를 띤 아미노산 개수 계산
private func chargedResidueCount(_ structure: PDBStructure) -> Int {
    let chargedResidues = ["ASP", "GLU", "LYS", "ARG", "HIS"]
    return structure.atoms.filter { chargedResidues.contains($0.residueName.uppercased()) }.count
}

/// Residue 그룹 요약 카드
private func residueGroupSummary(title: String, color: Color, count: Int) -> some View {
    VStack(spacing: 4) {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
        
        Text("\(count)")
            .font(.title3.weight(.bold))
            .foregroundColor(color)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(color.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}

// MARK: - ProteinSceneContainer Extensions
extension ProteinSceneContainer {
    private func focusOnChain(_ chain: String?) {
        guard let chain = chain, let structure = structure else { return }
        
        // 해당 체인의 원자들 찾기
        let chainAtoms = structure.atoms.filter { $0.chain == chain }
        guard !chainAtoms.isEmpty else { return }
        
        // 체인의 중심점 계산
        let centerX = chainAtoms.map { $0.position.x }.reduce(0, +) / Float(chainAtoms.count)
        let centerY = chainAtoms.map { $0.position.y }.reduce(0, +) / Float(chainAtoms.count)
        let centerZ = chainAtoms.map { $0.position.z }.reduce(0, +) / Float(chainAtoms.count)
        
        let center = SCNVector3(centerX, centerY, centerZ)
        
        // 체인의 경계 상자 계산
        let minX = chainAtoms.map { $0.position.x }.min() ?? 0
        let maxX = chainAtoms.map { $0.position.x }.max() ?? 0
        let minY = chainAtoms.map { $0.position.y }.min() ?? 0
        let maxY = chainAtoms.map { $0.position.y }.max() ?? 0
        let minZ = chainAtoms.map { $0.position.z }.min() ?? 0
        let maxZ = chainAtoms.map { $0.position.z }.max() ?? 0
        
        let boundingSize = max(maxX - minX, maxY - minY, maxZ - minZ)
        let cameraDistance = max(boundingSize * 1.5, 15.0)
        
        // 카메라를 체인 중심으로 이동하고 줌인
        // Note: 실제 카메라 제어는 SceneKit에서 처리해야 하므로
        // 여기서는 하이라이트만 토글하고, 카메라 제어는 별도로 구현
        print("Focusing on chain \(chain) at center: \(center), distance: \(cameraDistance)")
    }
    
    // onChainFocus 함수를 클로저로 정의
    private var onChainFocus: ((String?) -> Void) {
        return { chain in
            self.focusOnChain(chain)
        }
    }
    
    // onChainHighlight 함수를 클로저로 정의
    private var onChainHighlight: ((String?) -> Void) {
        return { chain in
            self.highlightedChain = chain
        }
    }
}



