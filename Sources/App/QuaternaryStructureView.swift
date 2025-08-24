import SwiftUI
import UIKit

// MARK: - Quaternary Structure Data Models
struct QuaternaryStructureData {
    let assemblyInfo: AssemblyInfo
    let subunits: [Subunit]
    let interfaces: [SubunitInterface]
    let symmetry: SymmetryInfo
    let stabilityMetrics: StabilityMetrics
    let biologicalRelevance: BiologicalRelevance
    
    var totalSubunits: Int {
        subunits.count
    }
    
    var totalInterfaces: Int {
        interfaces.count
    }
    
    var oligomericState: String {
        assemblyInfo.oligomericState
    }
}

struct AssemblyInfo {
    let assemblyType: AssemblyType
    let oligomericState: String
    let stoichiometry: String
    let molecularWeight: Double
    let assemblyMethod: String
    let confidence: Double
    
    var description: String {
        "\(assemblyType.displayName) - \(oligomericState)"
    }
}

enum AssemblyType: String, CaseIterable {
    case homomer = "Homomer"
    case heteromer = "Heteromer"
    case complex = "Complex"
    case fibril = "Fibril"
    case membrane = "Membrane"
    
    var displayName: String {
        return rawValue
    }
    
    var color: Color {
        switch self {
        case .homomer: return .blue
        case .heteromer: return .green
        case .complex: return .purple
        case .fibril: return .orange
        case .membrane: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .homomer: return "circle.grid.2x2"
        case .heteromer: return "square.grid.3x3"
        case .complex: return "hexagon"
        case .fibril: return "line.3.horizontal"
        case .membrane: return "rectangle.stack"
        }
    }
}

struct Subunit {
    let chainId: String
    let name: String
    let residueCount: Int
    let molecularWeight: Double
    let subunitType: SubunitType
    let copyNumber: Int
    let interactionPartners: [String]
    
    var weightDescription: String {
        String(format: "%.1f kDa", molecularWeight)
    }
    
    var description: String {
        if copyNumber > 1 {
            return "\(name) (×\(copyNumber))"
        }
        return name
    }
}

enum SubunitType: String, CaseIterable {
    case identical = "Identical"
    case similar = "Similar"
    case unique = "Unique"
    
    var color: Color {
        switch self {
        case .identical: return .blue
        case .similar: return .green
        case .unique: return .orange
        }
    }
}

struct SubunitInterface {
    let interfaceId: String
    let chainA: String
    let chainB: String
    let contactArea: Double
    let hydrogenbonds: Int
    let saltBridges: Int
    let interactionStrength: InteractionStrength
    let interfaceType: InterfaceType
    
    var areaDescription: String {
        String(format: "%.0f Ų", contactArea)
    }
    
    var partnersDescription: String {
        "\(chainA) ↔ \(chainB)"
    }
}

enum InteractionStrength: String, CaseIterable {
    case strong = "Strong"
    case moderate = "Moderate"
    case weak = "Weak"
    
    var color: Color {
        switch self {
        case .strong: return .red
        case .moderate: return .orange
        case .weak: return .yellow
        }
    }
    
    var description: String {
        switch self {
        case .strong: return "강한 결합"
        case .moderate: return "중간 결합"
        case .weak: return "약한 결합"
        }
    }
}

enum InterfaceType: String, CaseIterable {
    case crystallographic = "Crystallographic"
    case biological = "Biological"
    case artificial = "Artificial"
    
    var color: Color {
        switch self {
        case .crystallographic: return .blue
        case .biological: return .green
        case .artificial: return .gray
        }
    }
}

// Additional enums and structs for symmetry, stability, and biological relevance...

// MARK: - Quaternary Structure View
struct QuaternaryStructureView: View {
    let protein: ProteinInfo
    
