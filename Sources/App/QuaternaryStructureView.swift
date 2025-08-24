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
                subunitsSection(data)
                interfacesSection(data)
                symmetrySection(data)
                stabilityMetricsSection(data)
                biologicalRelevanceSection(data)
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
    
    // MARK: - Subunits Section
    private func subunitsSection(_ data: QuaternaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("서브유닛 분석")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(data.subunits.count)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if data.subunits.isEmpty {
                Text("예시 데이터: 일반적인 단백질은 단일 서브유닛으로 구성")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(16)
                    .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(data.subunits.indices, id: \.self) { index in
                    let subunit = data.subunits[index]
                    subunitCard(subunit)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func subunitCard(_ subunit: Subunit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube.fill")
                    .font(.title3)
                    .foregroundColor(subunit.subunitType.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(subunit.description)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("Chain \(subunit.chainId) \u2022 \(subunit.residueCount) residues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(subunit.weightDescription)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(subunit.subunitType.rawValue)
                        .font(.caption2)
                        .foregroundColor(subunit.subunitType.color)
                }
            }
        }
        .padding(12)
        .background(subunit.subunitType.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Interfaces Section
    private func interfacesSection(_ data: QuaternaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("인터페이스 분석")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(data.interfaces.count)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if data.interfaces.isEmpty {
                Text("예시 데이터: 단일 서브유닛에는 내부 인터페이스가 존재")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(16)
                    .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(data.interfaces.indices, id: \.self) { index in
                    let interface = data.interfaces[index]
                    interfaceCard(interface)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func interfaceCard(_ interface: SubunitInterface) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundColor(interface.interactionStrength.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(interface.partnersDescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(interface.interfaceType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(interface.areaDescription)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(interface.interactionStrength.description)
                        .font(.caption2)
                        .foregroundColor(interface.interactionStrength.color)
                }
            }
            
            HStack {
                Text("수소결합: \(interface.hydrogenbonds)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("염다리: \(interface.saltBridges)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(interface.interactionStrength.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Symmetry Section
    private func symmetrySection(_ data: QuaternaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("대칭성 분석")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                symmetryRow("Point Group", value: data.symmetry.pointGroup, color: .blue)
                symmetryRow("Symmetry Type", value: data.symmetry.symmetryType.displayName, color: .green)
                symmetryRow("Symmetry Order", value: "\(data.symmetry.symmetryOrder)", color: .orange)
                
                HStack {
                    Text("Perfect Symmetry")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: data.symmetry.isPerfectSymmetry ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(data.symmetry.isPerfectSymmetry ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func symmetryRow(_ title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Stability Metrics Section
    private func stabilityMetricsSection(_ data: QuaternaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("안정성 지표")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let deltaG = data.stabilityMetrics.deltaG {
                    stabilityCard("ΔG", value: String(format: "%.1f kcal/mol", deltaG), color: .blue, icon: "thermometer")
                }
                
                if let dissociation = data.stabilityMetrics.dissociationConstant {
                    stabilityCard("Kd", value: String(format: "%.1e M", dissociation), color: .green, icon: "divide")
                }
                
                if let thermal = data.stabilityMetrics.thermalStability {
                    stabilityCard("Tm", value: String(format: "%.1f°C", thermal), color: .red, icon: "flame")
                }
                
                if let cooperativity = data.stabilityMetrics.cooperativity {
                    stabilityCard("Hill Coeff", value: String(format: "%.1f", cooperativity), color: .purple, icon: "arrow.up.right")
                }
            }
            
            if let pHRange = data.stabilityMetrics.pHStability {
                HStack {
                    Text("pH Stability Range")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f - %.1f", pHRange.min, pHRange.max))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func stabilityCard(_ title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Biological Relevance Section
    private func biologicalRelevanceSection(_ data: QuaternaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("생물학적 연관성")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                relevanceRow("Functional State", value: data.biologicalRelevance.functionalState.rawValue, color: data.biologicalRelevance.functionalState.color, icon: "gearshape.fill")
                relevanceRow("Cellular Location", value: data.biologicalRelevance.cellularLocation, color: .blue, icon: "location.fill")
                relevanceRow("Physiological Conditions", value: data.biologicalRelevance.physiologicalConditions, color: .green, icon: "drop.fill")
                relevanceRow("Functional Importance", value: data.biologicalRelevance.functionalImportance.rawValue, color: data.biologicalRelevance.functionalImportance.color, icon: "exclamationmark.triangle.fill")
                
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                    
                    Text("Evolutionary Conservation")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", data.biologicalRelevance.evolutionaryConservation * 100))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.purple)
                }
                
                if !data.biologicalRelevance.diseaseRelevance.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cross.case.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            
                            Text("Disease Relevance")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        
                        ForEach(data.biologicalRelevance.diseaseRelevance, id: \.self) { disease in
                            Text("• \(disease)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func relevanceRow(_ title: String, value: String, color: Color, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
        }
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
