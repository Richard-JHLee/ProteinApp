import SwiftUI
import SceneKit

// MARK: - Position3D Type Definition
struct Position3D {
    let x: Double
    let y: Double
    let z: Double
    
    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - Enhanced Protein Viewer
struct EnhancedProteinViewerView: View {
    let protein: ProteinInfo
    
    @State private var structure: PDBStructure?
    @State private var isLoading = false
    @State private var error: String?
    
    // Viewer States
    @State private var style: RenderStyle = .cartoon
    @State private var colorMode: ColorMode = .chain
    @State private var uniformColor: Color = .blue
    @State private var autoRotate = false
    @State private var selectedAtom: Atom?
    
    // Tab Selection
    @State private var selectedTab: ViewerTab = .chains
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Header
                enhancedHeaderView
                
                // Main 3D Viewer
                ZStack {
                    ProteinSceneView(
                        structure: structure,
                        style: style,
                        colorMode: colorMode,
                        uniformColor: UIColor(uniformColor),
                        autoRotate: autoRotate,
                        onSelectAtom: { atom in
                            selectedAtom = atom
                        }
                    )
                    .background(Color.black)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    if isLoading {
                        ProgressView("Loading structure...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial)
                    }
                    
                    if let error = error {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial)
                    }
                }
                