    @State private var quaternaryStructureData: QuaternaryStructureData?
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
            .navigationTitle("Quaternary Structure")
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
            if quaternaryStructureData == nil {
                Task {
                    await loadQuaternaryStructure()
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.purple)
                
            Text("4차 구조 데이터를 분석하는 중...")
                .font(.headline)
                .foregroundColor(.primary)
                
            Text("서브유닛, 인터페이스, 대칭성 분석 중")
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
                
            Text("4차 구조 데이터를 불러올 수 없습니다")
                .font(.headline)
                .foregroundColor(.primary)
                
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
            Button("다시 시도") {
                Task { await loadQuaternaryStructure() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 20) {
            if let data = quaternaryStructureData {
                headerView(data)
                assemblyOverviewSection(data)
                // Additional sections would be implemented here
            }
        }
    }
    
    // MARK: - Header View
    private func headerView(_ data: QuaternaryStructureData) -> some View {
        HStack {
            Image(systemName: "square.grid.3x3")
                .font(.title2)
                .foregroundColor(.purple)
                
            VStack(alignment: .leading, spacing: 2) {
                Text("Protein ID: \(protein.id)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    
                Text("\(data.oligomericState) • \(data.totalSubunits)개 서브유닛")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
                
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Assembly Overview Section
    private func assemblyOverviewSection(_ data: QuaternaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("조립체 개요")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                overviewCard("타입", value: data.assemblyInfo.assemblyType.displayName, color: data.assemblyInfo.assemblyType.color, icon: data.assemblyInfo.assemblyType.icon)
                overviewCard("올리고머", value: data.oligomericState, color: .blue, icon: "circle.grid.2x2")
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
    
    // MARK: - API Functions
    private func loadQuaternaryStructure() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data = try await fetchQuaternaryStructure()
            await MainActor.run {
                self.quaternaryStructureData = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "데이터를 불러올 수 없습니다"
                self.isLoading = false
            }
        }
    }
    
    private func fetchQuaternaryStructure() async throws -> QuaternaryStructureData {
        _ = try await Task.sleep(nanoseconds: 2_000_000_000)
        return generateMockQuaternaryStructure()
    }
    
    private func generateMockQuaternaryStructure() -> QuaternaryStructureData {
        // Mock data generation - simplified version
        let assemblyInfo = AssemblyInfo(
            assemblyType: .homomer,
            oligomericState: "Tetramer",
            stoichiometry: "A4",
            molecularWeight: 124.8,
            assemblyMethod: "Crystallographic",
            confidence: 0.89
        )
        
        // Simplified mock data - more structures would be added in full implementation
        return QuaternaryStructureData(
            assemblyInfo: assemblyInfo,
            subunits: [],
            interfaces: [],
            symmetry: SymmetryInfo(pointGroup: "D2", symmetryType: .dihedral, rotationAxes: [], symmetryOrder: 4, isPerfectSymmetry: false),
            stabilityMetrics: StabilityMetrics(deltaG: -12.5, dissociationConstant: 2.3e-8, thermalStability: 68.5, pHStability: (min: 6.2, max: 8.8), cooperativity: 2.4),
            biologicalRelevance: BiologicalRelevance(functionalState: .active, physiologicalConditions: "pH 7.4, 37°C", cellularLocation: "Cytoplasm", functionalImportance: .essential, evolutionaryConservation: 0.87, diseaseRelevance: ["Metabolic syndrome"])
        )
    }
}

// Additional supporting structures for mock data
struct SymmetryInfo {
    let pointGroup: String
    let symmetryType: SymmetryType
    let rotationAxes: [RotationAxis]
    let symmetryOrder: Int
    let isPerfectSymmetry: Bool
}

enum SymmetryType: String, CaseIterable {
    case dihedral = "Dihedral"
    case cyclic = "Cyclic"
    
    var displayName: String { rawValue }
}

struct RotationAxis {
    let order: Int
    let direction: String
    let description: String
}

struct StabilityMetrics {
    let deltaG: Double?
    let dissociationConstant: Double?
    let thermalStability: Double?
    let pHStability: (min: Double, max: Double)?
    let cooperativity: Double?
}

struct BiologicalRelevance {
    let functionalState: FunctionalState
    let physiologicalConditions: String
    let cellularLocation: String
    let functionalImportance: FunctionalImportance
    let evolutionaryConservation: Double
    let diseaseRelevance: [String]
}

enum FunctionalState: String, CaseIterable {
    case active = "Active"
    case inactive = "Inactive"
    
    var color: Color {
        switch self {
        case .active: return .green
        case .inactive: return .red
        }
    }
}

enum FunctionalImportance: String, CaseIterable {
    case essential = "Essential"
    case important = "Important"
    
    var color: Color {
        switch self {
        case .essential: return .red
        case .important: return .orange
        }
    }
}