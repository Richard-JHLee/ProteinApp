import SwiftUI
import SceneKit
import UIKit

// MARK: - Mini 3D Protein Viewer

struct MiniProteinViewer: UIViewRepresentable {
    let pdbId: String
    let category: ProteinCategory
    @State private var structure: PDBStructure? = nil
    @State private var isLoading = true
    
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor.clear
        view.allowsCameraControl = false
        view.antialiasingMode = .none // 성능 최적화
        view.isUserInteractionEnabled = false
        
        // 성능 최적화 설정
        view.preferredFramesPerSecond = 30 // FPS 제한
        view.isPlaying = true
        view.loops = true
        
        // 렌더링 최적화
        view.showsStatistics = false
        view.debugOptions = []
        
        setupScene(view: view)
        loadMiniStructure(view: view)
        
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // No updates needed for mini viewer
    }
    
    private func setupScene(view: SCNView) {
        let scene = SCNScene()
        
        // Simple lighting for mini preview
        let light = SCNLight()
        light.type = .omni
        light.intensity = 500
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(10, 10, 10)
        scene.rootNode.addChildNode(lightNode)
        
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 300
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
        
        view.scene = scene
    }
    
    private func loadMiniStructure(view: SCNView) {
        Task {
            do {
                let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return }
                let text = String(decoding: data, as: UTF8.self)
                let parsedStructure = PDBParser.parse(pdbText: text)
                
                await MainActor.run {
                    self.structure = parsedStructure
                    self.isLoading = false
                    buildMiniScene(view: view, structure: parsedStructure)
                }
            } catch {
                // Fallback to placeholder
                await MainActor.run {
                    self.isLoading = false
                    buildPlaceholder(view: view)
                }
            }
        }
    }
    
    private func buildMiniScene(view: SCNView, structure: PDBStructure) {
        guard let scene = view.scene else { return }
        
        // Clear existing nodes
        scene.rootNode.childNodes.forEach { node in
            if node.light == nil {
                node.removeFromParentNode()
            }
        }
        
        // Simplified representation for mini view - performance optimized
        let backboneAtoms = structure.atoms.filter { $0.isBackbone && $0.name == "CA" }
        let chainGroups = Dictionary(grouping: backboneAtoms) { $0.chain }
        
        for (_, chainAtoms) in chainGroups.prefix(1) { // Only show first chain for performance
            let sortedAtoms = chainAtoms.sorted { $0.residueNumber < $1.residueNumber }
            
            // Further reduce segments for performance
            let step = max(1, sortedAtoms.count / 15) // Maximum 15 segments
            for i in stride(from: 0, to: sortedAtoms.count - step, by: step) {
                guard i + step < sortedAtoms.count else { break }
                let current = sortedAtoms[i]
                let next = sortedAtoms[i + step]
                
                let tube = SceneKitUtils.createCylinderBetween(
                    SCNVector3(current.position.x, current.position.y, current.position.z),
                    SCNVector3(next.position.x, next.position.y, next.position.z),
                    radius: 0.5, // 약간 더 크게 해서 단순화된 모양 보완
                    color: categoryColor(for: category),
                    segments: 6 // 세그먼트 수 감소로 성능 향상
                )
                scene.rootNode.addChildNode(tube)
            }
        }
        
        // Frame the scene
        SceneKitUtils.frameScene(scene, distance: 2.2) // 더 가깝게
        
        // Add slower rotation animation for performance
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 12.0) // 더 느린 회전
        let repeatAction = SCNAction.repeatForever(rotateAction)
        scene.rootNode.runAction(repeatAction)
    }
    
    private func buildPlaceholder(view: SCNView) {
        guard let scene = view.scene else { return }
        
        // Create a simple placeholder shape
        let geometry = SCNSphere(radius: 1.5) // 더 적절한 크기
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(category.color)
        material.specular.contents = UIColor.white
        material.shininess = 32.0
        geometry.materials = [material]
        
        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)
        
        // Add slower rotation for performance
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8.0) // 더 느린 회전
        let repeatAction = SCNAction.repeatForever(rotateAction)
        node.runAction(repeatAction)
        
        // Add camera
        let camera = SCNCamera()
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 6) // 더 가깝게
        scene.rootNode.addChildNode(cameraNode)
    }
    

    
    private func categoryColor(for category: ProteinCategory) -> UIColor {
        switch category {
        case .enzymes: return UIColor.systemBlue
        case .structural: return UIColor.systemOrange
        case .defense: return UIColor.systemRed
        case .transport: return UIColor.systemGreen
        case .hormones: return UIColor.systemPurple
        case .storage: return UIColor.systemBrown
        case .receptors: return UIColor.systemCyan
        case .membrane: return UIColor.systemMint
        case .motor: return UIColor.systemIndigo
        case .signaling: return UIColor.systemPink
        case .chaperones: return UIColor.systemYellow
        case .metabolic: return UIColor.systemTeal
        }
    }
}