                // Enhanced Bottom Panel (Tab 형식)
                enhancedBottomPanel
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task { await loadStructure() }
        }
    }
    
    // MARK: - Enhanced Header
    private var enhancedHeaderView: some View {
        HStack {
            // Back Button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(protein.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    // PDB ID
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(protein.id.uppercased())
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Resolution (Mock data)
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("2.1 Å")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Category
                    Text(protein.category.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundColor(protein.category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(protein.category.color.opacity(0.1), in: Capsule())
                }
            }
            
            Spacer()
            
            // Control Buttons
            HStack(spacing: 12) {
                // Rotate Toggle
                Button(action: { autoRotate.toggle() }) {
                    Image(systemName: autoRotate ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(autoRotate ? .orange : .blue)
                }
                
                // Share Button
                shareButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private var shareButton: some View {
        Menu {
            Button(action: { exportImage() }) {
                Label("Save Image", systemImage: "photo")
            }
            
            Button(action: { exportVideo() }) {
                Label("Export Video", systemImage: "video")
            }
            
            Button(action: { shareStructure() }) {
                Label("Share Structure", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Enhanced Bottom Panel
    private var enhancedBottomPanel: some View {
        VStack(spacing: 0) {
            // Tab Selector
            tabSelector
            
            // Tab Content
            TabView(selection: $selectedTab) {
                chainsTabView
                    .tag(ViewerTab.chains)
                
                residuesTabView
                    .tag(ViewerTab.residues)
                
                Text("💊 Ligands Tab\n구현 예정")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .tag(ViewerTab.ligands)
                
                Text("🔬 Pockets Tab\n구현 예정")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .tag(ViewerTab.pockets)
                
                Text("📖 Annotations Tab\n구현 예정")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .tag(ViewerTab.annotations)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)
        }
        .background(.ultraThinMaterial)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ViewerTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                        
                        Text(tab.title)
                            .font(.caption.weight(.medium))
                            .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(selectedTab.color)
                .animation(.spring(response: 0.3), value: selectedTab),
            alignment: .bottom
        )
    }
    
    // MARK: - Chains Tab (기본 구현)
    private var chainsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("🧬 Protein Chains")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let structure = structure {
                        let uniqueChains = Set(structure.atoms.map { $0.chain })
                        Text("\(uniqueChains.count) chains")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Chain Information
                if let structure = structure {
                    let chainGroups = Dictionary(grouping: structure.atoms) { $0.chain }
                    ForEach(chainGroups.keys.sorted(), id: \.self) { chainId in
                        chainCard(chainId: chainId, atoms: chainGroups[chainId] ?? [])
                    }
                } else {
                    Text("No structure loaded")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }
    
    private func chainCard(chainId: String, atoms: [Atom]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chain Header
            HStack {
                // Chain Chip
                HStack(spacing: 6) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 12, height: 12)
                    
                    Text("Chain \(chainId)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.1), in: Capsule())
                
                Spacer()
                
                Text("\(atoms.count) atoms")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            // Chain Actions
            HStack(spacing: 8) {
                Button(action: { highlightChain(chainId) }) {
                    Label("Highlight", systemImage: "eye")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
                
                Button(action: { focusOnChain(chainId) }) {
                    Label("Focus", systemImage: "scope")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Residues Tab
    private var residuesTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("🧩 Secondary Structure")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("Color Legend")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Secondary Structure Legend
                secondaryStructureLegend
                
                // Secondary Structure Statistics
                if let structure = structure {
                    secondaryStructureStats(for: structure)
                } else {
                    Text("No structure loaded")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
                
                // Selected Residue Details
                selectedResidueDetails
            }
            .padding()
        }
    }
    
    private var secondaryStructureLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Secondary Structure Color Scheme")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                legendItem("Alpha Helix", color: .red, icon: "tornado", description: "Right-handed spiral structure")
                legendItem("Beta Sheet", color: .blue, icon: "rectangle.stack", description: "Extended strand structure")
                legendItem("Turn/Loop", color: .green, icon: "arrow.turn.up.right", description: "Connecting regions")
                legendItem("Random Coil", color: .gray, icon: "scribble", description: "Unstructured regions")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func legendItem(_ name: String, color: Color, icon: String, description: String) -> some View {
        HStack(spacing: 12) {
            // Color indicator and icon
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func secondaryStructureStats(for structure: PDBStructure) -> some View {
        let totalAtoms = structure.atoms.count
        let helixCount = structure.atoms.filter { $0.secondaryStructure == .helix }.count
        let sheetCount = structure.atoms.filter { $0.secondaryStructure == .sheet }.count
        let coilCount = structure.atoms.filter { $0.secondaryStructure == .coil }.count
        let unknownCount = structure.atoms.filter { $0.secondaryStructure == .unknown }.count
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Structure Distribution")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                if totalAtoms > 0 {
                    structureBar("Alpha Helix", count: helixCount, total: totalAtoms, color: .red)
                    structureBar("Beta Sheet", count: sheetCount, total: totalAtoms, color: .blue)
                    structureBar("Turn/Loop", count: coilCount, total: totalAtoms, color: .green)
                    structureBar("Random Coil", count: unknownCount, total: totalAtoms, color: .gray)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func structureBar(_ name: String, count: Int, total: Int, color: Color) -> some View {
        let percentage = total > 0 ? Int((Double(count) / Double(total)) * 100) : 0
        
        return VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(count) atoms (\(percentage)%)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(color)
            }
            
            ProgressView(value: Double(count), total: Double(total))
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 1.5)
        }
    }
    
    private var selectedResidueDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Residue Information")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            if let atom = selectedAtom {
                selectedResidueCard(atom)
            } else {
                Text("Tap on a residue in the 3D view to see details")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func selectedResidueCard(_ atom: Atom) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(atom.residueName) \(atom.residueNumber)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Chain \(atom.chain)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.gray.opacity(0.2), in: Capsule())
            }
            
            Text("Atom: \(atom.name) (\(atom.element))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Secondary Structure:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(secondaryStructureName(atom.secondaryStructure))
                    .font(.caption.weight(.medium))
                    .foregroundColor(secondaryStructureColor(atom.secondaryStructure))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(secondaryStructureColor(atom.secondaryStructure).opacity(0.1), in: Capsule())
            }
            
            Text("Position: (\(String(format: "%.1f", atom.position.x)), \(String(format: "%.1f", atom.position.y)), \(String(format: "%.1f", atom.position.z)))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(secondaryStructureColor(atom.secondaryStructure).opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func secondaryStructureName(_ ss: SecondaryStructure) -> String {
        switch ss {
        case .helix: return "Alpha Helix"
        case .sheet: return "Beta Sheet"
        case .coil: return "Turn/Loop"
        case .unknown: return "Random Coil"
        }
    }
    
    private func secondaryStructureColor(_ ss: SecondaryStructure) -> Color {
        switch ss {
        case .helix: return .red
        case .sheet: return .blue
        case .coil: return .green
        case .unknown: return .gray
        }
    }
    
    // MARK: - Functions
    private func loadStructure() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            // Simulate loading with mock data
            _ = try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Mock structure data - in real implementation, load from PDB API
            let mockStructure = generateMockStructure()
            
            await MainActor.run {
                self.structure = mockStructure
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func generateMockStructure() -> PDBStructure {
        // Simplified mock structure using existing SIMD3<Float> type
        var atoms: [Atom] = []
        var bonds: [Bond] = []
        
        // Create a simple helix for Chain A (Alpha Helix)
        for i in 0..<10 {
            let angle = Double(i) * 0.3
            let x = cos(angle) * 5.0
            let y = Double(i) * 1.5
            let z = sin(angle) * 5.0
            
            atoms.append(Atom(
                id: i,
                element: "C",
                name: "CA",
                chain: "A",
                residueName: "ALA",
                residueNumber: i + 1,
                position: SIMD3<Float>(Float(x), Float(y), Float(z)),
                secondaryStructure: .helix,
                isBackbone: true
            ))
            
            if i > 0 {
                bonds.append(Bond(a: i-1, b: i))
            }
        }
        
        // Add beta sheet structure for Chain A
        for i in 10..<15 {
            let x = Double(i - 10) * 2.0 - 5.0
            let y = 15.0
            let z = 0.0
            
            atoms.append(Atom(
                id: i,
                element: "C",
                name: "CA",
                chain: "A",
                residueName: "VAL",
                residueNumber: i + 1,
                position: SIMD3<Float>(Float(x), Float(y), Float(z)),
                secondaryStructure: .sheet,
                isBackbone: true
            ))
            
            if i > 10 {
                bonds.append(Bond(a: i-1, b: i))
            }
        }
        
        // Add turn/loop structure for Chain A
        for i in 15..<18 {
            let x = Double(i - 15) * 1.0 + 5.0
            let y = Double(i - 15) * 2.0 + 10.0
            let z = Double(i - 15) * 1.5
            
            atoms.append(Atom(
                id: i,
                element: "C",
                name: "CA",
                chain: "A",
                residueName: "GLY",
                residueNumber: i + 1,
                position: SIMD3<Float>(Float(x), Float(y), Float(z)),
                secondaryStructure: .coil,
                isBackbone: true
            ))
            
            if i > 15 {
                bonds.append(Bond(a: i-1, b: i))
            }
        }
        
        // Add a few atoms for Chain B (Random coil)
        for i in 18..<23 {
            let x = Double(i - 18) * 1.5 + 8.0
            let y = 0.0
            let z = 10.0
            
            atoms.append(Atom(
                id: i,
                element: "C",
                name: "CA",
                chain: "B",
                residueName: "PRO",
                residueNumber: i - 17,
                position: SIMD3<Float>(Float(x), Float(y), Float(z)),
                secondaryStructure: .unknown,
                isBackbone: true
            ))
            
            if i > 18 {
                bonds.append(Bond(a: i-1, b: i))
            }
        }
        
        return PDBStructure(atoms: atoms, bonds: bonds)
    }
    
    // Share Functions
    private func exportImage() {
        print("Exporting image...")
    }
    
    private func exportVideo() {
        print("Exporting video...")
    }
    
    private func shareStructure() {
        print("Sharing structure...")
    }
    
    // Chain Functions
    private func highlightChain(_ chainId: String) {
        print("Highlighting chain: \(chainId)")
    }
    
    private func focusOnChain(_ chainId: String) {
        print("Focusing on chain: \(chainId)")
    }
}

// MARK: - Supporting Enums
enum ViewerTab: String, CaseIterable {
    case chains = "Chains"
    case residues = "Residues"
    case ligands = "Ligands"
    case pockets = "Pockets"
    case annotations = "Annotations"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .chains: return "link"
        case .residues: return "dna"
        case .ligands: return "pills"
        case .pockets: return "scope"
        case .annotations: return "book"
        }
    }
    
    var color: Color {
        switch self {
        case .chains: return .blue
        case .residues: return .green
        case .ligands: return .purple
        case .pockets: return .orange
        case .annotations: return .red
        }
    }
}
