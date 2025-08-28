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
        
        // 백그라운드에서 렌더링
        let image = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    let result = createSystematicProteinImage(structure: structure)
                    continuation.resume(returning: result)
                }
            }
        }
        
        await MainActor.run {
            self.renderedImage = image
            print("✅ Systematic rendering completed for \(proteinId)")
        }
    }
    
    // MARK: - 체계적 단백질 이미지 생성 (2-5단계 통합)
    private func createSystematicProteinImage(structure: PDBStructure) -> UIImage {
        print("🎨 Starting systematic image creation...")
        
        // 1. SceneKit 씬 생성
        let scene = SCNScene()
        
        // 2. 체인/2차 구조별로 분할된 노드 생성
        let proteinNode = createStructuredProteinNode(structure: structure)
        scene.rootNode.addChildNode(proteinNode)
        
        // 3. 조명 및 카메라 설정
        setupAdvancedLighting(scene: scene)
        let cameraNode = setupAdvancedCamera(structure: structure)
        scene.rootNode.addChildNode(cameraNode)
        
        // 4. 오프스크린 렌더링
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        
        // 5. 고품질 이미지 생성
        let size = CGSize(width: 240, height: 240) // 4x for high quality
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        
        print("✅ Systematic image creation completed")
        return image
    }
    
    // MARK: - 2단계: 체인/2차 구조별 분할된 노드 생성
    private func createStructuredProteinNode(structure: PDBStructure) -> SCNNode {
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
                    chainId: chainId
                )
                chainNode.addChildNode(ssNode)
            }
            
            proteinNode.addChildNode(chainNode)
        }
        
        return proteinNode
    }
    
    // MARK: - 2차 구조별 노드 생성 (All-atom + Ribbon)
    private func createSecondaryStructureNode(
        atoms: [Atom],
        structureType: SecondaryStructure,
        chainId: String
    ) -> SCNNode {
        let ssNode = SCNNode()
        ssNode.name = "\(chainId)_\(structureType)"
        
        // 1. All-atom 표현: 구체 인스턴싱
        let atomNode = createAllAtomRepresentation(atoms: atoms, structureType: structureType)
        ssNode.addChildNode(atomNode)
        
        // 2. 2차 구조 리본: Cα 스플라인 → 리본 메쉬
        let ribbonNode = createRibbonRepresentation(atoms: atoms, structureType: structureType)
        ssNode.addChildNode(ribbonNode)
        
        return ssNode
    }
    
    // MARK: - All-atom 표현: 구체 인스턴싱
    private func createAllAtomRepresentation(atoms: [Atom], structureType: SecondaryStructure) -> SCNNode {
        let atomNode = SCNNode()
        atomNode.name = "atoms_\(structureType)"
        
        // 3단계: 블루노이즈/그리드 샘플링으로 원자 감산
        let sampledAtoms = sampleAtomsWithBlueNoise(atoms: atoms, targetCount: min(200, atoms.count))
        
        for atom in sampledAtoms {
            let sphere = createOptimizedAtomSphere(atom: atom, structureType: structureType)
            let individualAtomNode = SCNNode(geometry: sphere)
            individualAtomNode.position = SCNVector3(atom.position)
            individualAtomNode.name = "atom_\(atom.id)"
            atomNode.addChildNode(individualAtomNode)
        }
        
        return atomNode
    }
    
    // MARK: - 2차 구조 리본: Cα 스플라인 → 리본 메쉬
    private func createRibbonRepresentation(atoms: [Atom], structureType: SecondaryStructure) -> SCNNode {
        let ribbonNode = SCNNode()
        ribbonNode.name = "ribbon_\(structureType)"
        
        // Cα 원자만 추출 (백본)
        let caAtoms = atoms.filter { $0.name == "CA" }
        
        guard caAtoms.count >= 3 else { return ribbonNode }
        
        // 스플라인 곡선 생성
        let spline = createSplineFromAtoms(caAtoms)
        
        // 리본 메쉬 생성
        let ribbonMesh = createRibbonMesh(from: spline, structureType: structureType)
        
        let ribbonGeometryNode = SCNNode(geometry: ribbonMesh)
        ribbonNode.addChildNode(ribbonGeometryNode)
        
        return ribbonNode
    }
    
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
    private func createOptimizedAtomSphere(atom: Atom, structureType: SecondaryStructure) -> SCNSphere {
        let radius: CGFloat
        let segmentCount: Int
        
        // 2차 구조별로 렌더링 품질 조정
        switch structureType {
        case .helix:
            radius = 0.4
            segmentCount = 16
        case .sheet:
            radius = 0.35
            segmentCount = 14
        case .coil:
            radius = 0.3
            segmentCount = 12
        case .unknown:
            radius = 0.25
            segmentCount = 10
        }
        
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
    
    // MARK: - Cα 스플라인 생성
    private func createSplineFromAtoms(_ caAtoms: [Atom]) -> [SCNVector3] {
        var splinePoints: [SCNVector3] = []
        
        for atom in caAtoms {
            splinePoints.append(SCNVector3(atom.position))
        }
        
        // 스플라인 보간 (간단한 선형 보간)
        return interpolateSpline(points: splinePoints, segments: caAtoms.count * 2)
    }
    
    // MARK: - 스플라인 보간
    private func interpolateSpline(points: [SCNVector3], segments: Int) -> [SCNVector3] {
        guard points.count >= 2 else { return points }
        
        var interpolated: [SCNVector3] = []
        
        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]
            
            for j in 0..<segments {
                let t = Float(j) / Float(segments)
                let interpolatedPoint = SCNVector3(
                    start.x + (end.x - start.x) * t,
                    start.y + (end.y - start.y) * t,
                    start.z + (end.z - start.z) * t
                )
                interpolated.append(interpolatedPoint)
            }
        }
        
        return interpolated
    }
    
    // MARK: - 리본 메쉬 생성
    private func createRibbonMesh(from spline: [SCNVector3], structureType: SecondaryStructure) -> SCNGeometry {
        guard spline.count >= 2 else { return SCNGeometry() }
        
        // 간단한 실린더 기반 리본 (실제로는 더 복잡한 메쉬 생성 필요)
        let radius: CGFloat
        let height: CGFloat
        
        switch structureType {
        case .helix:
            radius = 0.3
            height = 0.8
        case .sheet:
            radius = 0.25
            height = 0.6
        case .coil:
            radius = 0.2
            height = 0.4
        case .unknown:
            radius = 0.15
            height = 0.3
        }
        
        // 각 스플라인 포인트에 실린더 생성
        let ribbonNode = SCNNode()
        
        for i in 0..<(spline.count - 1) {
            let start = spline[i]
            let end = spline[i + 1]
            
            let cylinder = SCNCylinder(radius: radius, height: height)
            let material = createStructureMaterial(structureType: structureType)
            cylinder.materials = [material]
            
            let cylinderNode = SCNNode(geometry: cylinder)
            
            // 두 점 사이의 중점과 방향 계산
            let midPoint = SCNVector3(
                (start.x + end.x) / 2,
                (start.y + end.y) / 2,
                (start.z + end.z) / 2
            )
            
            cylinderNode.position = midPoint
            
            // 방향 벡터 계산
            let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
            let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
            
            if length > 0.001 {
                let normalizedDirection = SCNVector3(direction.x / length, direction.y / length, direction.z / length)
                let rotation = calculateRotation(from: SCNVector3(0, 1, 0), to: normalizedDirection)
                cylinderNode.rotation = rotation
            }
            
            ribbonNode.addChildNode(cylinderNode)
        }
        
        // 실제 리본 지오메트리 생성
        return createCompositeRibbonGeometry(from: spline, structureType: structureType)
    }
    
    // MARK: - 복합 리본 지오메트리 생성
    private func createCompositeRibbonGeometry(from spline: [SCNVector3], structureType: SecondaryStructure) -> SCNGeometry {
        guard spline.count >= 2 else { return SCNGeometry() }
        
        // 여러 실린더를 하나의 복합 지오메트리로 결합
        var geometries: [SCNGeometry] = []
        
        for i in 0..<(spline.count - 1) {
            let start = spline[i]
            let end = spline[i + 1]
            
            let radius: CGFloat
            let height: CGFloat
            
            switch structureType {
            case .helix:
                radius = 0.3
                height = 0.8
            case .sheet:
                radius = 0.25
                height = 0.6
            case .coil:
                radius = 0.2
                height = 0.4
            case .unknown:
                radius = 0.15
                height = 0.3
            }
            
            let cylinder = SCNCylinder(radius: radius, height: height)
            let material = createStructureMaterial(structureType: structureType)
            cylinder.materials = [material]
            
            // 실린더를 올바른 위치와 방향으로 변환
            let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
            let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
            
            if length > 0.001 {
                let normalizedDirection = SCNVector3(direction.x / length, direction.y / length, direction.z / length)
                let rotation = calculateRotation(from: SCNVector3(0, 1, 0), to: normalizedDirection)
                
                // 실린더를 올바른 방향으로 회전
                cylinder.transform = SCNMatrix4MakeRotation(rotation.w, rotation.x, rotation.y, rotation.z)
                
                // 중점 위치로 이동
                let midPoint = SCNVector3(
                    (start.x + end.x) / 2,
                    (start.y + end.y) / 2,
                    (start.z + end.z) / 2
                )
                cylinder.transform = SCNMatrix4Mult(cylinder.transform, SCNMatrix4MakeTranslation(midPoint.x, midPoint.y, midPoint.z))
                
                geometries.append(cylinder)
            }
        }
        
        // 복합 지오메트리 생성 (여러 실린더를 하나로 결합)
        if geometries.count == 1 {
            return geometries[0]
        } else if geometries.count > 1 {
            // SCNNode를 사용하여 복합 지오메트리 생성
            let compositeNode = SCNNode()
            for geometry in geometries {
                let node = SCNNode(geometry: geometry)
                compositeNode.addChildNode(node)
            }
            
            // 복합 노드를 지오메트리로 변환 (간단한 박스로 대체)
            let boundingBox = compositeNode.boundingBox
            let box = SCNBox(
                width: CGFloat(boundingBox.max.x - boundingBox.min.x),
                height: CGFloat(boundingBox.max.y - boundingBox.min.y),
                length: CGFloat(boundingBox.max.z - boundingBox.min.z),
                chamferRadius: 0.1
            )
            box.materials = [createStructureMaterial(structureType: structureType)]
            return box
        }
        
        return SCNGeometry()
    }
    
    // MARK: - 회전 계산 헬퍼
    private func calculateRotation(from: SCNVector3, to: SCNVector3) -> SCNVector4 {
        let cross = SCNVector3(
            from.y * to.z - from.z * to.y,
            from.z * to.x - from.x * to.z,
            from.x * to.y - from.y * to.x
        )
        
        let dot = from.x * to.x + from.y * to.y + from.z * to.z
        let angle = acos(max(-1, min(1, dot)))
        
        return SCNVector4(cross.x, cross.y, cross.z, angle)
    }
    
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
