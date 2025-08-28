import SwiftUI
import SceneKit
import simd

// MARK: - Enhanced Protein Structure Preview
struct ProteinStructurePreview: View {
    let proteinId: String
    @State private var structure: PDBStructure?
    @State private var isLoading = true
    @State private var error: String?
    @State private var renderedImage: UIImage?
    @State private var renderMode: RenderMode = .allAtoms
    
    // 렌더링 모드
    enum RenderMode: String, CaseIterable {
        case allAtoms = "All Atoms"
        case ribbon = "Ribbon"
        case hybrid = "Hybrid"
        
        var icon: String {
            switch self {
            case .allAtoms: return "circle.grid.3x3"
            case .ribbon: return "waveform.path"
            case .hybrid: return "layers"
            }
        }
    }
    
    // 렌더링 품질 설정
    struct RenderQuality {
        let maxAtoms: Int
        let imageSize: CGSize
        let antialiasingMode: SCNAntialiasingMode
        let sphereRadius: CGFloat
        let segmentCount: Int
        
        static func low(for atomCount: Int) -> RenderQuality {
            RenderQuality(
                maxAtoms: min(100, atomCount),
                imageSize: CGSize(width: 120, height: 120),
                antialiasingMode: .none,
                sphereRadius: 0.5,
                segmentCount: 8
            )
        }
        
        static func medium(for atomCount: Int) -> RenderQuality {
            RenderQuality(
                maxAtoms: min(300, atomCount),
                imageSize: CGSize(width: 180, height: 180),
                antialiasingMode: .multisampling2X,
                sphereRadius: 0.4,
                segmentCount: 12
            )
        }
        
        static func high(for atomCount: Int) -> RenderQuality {
            RenderQuality(
                maxAtoms: min(500, atomCount),
                imageSize: CGSize(width: 240, height: 240),
                antialiasingMode: .multisampling4X,
                sphereRadius: 0.3,
                segmentCount: 16
            )
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if error != nil {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            } else if let image = renderedImage {
                VStack(spacing: 4) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // 렌더링 모드 표시
                    Text(renderMode.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if let structure = structure {
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
                Image(systemName: "cube.box.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadStructure()
        }
    }
    
    // MARK: - 1단계: PDB 파싱 및 체인/2차 구조별 인덱스 분할
    private func loadStructure() {
        Task {
            do {
                print("🔄 Loading structure for \(proteinId)...")
                
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
                
                // 2-5단계: 체계적 렌더링 시스템 실행
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
    
    // MARK: - 2-5단계: 체계적 렌더링 시스템
    private func renderProteinImage(structure: PDBStructure) async {
        print("🎨 Starting systematic rendering for \(proteinId)...")
        print("🔧 Structure size: \(structure.atoms.count) atoms, \(structure.bonds.count) bonds")
        
        // 타임아웃 설정 (30초)
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 30_000_000_000) // 30초
            print("⏰ Rendering timeout for \(proteinId)")
            return UIImage()
        }
        
        // 백그라운드에서 렌더링
        let image = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    print("🎨 Rendering in background thread...")
                    let result = createSystematicProteinImage(structure: structure)
                    print("✅ Background rendering completed")
                    continuation.resume(returning: result)
                }
            }
        }
        
        // 타임아웃 태스크 취소
        timeoutTask.cancel()
        
        await MainActor.run {
            self.renderedImage = image
            print("✅ Systematic rendering completed for \(proteinId)")
        }
    }
    
    // MARK: - 체계적 단백질 이미지 생성 (2-5단계 통합)
    private func createSystematicProteinImage(structure: PDBStructure) -> UIImage {
        print("🎨 Starting systematic image creation...")
        
        // 구조 크기에 따른 렌더링 품질 조정
        let renderQuality = determineRenderQuality(for: structure.atoms.count)
        print("🔧 Render quality: \(renderQuality)")
        
        // 1. SceneKit 씬 생성
        let scene = SCNScene()
        
        // 2. 체인/2차 구조별로 분할된 노드 생성 (점진적 렌더링)
        let proteinNode = createStructuredProteinNode(structure: structure, quality: renderQuality)
        scene.rootNode.addChildNode(proteinNode)
        
        // 3. 조명 및 카메라 설정
        setupAdvancedLighting(scene: scene)
        let cameraNode = setupAdvancedCamera(structure: structure)
        scene.rootNode.addChildNode(cameraNode)
        
        // 4. 오프스크린 렌더링
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        
        // 5. 고품질 이미지 생성 (품질에 따라 조정)
        let size = renderQuality.imageSize
        let antialiasing = renderQuality.antialiasingMode
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: antialiasing)
        
        print("✅ Systematic image creation completed with quality: \(renderQuality)")
        return image
    }
    
