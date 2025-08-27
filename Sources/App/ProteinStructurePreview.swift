import SwiftUI
import SceneKit

struct ProteinStructurePreview: View {
    let proteinId: String
    @State private var structure: PDBStructure?
    @State private var isLoading = true
    @State private var error: String?
    @State private var renderedImage: UIImage?
    
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
            } else if let image = renderedImage {
                // 렌더링된 이미지 표시
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let structure = structure {
                // 구조는 로드되었지만 이미지 렌더링 중
                VStack(spacing: 4) {
                    Text("Rendering...")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text("\(structure.atoms.count) atoms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                // 데이터 없을 때 기본 아이콘 표시
                Image(systemName: "cube.box.fill")
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
                
                // PDB ID 유효성 검사
                guard isValidPDBId(proteinId) else {
                    throw NSError(domain: "PDBError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid PDB ID: \(proteinId)"])
                }
                
                let loadedStructure = try await loadStructureFromRCSB(pdbId: proteinId)
                print("✅ Successfully loaded structure for \(proteinId): \(loadedStructure.atoms.count) atoms")
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.isLoading = false
                    self.error = nil
                }
                
                // 오프스크린 렌더링으로 이미지 생성
                await renderProteinImage(structure: loadedStructure)
                
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
    
    private func renderProteinImage(structure: PDBStructure) async {
        print("🎨 Starting offscreen rendering for \(proteinId)...")
        
        // 백그라운드 스레드에서 렌더링 (타임아웃 및 성능 최적화)
        let image = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                // 메모리 사용량 제한
                autoreleasepool {
                    let result = createProteinImage(structure: structure)
                    continuation.resume(returning: result)
                }
            }
        }
        
        await MainActor.run {
            self.renderedImage = image
            print("✅ Image rendering completed for \(proteinId)")
        }
    }
    
    private func createProteinImage(structure: PDBStructure) -> UIImage {
        print("🎨 Starting image creation...")
        
        // 1. SceneKit 씬 생성
        let scene = SCNScene()
        print("🎨 Scene created")
        
        // 2. 단백질 노드 생성
        let proteinNode = createProteinNode(structure: structure)
        scene.rootNode.addChildNode(proteinNode)
        print("🎨 Protein node added to scene")
        
        // 3. 조명 설정
        setupLighting(scene: scene)
        print("🎨 Lighting setup completed")
        
        // 4. 카메라 설정
        let cameraNode = setupCamera(structure: structure)
        scene.rootNode.addChildNode(cameraNode)
        print("🎨 Camera setup completed")
        
        // 5. 오프스크린 렌더링
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        print("🎨 Renderer configured")
        
        // 6. 이미지 크기 설정
        let size = CGSize(width: 120, height: 120) // 2x for retina
        print("🎨 Target image size: \(size.width) x \(size.height)")
        
        // 7. 렌더링 실행
        print("🎨 Starting snapshot...")
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        print("🎨 Snapshot completed, image size: \(image.size.width) x \(image.size.height)")
        
        return image
    }
    
    private func createProteinNode(structure: PDBStructure) -> SCNNode {
        let proteinNode = SCNNode()
        
        // 체인별로 그룹핑
        let chains = Dictionary(grouping: structure.atoms, by: { $0.chain })
        
        for (chainId, atoms) in chains {
            let chainNode = SCNNode()
            
            // 체인별 색상 설정
            let chainColor = chainColor(for: chainId)
            
            // 성능 최적화: 원자 수 제한 (더 적극적으로)
            let atomCount = atoms.count
            let maxAtoms = min(300, atomCount) // 500 → 300으로 감소
            let step = max(1, atomCount / maxAtoms)
            
            // 원자 샘플링을 더 효율적으로
            let sampledAtoms = stride(from: 0, to: atomCount, by: step).prefix(maxAtoms).map { atoms[$0] }
            
            for atom in sampledAtoms {
                let sphere = SCNSphere(radius: 0.3) // 0.4 → 0.3으로 감소
                let material = SCNMaterial()
                material.diffuse.contents = chainColor
                material.specular.contents = UIColor.white
                material.shininess = 0.2 // 0.3 → 0.2로 감소
                sphere.materials = [material]
                
                let atomNode = SCNNode(geometry: sphere)
                atomNode.position = SCNVector3(atom.position)
                chainNode.addChildNode(atomNode)
            }
            
            proteinNode.addChildNode(chainNode)
            print("🔧 Chain \(chainId): \(atomCount) atoms → \(sampledAtoms.count) rendered")
        }
        
        return proteinNode
    }
    
    private func setupLighting(scene: SCNScene) {
        // 주 조명
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 1000
        lightNode.position = SCNVector3(x: 10, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // 환경 조명
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.intensity = 300
        scene.rootNode.addChildNode(ambientLightNode)
    }
    
    private func setupCamera(structure: PDBStructure) -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 45
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        // 단백질을 중앙에 보도록 조정
        let bounds = structure.atoms.map { $0.position }
        let center = bounds.reduce(SIMD3<Float>(0,0,0)) { $0 + $1 } / Float(bounds.count)
        let maxDistance = bounds.map { length($0 - center) }.max() ?? 10
        
        // PDB ID 기반으로 카메라 각도 다양화 (고유한 이미지 생성)
        let pdbHash = abs(proteinId.hashValue)
        let angleOffset = Float(pdbHash % 360) * .pi / 180.0
        
        // 카메라 위치 설정 (각도 다양화)
        let cameraDistance = maxDistance * 2.5
        let baseX = cameraDistance * 0.7
        let baseY = cameraDistance * 0.5
        let baseZ = cameraDistance
        
        // 회전 변환 적용
        let rotatedX = baseX * cos(angleOffset) - baseZ * sin(angleOffset)
        let rotatedZ = baseX * sin(angleOffset) + baseZ * cos(angleOffset)
        
        cameraNode.position = SCNVector3(x: rotatedX, y: baseY, z: rotatedZ)
        cameraNode.look(at: SCNVector3(center))
        
        print("📷 Camera positioned at unique angle for \(proteinId): \(angleOffset * 180 / .pi)°")
        
        return cameraNode
    }
    
    private func chainColor(for chain: String) -> UIColor {
        // PDB ID와 체인 ID를 조합하여 고유한 색상 생성
        let combinedHash = abs((proteinId + chain).hashValue)
        let colors: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange, .systemRed,
            .systemPurple, .systemPink, .systemCyan, .systemMint,
            .systemIndigo, .systemTeal, .systemBrown, .systemYellow
        ]
        
        let baseColor = colors[combinedHash % colors.count]
        
        // 명도와 채도도 약간씩 다르게 조정
        let brightness = 0.8 + Float(combinedHash % 40) / 100.0 // 0.8 ~ 1.2
        let saturation = 0.7 + Float(combinedHash % 30) / 100.0 // 0.7 ~ 1.0
        
        return baseColor.withAlphaComponent(CGFloat(saturation))
    }
    
    private func length(_ vector: SIMD3<Float>) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
}

// MARK: - Helper Functions

private func isValidPDBId(_ pdbId: String) -> Bool {
    // PDB ID 형식 검사: 4자리 영문자+숫자 조합
    let pattern = "^[0-9][A-Z0-9]{3}$"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: pdbId.utf16.count)
    return regex.firstMatch(in: pdbId, options: [], range: range) != nil
}

private func loadStructureFromRCSB(pdbId: String) async throws -> PDBStructure {
    let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
    
    print("🌐 Fetching PDB file from: \(url)")
    
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // HTTP 응답 상태 확인
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 404 {
                throw NSError(domain: "PDBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "PDB ID '\(pdbId)' not found. Please check if the ID is correct."])
            } else if httpResponse.statusCode != 200 {
                throw NSError(domain: "PDBError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): Failed to download PDB file for '\(pdbId)'"])
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
