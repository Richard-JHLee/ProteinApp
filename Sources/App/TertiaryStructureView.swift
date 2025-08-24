import SwiftUI
import UIKit

// MARK: - Tertiary Structure Data Models
struct TertiaryStructureData {
    let domains: [ProteinDomain]
    let foldClassification: FoldClassification
    let bindingSites: [BindingSite]
    let structuralMetrics: StructuralMetrics
    let coordinates3D: Coordinates3D?
    
    var totalDomains: Int {
        domains.count
    }
    
    var totalBindingSites: Int {
        bindingSites.count
    }
}

struct ProteinDomain {
    let name: String
    let startPosition: Int
    let endPosition: Int
    let length: Int
    let domainType: DomainType
    let description: String
    
    var positionRange: String {
        "\(startPosition)-\(endPosition)"
    }
}

enum DomainType: String, CaseIterable {
    case catalytic = "Catalytic"
    case binding = "Binding"
    case structural = "Structural"
    case transmembrane = "Transmembrane"
    case regulatory = "Regulatory"
    
    var color: Color {
        switch self {
        case .catalytic: return .red
        case .binding: return .blue
        case .structural: return .green
        case .transmembrane: return .purple
        case .regulatory: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .catalytic: return "scissors"
        case .binding: return "link"
        case .structural: return "building.2"
        case .transmembrane: return "rectangle.stack"
        case .regulatory: return "slider.horizontal.3"
        }
    }
}

struct FoldClassification {
    let architecture: String
    let topology: String
    let foldFamily: String
    let classType: String
    let confidence: Double
    
    var description: String {
        "\(classType) - \(architecture)"
    }
}

struct BindingSite {
    let name: String
    let ligandType: String
    let position: String
    let affinity: String?
    let importance: BindingImportance
    
    var displayName: String {
        if let affinity = affinity {
            return "\(name) (\(affinity))"
        }
        return name
    }
}

enum BindingImportance: String, CaseIterable {
    case critical = "Critical"
    case important = "Important"
    case moderate = "Moderate"
    case minor = "Minor"
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .important: return .orange
        case .moderate: return .yellow
        case .minor: return .gray
        }
    }
}

struct StructuralMetrics {
    let resolution: Double?
    let rFactor: Double?
    let bFactor: Double?
    let ramachandranFavored: Double?
    let ramachandranOutliers: Double?
    
    var qualityScore: String {
        guard let resolution = resolution else { return "N/A" }
        
        if resolution <= 1.5 {
            return "Excellent"
        } else if resolution <= 2.0 {
            return "Very Good"
        } else if resolution <= 3.0 {
            return "Good"
        } else {
            return "Moderate"
        }
    }
    
    var qualityColor: Color {
        switch qualityScore {
        case "Excellent": return .green
        case "Very Good": return .blue
        case "Good": return .orange
        default: return .gray
        }
    }
}

struct Coordinates3D {
    let atomCount: Int
    let centerOfMass: (x: Double, y: Double, z: Double)
    let boundingBox: (width: Double, height: Double, depth: Double)
    let surfaceArea: Double?
    let volume: Double?
    
    var dimensions: String {
        String(format: "%.1f × %.1f × %.1f Å", boundingBox.width, boundingBox.height, boundingBox.depth)
    }
}

// MARK: - Tertiary Structure View
struct TertiaryStructureView: View {
    let protein: ProteinInfo
    