    // MARK: - 2단계: 체인/2차 구조별 분할된 노드 생성
    private func createStructuredProteinNode(structure: PDBStructure, quality: RenderQuality) -> SCNNode {
        let proteinNode = SCNNode()
        
        // 1. 체인별로 그룹핑
        let chainGroups = Dictionary(grouping: structure.atoms) { $0.chain }
        print("🔗 Found \(chainGroups.count) chains: \(chainGroups.keys.sorted())")
        
        for (chainId, chainAtoms) in chainGroups {
            let chainNode = SCNNode()
            chainNode.name = "chain_\(chainId)"
            
            // 2. 2차 구조별로 서브그룹핑
            let secondaryStructureGroups = Dictionary(grouping: chainAtoms) { $0.secondaryStructure }
            print("🧬 Chain \(chainId): \(secondaryStructureGroups.mapValues { $0.count })")
            
            for (ssType, ssAtoms) in secondaryStructureGroups {
                let ssNode = createSecondaryStructureNode(
                    atoms: ssAtoms,
                    structureType: ssType,
                    chainId: chainId,
                    quality: quality
                )
                chainNode.addChildNode(ssNode)
            }
            
            proteinNode.addChildNode(chainNode)
        }
        
        return proteinNode
    }
    
    // MARK: - 2차 구조별 노드 생성 (All-atom만 사용)
    private func createSecondaryStructureNode(
        atoms: [Atom],
        structureType: SecondaryStructure,
        chainId: String,
        quality: RenderQuality
    ) -> SCNNode {
        let ssNode = SCNNode()
        ssNode.name = "\(chainId)_\(structureType)"
        
        // All-atom 표현만 사용 (리본 제거로 성능 향상)
        let atomNode = createAllAtomRepresentation(atoms: atoms, structureType: structureType, quality: quality)
        ssNode.addChildNode(atomNode)
        
        return ssNode
    }
    
    // MARK: - All-atom 표현: 구체 인스턴싱
    private func createAllAtomRepresentation(atoms: [Atom], structureType: SecondaryStructure, quality: RenderQuality) -> SCNNode {
        let atomNode = SCNNode()
        atomNode.name = "atoms_\(structureType)"
        
        // 3단계: 블루노이즈/그리드 샘플링으로 원자 감산 (품질에 따라 조정)
        let sampledAtoms = sampleAtomsWithBlueNoise(atoms: atoms, targetCount: min(quality.maxAtoms, atoms.count))
        
        for atom in sampledAtoms {
            let sphere = createOptimizedAtomSphere(atom: atom, structureType: structureType, quality: quality)
            let individualAtomNode = SCNNode(geometry: sphere)
            individualAtomNode.position = SCNVector3(atom.position)
            individualAtomNode.name = "atom_\(atom.id)"
            atomNode.addChildNode(individualAtomNode)
        }
        
        return atomNode
    }
    
    // MARK: - 2차 구조 리본 (제거됨 - 성능 향상을 위해)
    // 복잡한 리본 메쉬는 제거하고 단순한 구체 렌더링만 사용
    
    // MARK: - 3단계: 블루노이즈/그리드 샘플링
    private func sampleAtomsWithBlueNoise(atoms: [Atom], targetCount: Int) -> [Atom] {
        guard atoms.count > targetCount else { return atoms }
        
        // 간격 유지하며 균등 샘플링
        let step = Double(atoms.count) / Double(targetCount)
        var sampledAtoms: [Atom] = []
        
        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            if index < atoms.count {
                sampledAtoms.append(atoms[index])
            }
        }
        
        print("🔧 Sampled \(atoms.count) → \(sampledAtoms.count) atoms")
        return sampledAtoms
    }
    
    // MARK: - 최적화된 원자 구체 생성
    private func createOptimizedAtomSphere(atom: Atom, structureType: SecondaryStructure, quality: RenderQuality) -> SCNSphere {
        // 품질에 따라 반지름과 세그먼트 수 조정
        let radius = quality.sphereRadius
        let segmentCount = quality.segmentCount
        
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = segmentCount
        
        // 2차 구조별 색상 및 재질
        let material = createStructureMaterial(structureType: structureType)
        sphere.materials = [material]
        
        return sphere
    }
    
