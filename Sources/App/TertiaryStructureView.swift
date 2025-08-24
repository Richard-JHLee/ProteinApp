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
    
    // MARK: - Additional sections would continue here...
    // (Fold Classification, Binding Sites, Structural Metrics, 3D Coordinates)
    
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
            await MainActor.run {
                self.errorMessage = "데이터를 불러올 수 없습니다"
                self.isLoading = false
            }
        }
    }
    
    private func fetchTertiaryStructure() async throws -> TertiaryStructureData {
        _ = try await Task.sleep(nanoseconds: 1_500_000_000)
        return generateMockTertiaryStructure()
    }
    
    private func generateMockTertiaryStructure() -> TertiaryStructureData {
        // Mock data generation
        let domains = [
            ProteinDomain(name: "Catalytic Domain", startPosition: 25, endPosition: 180, length: 156, domainType: .catalytic, description: "Primary enzymatic activity site")
        ]
        
        let foldClassification = FoldClassification(architecture: "Alpha/Beta", topology: "TIM Barrel", foldFamily: "Glycosyl Hydrolase", classType: "Mixed α/β", confidence: 0.92)
        
        let bindingSites = [
            BindingSite(name: "Active Site", ligandType: "ATP", position: "Ser125, His180, Asp200", affinity: "Kd = 2.3 μM", importance: .critical)
        ]
        
        let structuralMetrics = StructuralMetrics(resolution: 1.85, rFactor: 0.186, bFactor: 23.4, ramachandranFavored: 0.94, ramachandranOutliers: 0.02)
        
        let coordinates3D = Coordinates3D(atomCount: 3542, centerOfMass: (x: 12.45, y: -8.32, z: 15.67), boundingBox: (width: 65.2, height: 52.8, depth: 48.9), surfaceArea: 15420.5, volume: 89650.2)
        
        return TertiaryStructureData(domains: domains, foldClassification: foldClassification, bindingSites: bindingSites, structuralMetrics: structuralMetrics, coordinates3D: coordinates3D)
    }
}