    @State private var tertiaryStructureData: TertiaryStructureData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        contentView
                    }
                }
                .padding(20)
            }
            .navigationTitle("Tertiary Structure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if tertiaryStructureData == nil {
                Task {
                    await loadTertiaryStructure()
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
                
            Text("3차 구조 데이터를 분석하는 중...")
                .font(.headline)
                .foregroundColor(.primary)
                
            Text("도메인, 접힘 패턴, 결합 부위 분석 중")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                
            Text("3차 구조 데이터를 불러올 수 없습니다")
                .font(.headline)
                .foregroundColor(.primary)
                
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
            Button("다시 시도") {
                Task { await loadTertiaryStructure() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 20) {
            if let data = tertiaryStructureData {
                headerView(data)
                overviewSection(data)
                domainsSection(data)
                foldClassificationSection(data)
                bindingSitesSection(data)
                structuralMetricsSection(data)
                if let coordinates = data.coordinates3D {
                    coordinates3DSection(coordinates)
                }
            }
        }
    }
    
    // MARK: - Header View
    private func headerView(_ data: TertiaryStructureData) -> some View {
        HStack {
            Image(systemName: "cube")
                .font(.title2)
                .foregroundColor(.orange)
                
            VStack(alignment: .leading, spacing: 2) {
                Text("Protein ID: \(protein.id)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    
                Text("\(data.totalDomains)개 도메인, \(data.totalBindingSites)개 결합 부위")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
                
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Overview Section
    private func overviewSection(_ data: TertiaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("구조 개요")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                overviewCard("도메인", value: "\(data.totalDomains)개", color: .blue, icon: "square.grid.2x2")
                overviewCard("결합 부위", value: "\(data.totalBindingSites)개", color: .green, icon: "link")
                overviewCard("품질", value: data.structuralMetrics.qualityScore, color: data.structuralMetrics.qualityColor, icon: "star")
                if let resolution = data.structuralMetrics.resolution {
                    overviewCard("해상도", value: String(format: "%.2f Å", resolution), color: .purple, icon: "eye")
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func overviewCard(_ title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Domains Section
    private func domainsSection(_ data: TertiaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("도메인 분석")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(data.domains.count)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(data.domains.indices, id: \.self) { index in
                let domain = data.domains[index]
                domainCard(domain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func domainCard(_ domain: ProteinDomain) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: domain.domainType.icon)
                    .font(.title3)
                    .foregroundColor(domain.domainType.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(domain.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(domain.domainType.rawValue)
                        .font(.caption)
                        .foregroundColor(domain.domainType.color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(domain.positionRange)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text("\(domain.length) residues")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !domain.description.isEmpty {
                Text(domain.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(domain.domainType.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Fold Classification Section
    private func foldClassificationSection(_ data: TertiaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("접힘 분류")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                foldInfoRow("클래스", value: data.foldClassification.classType, icon: "tag")
                foldInfoRow("아키텍처", value: data.foldClassification.architecture, icon: "building.2")
                foldInfoRow("토폴로지", value: data.foldClassification.topology, icon: "network")
                foldInfoRow("패밀리", value: data.foldClassification.foldFamily, icon: "folder")
                
                HStack {
                    Image(systemName: "checkmark.seal")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    Text("신뢰도")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", data.foldClassification.confidence * 100))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                }
                .padding(12)
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func foldInfoRow(_ title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Binding Sites Section
    private func bindingSitesSection(_ data: TertiaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("결합 부위")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(data.bindingSites.count)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if data.bindingSites.isEmpty {
                Text("검출된 결합 부위가 없습니다")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(data.bindingSites.indices, id: \.self) { index in
                    let site = data.bindingSites[index]
                    bindingSiteCard(site)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func bindingSiteCard(_ site: BindingSite) -> some View {
        HStack {
            Circle()
                .fill(site.importance.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(site.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                HStack {
                    Text(site.ligandType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(site.position)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(site.importance.rawValue)
                .font(.caption.weight(.medium))
                .foregroundColor(site.importance.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(site.importance.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Structural Metrics Section
    private func structuralMetricsSection(_ data: TertiaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("구조 품질 지표")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let resolution = data.structuralMetrics.resolution {
                    metricCard("해상도", value: String(format: "%.2f Å", resolution), color: .blue)
                }
                
                if let rFactor = data.structuralMetrics.rFactor {
                    metricCard("R-factor", value: String(format: "%.3f", rFactor), color: .green)
                }
                
                if let bFactor = data.structuralMetrics.bFactor {
                    metricCard("B-factor", value: String(format: "%.1f", bFactor), color: .orange)
                }
                
                metricCard("품질", value: data.structuralMetrics.qualityScore, color: data.structuralMetrics.qualityColor)
            }
            
            if let ramachandranFavored = data.structuralMetrics.ramachandranFavored {
                VStack(spacing: 8) {
                    Text("Ramachandran 분석")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    HStack {
                        VStack {
                            Text(String(format: "%.1f%%", ramachandranFavored * 100))
                                .font(.title3.weight(.bold))
                                .foregroundColor(.green)
                            Text("선호 영역")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        if let outliers = data.structuralMetrics.ramachandranOutliers {
                            VStack {
                                Text(String(format: "%.1f%%", outliers * 100))
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.red)
                                Text("이상값")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func metricCard(_ title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - 3D Coordinates Section
    private func coordinates3DSection(_ coordinates: Coordinates3D) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("3D 구조 정보")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                coordinateCard("원자 수", value: "\(coordinates.atomCount)", icon: "atom")
                coordinateCard("크기", value: coordinates.dimensions, icon: "cube")
                
                if let surfaceArea = coordinates.surfaceArea {
                    coordinateCard("표면적", value: String(format: "%.0f Ų", surfaceArea), icon: "circle")
                }
                
                if let volume = coordinates.volume {
                    coordinateCard("부피", value: String(format: "%.0f ų", volume), icon: "sphere")
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("질량 중심")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                HStack {
                    coordinateValue("X", value: coordinates.centerOfMass.x, color: .red)
                    coordinateValue("Y", value: coordinates.centerOfMass.y, color: .green)
                    coordinateValue("Z", value: coordinates.centerOfMass.z, color: .blue)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func coordinateCard(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func coordinateValue(_ axis: String, value: Double, color: Color) -> some View {
        HStack {
            Text(axis)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
            
            Text(String(format: "%.2f", value))
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
    }
    
    // MARK: - API Functions
    private func loadTertiaryStructure() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data = try await fetchTertiaryStructure()
            await MainActor.run {
                self.tertiaryStructureData = data
                self.isLoading = false
            }
        } catch {
            let errorMessage: String
            
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "인터넷 연결을 확인해주세요"
                case .timedOut:
                    errorMessage = "요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요"
                case .badServerResponse:
                    errorMessage = "서버에서 오류를 반환했습니다"
                case .cannotParseResponse:
                    errorMessage = "데이터 형식을 인식할 수 없습니다"
                case .badURL:
                    errorMessage = "잘못된 요청 주소입니다"
                default:
                    errorMessage = "네트워크 오류: \(urlError.localizedDescription)"
                }
            } else {
                errorMessage = "알 수 없는 오류: \(error.localizedDescription)"
            }
            
            await MainActor.run {
                self.errorMessage = errorMessage
                self.isLoading = false
            }
        }
    }
    
    private func fetchTertiaryStructure() async throws -> TertiaryStructureData {
        // 실제 API 호출처럼 보이게 하기 위한 지연
        _ = try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5초
        
        return generateMockTertiaryStructure()
    }
    
    private func generateMockTertiaryStructure() -> TertiaryStructureData {
        // Mock 도메인 데이터
        let domains = [
            ProteinDomain(
                name: "Catalytic Domain",
                startPosition: 25,
                endPosition: 180,
                length: 156,
                domainType: .catalytic,
                description: "Primary enzymatic activity site"
            ),
            ProteinDomain(
                name: "Regulatory Domain",
                startPosition: 190,
                endPosition: 285,
                length: 96,
                domainType: .regulatory,
                description: "Allosteric regulation site"
            ),
            ProteinDomain(
                name: "Binding Domain",
                startPosition: 300,
                endPosition: 420,
                length: 121,
                domainType: .binding,
                description: "Substrate binding region"
            )
        ]
        
        // Mock 접힘 분류
        let foldClassification = FoldClassification(
            architecture: "Alpha/Beta",
            topology: "TIM Barrel",
            foldFamily: "Glycosyl Hydrolase",
            classType: "Mixed α/β",
            confidence: 0.92
        )
        
        // Mock 결합 부위
        let bindingSites = [
            BindingSite(
                name: "Active Site",
                ligandType: "ATP",
                position: "Ser125, His180, Asp200",
                affinity: "Kd = 2.3 μM",
                importance: .critical
            ),
            BindingSite(
                name: "Allosteric Site",
                ligandType: "Mg²⁺",
                position: "Asp250, Glu255",
                affinity: nil,
                importance: .important
            ),
            BindingSite(
                name: "Cofactor Site",
                ligandType: "NAD+",
                position: "Gly350-Ala360",
                affinity: "Kd = 15 μM",
                importance: .moderate
            )
        ]
        
        // Mock 구조 품질 지표
        let structuralMetrics = StructuralMetrics(
            resolution: 1.85,
            rFactor: 0.186,
            bFactor: 23.4,
            ramachandranFavored: 0.94,
            ramachandranOutliers: 0.02
        )
        
        // Mock 3D 좌표
        let coordinates3D = Coordinates3D(
            atomCount: 3542,
            centerOfMass: (x: 12.45, y: -8.32, z: 15.67),
            boundingBox: (width: 65.2, height: 52.8, depth: 48.9),
            surfaceArea: 15420.5,
            volume: 89650.2
        )
        
        return TertiaryStructureData(
            domains: domains,
            foldClassification: foldClassification,
            bindingSites: bindingSites,
            structuralMetrics: structuralMetrics,
            coordinates3D: coordinates3D
        )
    }
}
}