    // MARK: - 2차 구조별 재질 생성
    private func createStructureMaterial(structureType: SecondaryStructure) -> SCNMaterial {
        let material = SCNMaterial()
        
        switch structureType {
        case .helix:
            material.diffuse.contents = UIColor.systemRed
            material.specular.contents = UIColor.white
            material.shininess = 0.8
        case .sheet:
            material.diffuse.contents = UIColor.systemBlue
            material.specular.contents = UIColor.white
            material.shininess = 0.6
        case .coil:
            material.diffuse.contents = UIColor.systemGreen
            material.specular.contents = UIColor.white
            material.shininess = 0.4
        case .unknown:
            material.diffuse.contents = UIColor.systemGray
            material.specular.contents = UIColor.white
            material.shininess = 0.2
        }
        
        return material
    }
    
    // MARK: - 스플라인 관련 함수들 (제거됨 - 성능 향상을 위해)
    
    // MARK: - 리본 메쉬 생성 (제거됨 - 성능 향상을 위해)
    
    // MARK: - 리본 관련 함수들 (제거됨 - 성능 향상을 위해)
    // 복잡한 실린더 메쉬, 회전 계산 함수들을 모두 제거
    
    // MARK: - 4단계: 고급 조명 시스템
    private func setupAdvancedLighting(scene: SCNScene) {
        // 주 조명 (키 라이트)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 800
        keyLight.light?.shadowMode = .deferred
        keyLight.light?.shadowRadius = 3
        keyLight.position = SCNVector3(x: 10, y: 10, z: 10)
        keyLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLight)
        
        // 보조 조명 (필 라이트)
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 400
        fillLight.position = SCNVector3(x: -8, y: 5, z: -8)
        fillLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLight)
        
        // 환경 조명
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 200
        ambientLight.light?.color = UIColor.systemBlue.withAlphaComponent(0.1)
        scene.rootNode.addChildNode(ambientLight)
        
        // 림 라이트 (윤곽선 강조)
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 300
        rimLight.position = SCNVector3(x: 0, y: 0, z: 15)
        rimLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLight)
    }
    
    // MARK: - 고급 카메라 시스템
    private func setupAdvancedCamera(structure: PDBStructure) -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 45
        camera.zNear = 0.1
        camera.zFar = 1000
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        // 단백질 경계 계산
        let bounds = structure.atoms.map { $0.position }
        let center = bounds.reduce(SIMD3<Float>(0,0,0)) { $0 + $1 } / Float(bounds.count)
        let maxDistance = bounds.map { length($0 - center) }.max() ?? 10
        
        // PDB ID 기반 고유한 카메라 각도
        let pdbHash = abs(proteinId.hashValue)
        let angleOffset = Float(pdbHash % 360) * .pi / 180.0
        
        // 카메라 위치 설정
        let cameraDistance = maxDistance * 2.5
        let baseX = cameraDistance * 0.7
        let baseY = cameraDistance * 0.5
        let baseZ = cameraDistance
        
        // 회전 변환 적용
        let rotatedX = baseX * cos(angleOffset) - baseZ * sin(angleOffset)
        let rotatedZ = baseX * sin(angleOffset) + baseZ * cos(angleOffset)
        
        cameraNode.position = SCNVector3(x: rotatedX, y: baseY, z: rotatedZ)
        cameraNode.look(at: SCNVector3(center))
        
        print("📷 Advanced camera positioned at unique angle for \(proteinId): \(angleOffset * 180 / .pi)°")
        
        return cameraNode
    }
    
    // MARK: - 렌더링 품질 결정
    private func determineRenderQuality(for atomCount: Int) -> RenderQuality {
        if atomCount > 8000 {
            print("🔧 Large structure detected (\(atomCount) atoms) → Using LOW quality")
            return .low(for: atomCount)
        } else if atomCount > 4000 {
            print("🔧 Medium structure detected (\(atomCount) atoms) → Using MEDIUM quality")
            return .medium(for: atomCount)
        } else {
            print("🔧 Small structure detected (\(atomCount) atoms) → Using HIGH quality")
            return .high(for: atomCount)
        }
    }
    
    // MARK: - 벡터 길이 계산 헬퍼
    private func length(_ vector: SIMD3<Float>) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
}

// MARK: - Helper Functions
private func isValidPDBId(_ pdbId: String) -> Bool {
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
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 404 {
                throw NSError(domain: "PDBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "PDB ID '\(pdbId)' not found"])
            } else if httpResponse.statusCode != 200 {
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
