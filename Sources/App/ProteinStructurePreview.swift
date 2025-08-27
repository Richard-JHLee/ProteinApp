import SwiftUI
import SceneKit

struct ProteinStructurePreview: View {
    let proteinId: String
    @State private var structure: PDBStructure?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        Group {
            if isLoading {
                // 로딩 중일 때는 기본 아이콘 표시
                Image(systemName: "cube.box")
                    .font(.title2)
                    .foregroundColor(.secondary)
            } else if error != nil {
                // 에러 시 기본 아이콘 표시
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundColor(.red)
            } else if let structure = structure {
                // 3D 구조를 2D 이미지로 렌더링
                ProteinStructureImage(structure: structure)
            } else {
                // 데이터 없을 때 기본 아이콘 표시
                Image(systemName: "cube.box")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadStructure()
        }
    }
    
    private func loadStructure() {
        Task {
            do {
                let loadedStructure = try await loadStructureFromRCSB(pdbId: proteinId)
                await MainActor.run {
                    self.structure = loadedStructure
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// 3D 구조를 2D 이미지로 렌더링하는 뷰
struct ProteinStructureImage: UIViewRepresentable {
    let structure: PDBStructure
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = UIColor.systemBackground
        sceneView.scene = createScene()
        sceneView.allowsCameraControl = false
        sceneView.isUserInteractionEnabled = false
        
        // 카드 크기에 맞는 카메라 설정
        sceneView.pointOfView = createCamera()
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 업데이트 시 새로운 씬 생성
        uiView.scene = createScene()
    }
    
    private func createScene() -> SCNScene {
        let scene = SCNScene()
        
        // 단백질 구조 생성
        let proteinNode = createProteinNode()
        scene.rootNode.addChildNode(proteinNode)
        
        // 조명 설정
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // 환경 조명
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.systemGray5
        scene.rootNode.addChildNode(ambientLightNode)
        
        return scene
    }
    
    private func createProteinNode() -> SCNNode {
        let proteinNode = SCNNode()
        
        // 체인별로 그룹핑
        let chains = Dictionary(grouping: structure.atoms, by: { $0.chain })
        
        for (chainId, atoms) in chains {
            let chainNode = SCNNode()
            
            // 체인별 색상 설정
            let chainColor: UIColor
            switch chainId {
            case "A": chainColor = .systemBlue
            case "B": chainColor = .systemGreen
            case "C": chainColor = .systemOrange
            case "D": chainColor = .systemRed
            case "E": chainColor = .systemPurple
            default: chainColor = .systemGray
            }
            
            // 원자들을 구체로 표현
            for atom in atoms {
                let sphere = SCNSphere(radius: 0.3)
                let material = SCNMaterial()
                material.diffuse.contents = chainColor
                material.specular.contents = UIColor.white
                material.shininess = 0.5
                sphere.materials = [material]
                
                let atomNode = SCNNode(geometry: sphere)
                atomNode.position = SCNVector3(atom.position)
                chainNode.addChildNode(atomNode)
            }
            
            proteinNode.addChildNode(chainNode)
        }
        
        return proteinNode
    }
    
    private func createCamera() -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        
        // 단백질을 중앙에 보도록 조정
        let bounds = structure.atoms.map { $0.position }
        let center = bounds.reduce(SIMD3<Float>(0,0,0)) { $0 + $1 } / Float(bounds.count)
        let maxDistance = bounds.map { length($0 - center) }.max() ?? 10
        
        cameraNode.position = SCNVector3(x: 0, y: 0, z: maxDistance * 2)
        cameraNode.look(at: SCNVector3(center))
        
        return cameraNode
    }
}

// MARK: - Helper Functions
private func loadStructureFromRCSB(pdbId: String) async throws -> PDBStructure {
    let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
    let data = try await URLSession.shared.data(from: url).0
    
    guard let pdbString = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "PDBError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode PDB data"])
    }
    
            return PDBParser.parse(pdbText: pdbString)
}

private func length(_ vector: SIMD3<Float>) -> Float {
    return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}
