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
                // 로딩 중일 때는 진행 상황 표시
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if error != nil {
                // 에러 시 에러 정보 표시
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("Error")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
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
                print("🔄 Loading structure for \(proteinId)...")
                let loadedStructure = try await loadStructureFromRCSB(pdbId: proteinId)
                print("✅ Successfully loaded structure for \(proteinId): \(loadedStructure.atoms.count) atoms")
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.isLoading = false
                    self.error = nil
                }
            } catch {
                print("❌ Failed to load structure for \(proteinId): \(error.localizedDescription)")
                
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    self.structure = nil
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
            
            // 원자들을 구체로 표현 (성능 최적화)
            let atomCount = atoms.count
            let maxAtoms = 1000 // 성능을 위해 최대 원자 수 제한
            
            if atomCount > maxAtoms {
                // 원자 수가 많을 때는 샘플링하여 표시
                let step = atomCount / maxAtoms
                for i in stride(from: 0, to: atomCount, by: step) {
                    let atom = atoms[i]
                    let sphere = SCNSphere(radius: 0.4)
                    let material = SCNMaterial()
                    material.diffuse.contents = chainColor
                    material.specular.contents = UIColor.white
                    material.shininess = 0.5
                    sphere.materials = [material]
                    
                    let atomNode = SCNNode(geometry: sphere)
                    atomNode.position = SCNVector3(atom.position)
                    chainNode.addChildNode(atomNode)
                }
            } else {
                // 원자 수가 적을 때는 모든 원자 표시
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
            }
            
            proteinNode.addChildNode(chainNode)
        }
        
        return proteinNode
    }
    
    private func createCamera() -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 45 // 더 좁은 시야각으로 집중
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        // 단백질을 중앙에 보도록 조정
        let bounds = structure.atoms.map { $0.position }
        let center = bounds.reduce(SIMD3<Float>(0,0,0)) { $0 + $1 } / Float(bounds.count)
        let maxDistance = bounds.map { length($0 - center) }.max() ?? 10
        
        // 카메라를 단백질 주변에 배치하여 전체 구조를 볼 수 있도록
        let cameraDistance = maxDistance * 2.5
        cameraNode.position = SCNVector3(x: cameraDistance * 0.7, y: cameraDistance * 0.5, z: cameraDistance)
        cameraNode.look(at: SCNVector3(center))
        
        return cameraNode
    }
}

// MARK: - Helper Functions
private func loadStructureFromRCSB(pdbId: String) async throws -> PDBStructure {
    let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
    
    print("🌐 Fetching PDB file from: \(url)")
    
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // HTTP 응답 상태 확인
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                throw NSError(domain: "PDBError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): Failed to download PDB file"])
            }
        }
        
        print("📦 Downloaded \(data.count) bytes")
        
        guard let pdbString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "PDBError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode PDB data as UTF-8"])
        }
        
        print("📝 PDB content length: \(pdbString.count) characters")
        
        let structure = PDBParser.parse(pdbText: pdbString)
        print("🔬 Parsed structure: \(structure.atoms.count) atoms, \(structure.bonds.count) bonds")
        
        return structure
        
    } catch let urlError as URLError {
        print("🌐 Network error: \(urlError.localizedDescription)")
        throw NSError(domain: "PDBError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Network error: \(urlError.localizedDescription)"])
    } catch {
        print("❌ Unexpected error: \(error.localizedDescription)")
        throw error
    }
}

private func length(_ vector: SIMD3<Float>) -> Float {
    return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}
