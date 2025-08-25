import SwiftUI
import SceneKit
import UIKit

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
    // ✅ Tab Selection (주석 해제/복원)
    @State private var selectedTab: ViewerTab = .chains

    // ✅ 전역 enum 삭제하고, 이 중첩 enum만 사용
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
    // Data States
    @State private var ligandsData: [LigandModel] = []
    @State private var pocketsData: [PocketModel] = []
    @State private var annotationsData: AnnotationData?
    
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
                        style: computedRenderStyle,  // Use computed render style
                        colorMode: computedColorMode,  // Use computed color mode
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
    
    // Computed property to automatically change render style and color mode based on selected tab
    private var computedRenderStyle: RenderStyle {
        switch selectedTab {
        case .residues:
            // For residues tab, use cartoon style for better secondary structure visualization
            return .cartoon
        default:
            return style
        }
    }
    
    private var computedColorMode: ColorMode {
        switch selectedTab {
        case .residues:
            return .secondaryStructure
        default:
            return colorMode
        }
    }
    
    // Override the color mode buttons when in residues tab
    private var isColorModeLocked: Bool {
        selectedTab == .residues
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
                
                ligandsTabView
                    .tag(ViewerTab.ligands)
                
                pocketsTabView
                    .tag(ViewerTab.pockets)
                
                annotationsTabView
                    .tag(ViewerTab.annotations)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)
            
            // Render Style Selection (hidden in Residues tab)
            if selectedTab != .residues {
                renderStyleSelector
                    .padding(.vertical, 10)
                    .disabled(isLoading)
            }
            
            // Color Mode Selection (hidden in Residues tab)
            if selectedTab != .residues {
                colorModeSelector
                    .padding(.vertical, 10)
                    .disabled(isLoading)
            }
        }
        .background(.ultraThinMaterial)
        .disabled(isLoading)
    }
    
    private var renderStyleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(RenderStyle.allCases, id: \.self) { renderStyle in
                    StyleButton(
                        style: renderStyle,
                        isSelected: self.style == renderStyle
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            self.style = renderStyle
                        }
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var colorModeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ColorMode.allCases.filter { $0 != .secondaryStructure }, id: \.self) { colorMode in
                    ColorButton(
                        colorMode: colorMode,
                        isSelected: self.colorMode == colorMode
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            self.colorMode = colorMode
                        }
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }
                
                if self.colorMode == .uniform {
                    ColorPicker("Custom", selection: $uniformColor)
                        .labelsHidden()
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ViewerTab.allCases, id: \.self) { tab in
                Button(action: { 
                    withAnimation {
                        // 이전 탭 상태 저장
                        let oldTab = selectedTab
                        // 새 탭 설정
                        selectedTab = tab
                        
                        // 렌더링 갱신을 강제하기 위한 코드
                        // 탭이 실제로 변경된 경우에만 실행
                        if oldTab != tab {
                            // 필요한 경우 강제로 레이아웃 갱신
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // 렌더링 스타일 및 색상 모드 강제 갱신
                                if tab == .residues {
                                    style = .cartoon // 일시적으로 설정하여 UI 업데이트 트리거
                                    colorMode = .secondaryStructure
                                    // 원래 상태로 복원하지 않음 (computed property가 처리함)
                                }
                            }
                        }
                    }
                }) {
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
    
    // MARK: - Ligands Tab
    private var ligandsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("💊 Ligands & Small Molecules")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(ligandsData.count) ligands")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if ligandsData.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "pills")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No ligands found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("This protein structure doesn't contain any ligands or small molecules")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // Ligand Cards
                    ForEach(ligandsData) { ligand in
                        LigandCard(ligand: ligand) {
                            focusOnLigand(ligand)
                        }
                    }
                    
                    // Ligand Analysis Summary
                    LigandAnalysisSummary(ligands: ligandsData)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Pockets Tab
    private var pocketsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("🔬 Binding Pockets")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(pocketsData.count) pockets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if pocketsData.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "scope")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No pockets detected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Pocket detection analysis hasn't been performed or no significant binding sites were found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // Pocket Cards
                    ForEach(pocketsData) { pocket in
                        PocketCard(pocket: pocket) {
                            viewPocket(pocket)
                        }
                    }
                    
                    // Pocket Analysis Summary
                    PocketAnalysisSummary(pockets: pocketsData)
                }
            }
            .padding()
        }
    }
    
    private func viewPocket(_ pocket: PocketModel) {
        print("Viewing pocket: \(pocket.name)")
        // TODO: Implement pocket visualization in 3D viewer
    }
    
    // MARK: - Annotations Tab
    private var annotationsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("📖 Protein Annotations")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                if let annotations = annotationsData {
                    VStack(spacing: 16) {
                        // Function Description
                        functionCard(annotations)
                        
                        // Gene Information
                        geneCard(annotations)
                        
                        // Organism Information
                        organismCard(annotations)
                        
                        // GO Terms
                        goTermsCard(annotations)
                        
                        // Pathways
                        pathwaysCard(annotations)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "book")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No annotations available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Annotation data is still being processed or not available for this protein")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Annotation Functions
    private func functionCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "function")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Protein Function")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(annotations.function)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func geneCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dna")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Gene Information")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                Text("Gene Symbol:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Text(annotations.gene)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.1), in: Capsule())
            }
        }
        .padding(16)
        .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func organismCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Organism")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                Text("Species:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Text(annotations.organism)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .italic()
            }
        }
        .padding(16)
        .background(.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func goTermsCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Gene Ontology Terms")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(annotations.goTerms.count) terms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(annotations.goTerms, id: \.self) { term in
                    Text(term)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(16)
        .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func pathwaysCard(_ annotations: AnnotationData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text("Biological Pathways")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(annotations.pathways.count) pathways")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(annotations.pathways, id: \.self) { pathway in
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        
                        Text(pathway)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Functions
    #if DEBUG
    private func loadStructureMock() async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            _ = try await Task.sleep(nanoseconds: 1_000_000_000)
            let mock = generateMockStructure()
            await MainActor.run {
                self.structure = mock
                self.ligandsData = generateMockLigands()
                self.pocketsData = generateMockPockets()
                self.annotationsData = generateMockAnnotations()
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
        }
    }
    #endif
    
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
    
    private func loadAdditionalData() {
        // Mock data for tabs
        ligandsData = generateMockLigands()
        pocketsData = generateMockPockets()
        annotationsData = generateMockAnnotations()
    }
    
    private func generateMockAnnotations() -> AnnotationData {
        return AnnotationData(
            function: "ATP synthase catalyzes the synthesis of ATP from ADP and inorganic phosphate using the proton gradient across the inner mitochondrial membrane. This enzyme is essential for cellular energy production and is highly conserved across species. It plays a crucial role in oxidative phosphorylation.",
            gene: "ATP5F1A",
            organism: "Homo sapiens (Human)",
            goTerms: [
                "GO:0005524", // ATP binding
                "GO:0016887", // ATPase activity
                "GO:0015986", // ATP synthesis
                "GO:0005739", // Mitochondrion
                "GO:0045261", // Proton-transporting ATP synthase complex
                "GO:0006754"  // ATP biosynthetic process
            ],
            pathways: [
                "Oxidative Phosphorylation",
                "ATP Synthesis",
                "Mitochondrial Electron Transport Chain",
                "Energy Metabolism",
                "Cellular Respiration"
            ]
        )
    }
    
    private func generateMockLigands() -> [LigandModel] {
        return [
            LigandModel(
                name: "ATP", 
                description: "Adenosine Triphosphate - Primary energy carrier", 
                position: SIMD3<Float>(12.5, 8.3, -4.1),
                molecularWeight: 0.507,
                charge: -4.0,
                type: "Nucleotide"
            ),
            LigandModel(
                name: "MG", 
                description: "Magnesium Ion - Cofactor for enzymatic activity", 
                position: SIMD3<Float>(15.2, 7.8, -3.8),
                molecularWeight: 0.024,
                charge: 2.0,
                type: "Metal Ion"
            ),
            LigandModel(
                name: "NAD", 
                description: "Nicotinamide Adenine Dinucleotide - Electron carrier", 
                position: SIMD3<Float>(-8.7, 12.1, 6.4),
                molecularWeight: 0.663,
                charge: -1.0,
                type: "Coenzyme"
            ),
            LigandModel(
                name: "FAD", 
                description: "Flavin Adenine Dinucleotide - Redox cofactor", 
                position: SIMD3<Float>(3.2, -5.6, 9.8),
                molecularWeight: 0.785,
                charge: -2.0,
                type: "Coenzyme"
            )
        ]
    }
    
    private func generateMockPockets() -> [PocketModel] {
        return [
            PocketModel(
                name: "Active Site", 
                score: 0.89, 
                volume: 1450, 
                description: "Primary ATP binding site with high druggability",
                druggability: "High"
            ),
            PocketModel(
                name: "Allosteric Site", 
                score: 0.72, 
                volume: 820, 
                description: "Regulatory binding site for allosteric modulators",
                druggability: "Medium"
            ),
            PocketModel(
                name: "Cofactor Binding", 
                score: 0.65, 
                volume: 450, 
                description: "Magnesium ion coordination site",
                druggability: "Medium"
            ),
            PocketModel(
                name: "Substrate Channel", 
                score: 0.58, 
                volume: 680, 
                description: "Substrate entry channel with moderate binding potential",
                druggability: "Low"
            )
        ]
    }
    
    // MARK: - Ligand Functions
    private func focusOnLigand(_ ligand: LigandModel) {
        print("Focusing on ligand: \(ligand.name)")
        // TODO: Implement camera focus and zoom on specific ligand
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
    
    /// 실제 로딩(병렬 호출) — 기존 mock 흐름 대체
    fileprivate func loadStructure() async {
        await MainActor.run { isLoading = true; error = nil }

        // Try to load structure from RCSB first
        let structure: PDBStructure
        do {
            structure = try await loadStructureFromRCSB(pdbId: protein.id)
        } catch {
            await MainActor.run {
                self.error = "Failed to load structure from RCSB: \(error.localizedDescription)"
                self.structure = self.generateMockStructure()
                self.isLoading = false
            }
            return
        }
        
        // Load ligand metadata
        let ligMeta: [LigandModel]
        do {
            ligMeta = try await fetchLigandsMetaFromPDBe(pdbId: protein.id)
        } catch {
            await MainActor.run {
                self.error = "Failed to load ligand metadata from PDBe: \(error.localizedDescription)"
                self.structure = structure
                self.ligandsData = self.generateMockLigands()
                self.isLoading = false
            }
            return
        }
        
        // Map PDB to UniProt
        let uni: String?
        do {
            uni = try await mapPDBtoUniProt(protein.id)
        } catch {
            await MainActor.run {
                self.error = "Failed to map PDB to UniProt: \(error.localizedDescription)"
                self.structure = structure
                self.ligandsData = ligMeta
                self.isLoading = false
            }
            return
        }
        
        // Fetch annotations if UniProt mapping exists
        let annotations: AnnotationData?
        if let uni = uni {
            do {
                annotations = try await fetchAnnotations(uniprot: uni)
            } catch {
                await MainActor.run {
                    self.error = "Failed to fetch annotations from UniProt: \(error.localizedDescription)"
                    self.structure = structure
                    self.ligandsData = mergeLigands(meta: ligMeta, with: structure)
                    self.annotationsData = self.generateMockAnnotations()
                    self.isLoading = false
                }
                return
            }
        } else {
            annotations = nil
        }

        await MainActor.run {
            self.structure = structure
            self.ligandsData = mergeLigands(meta: ligMeta, with: structure)
            self.annotationsData = annotations ?? self.generateMockAnnotations()
            self.pocketsData = generatePocketsFromStructure(structure)
            self.isLoading = false
        }
    }
    // MARK: - Pockets (lightweight heuristic)
    // 목적: 구조 내 원자 밀도와 리간드 인접성을 이용해 간단히 포켓 후보를 생성
    func generatePocketsFromStructure(_ structure: PDBStructure) -> [PocketModel] {
        // 체인 단위로 그룹핑
        let chains = Dictionary(grouping: structure.atoms, by: { $0.chain })
        var pockets: [PocketModel] = []

        for (idx, pair) in chains.enumerated() {
            let chainId = pair.key
            let atoms = pair.value
            guard atoms.count >= 12 else { continue }

            // 중심점(centroid)과 평균 거리로 밀도 근사
            let center = atoms.reduce(SIMD3<Float>(0,0,0)) { $0 + $1.position } / Float(atoms.count)
            let avgDist = atoms.map { length($0.position - center) }.reduce(0,+) / Float(atoms.count)
            let densityScore = max(0.0, min(1.0, 1.0 / Double(avgDist + 0.001)))   // 거리가 작을수록 조밀 → 점수↑
            let volume = Int(max(300, min(1800, Double(atoms.count) * Double(avgDist) * 8.0)))

            let score = min(0.95, 0.55 + densityScore * 0.4)
            let druggability = score > 0.85 ? "High" : (score > 0.7 ? "Medium" : "Low")

            pockets.append(
                PocketModel(
                    name: "Binding Site \(idx + 1) – Chain \(chainId)",
                    score: score,
                    volume: volume,
                    description: "Heuristic pocket near chain \(chainId) centroid",
                    druggability: druggability
                )
            )
        }
        return pockets
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

// MARK: - Ligand Model
struct LigandModel: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let position: SIMD3<Float>
    let molecularWeight: Double // in kDa
    let charge: Double
    let type: String
}

// MARK: - Ligand Card View
struct LigandCard: View {
    let ligand: LigandModel
    let onFocus: () -> Void
    
    var body: some View {
        Button(action: onFocus) {
            HStack(spacing: 12) {
                // Ligand Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "pills.fill")
                        .font(.title3)
                        .foregroundColor(Color.purple)
                }
                
                // Ligand Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(ligand.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(ligand.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Label("Position", systemImage: "location")
                            .font(.caption)
                            .foregroundColor(Color.blue)
                        
                        Text("(\(String(format: "%.1f", ligand.position.x)), \(String(format: "%.1f", ligand.position.y)), \(String(format: "%.1f", ligand.position.z)))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    // Molecular Properties
                    HStack(spacing: 8) {
                        PropertyTag(text: "MW: \(ligand.molecularWeight)kDa", color: Color.green)
                        PropertyTag(text: "Charge: \(ligand.charge)", color: Color.orange)
                    }
                }
                
                Spacer()
                
                // Focus Button
                VStack(spacing: 4) {
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundColor(Color.purple)
                    
                    Text("Focus")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color.purple)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Property Tag View
struct PropertyTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Ligand Analysis Summary View
struct LigandAnalysisSummary: View {
    let ligands: [LigandModel]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ligand Analysis Summary")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total MW", 
                    value: "\(String(format: "%.1f", ligands.reduce(0.0) { $0 + $1.molecularWeight }))kDa", 
                    color: Color.blue
                )
                StatCard(
                    title: "Avg Charge", 
                    value: String(format: "%.1f", ligands.isEmpty ? 0.0 : ligands.reduce(0.0) { $0 + $1.charge } / Double(ligands.count)), 
                    color: Color.green
                )
                StatCard(
                    title: "Types", 
                    value: "\(Set(ligands.map { $0.type }).count)", 
                    color: Color.orange
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Card View
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pocket Model
struct PocketModel: Identifiable {
    let id = UUID()
    let name: String
    let score: Double // 0.0 to 1.0
    let volume: Int // in Ų
    let description: String
    let druggability: String // "High", "Medium", "Low"
}

// MARK: - Pocket Card View
struct PocketCard: View {
    let pocket: PocketModel
    let onView: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pocket Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pocket.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(pocket.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Score Gauge
                ZStack {
                    Circle()
                        .stroke(.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: pocket.score)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(pocket.score * 100))")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary)
                }
            }
            
            // Pocket Details
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(pocket.volume) Ų")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.2f", pocket.score))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(pocket.score > 0.7 ? .green : pocket.score > 0.5 ? .orange : .red)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Druggability")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(pocket.druggability)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DruggabilityHelper.color(for: pocket.druggability))
                }
                
                Spacer()
                
                // View Button
                Button(action: onView) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                        Text("View")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.orange, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pocket Analysis Summary View
struct PocketAnalysisSummary: View {
    let pockets: [PocketModel]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pocket Analysis Summary")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Volume", 
                    value: "\(pockets.reduce(0) { $0 + $1.volume }) Ų", 
                    color: Color.blue
                )
                StatCard(
                    title: "Avg Score", 
                    value: String(format: "%.2f", pockets.isEmpty ? 0.0 : pockets.reduce(0.0) { $0 + $1.score } / Double(pockets.count)), 
                    color: Color.green
                )
                StatCard(
                    title: "Best Score", 
                    value: String(format: "%.2f", pockets.max(by: { $0.score < $1.score })?.score ?? 0.0), 
                    color: Color.orange
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Druggability Helper
struct DruggabilityHelper {
    static func color(for druggability: String) -> Color {
        switch druggability.lowercased() {
        case "high": return .green
        case "medium": return .orange
        case "low": return .red
        default: return .gray
        }
    }
}

// MARK: - Annotation Data Model
struct AnnotationData {
    let function: String
    let gene: String
    let organism: String
    let goTerms: [String]
    let pathways: [String]
}

// MARK: - Networking
private enum NetError: Error { case badURL, badStatus(Int), badData }

private struct Net {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static func getText(_ url: URL) async throws -> String {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse else { throw NetError.badData }
        guard (200..<300).contains(http.statusCode) else { throw NetError.badStatus(http.statusCode) }
        guard let text = String(data: data, encoding: .utf8) else { throw NetError.badData }
        return text
    }

    static func getJSON<T: Decodable>(_ url: URL, as: T.Type) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse else { throw NetError.badData }
        guard (200..<300).contains(http.statusCode) else { throw NetError.badStatus(http.statusCode) }
        return try decoder.decode(T.self, from: data)
    }
}
// MARK: - External DTOs
private struct PDBeLigandRoot: Decodable { let ligandMonomers: [PDBeLigand]? }
private struct PDBeLigand: Decodable {
    let chemCompId: String?
    let moleculeName: [String]?
    let formulaWeight: Double?
    let charge: Int?
}

private struct PDBeUniProtMapRoot: Decodable { let uniprotIds: [String]? }

private struct UniProtDTO: Decodable {
    struct ProteinDescription: Decodable {
        struct RecName: Decodable { struct NameText: Decodable { let value: String? }; let fullName: NameText? }
        let recommendedName: RecName?
    }
    struct Organism: Decodable { let scientificName: String? }
    struct DBRef: Decodable { let type: String?; let id: String? }

    let primaryAccession: String?
    let proteinDescription: ProteinDescription?
    let organism: Organism?
    let genes: [Gene]?
    let comments: [Comment]?
    let uniProtKBCrossReferences: [DBRef]?

    struct Gene: Decodable { struct GeneName: Decodable { let value: String? }; let geneName: GeneName? }
    struct Comment: Decodable { let commentType: String?; let texts: [Text]?; struct Text: Decodable { let value: String? } }
}

// MARK: - Live Data Loader
extension EnhancedProteinViewerView {

    /// RCSB에서 PDB 파일(.pdb) 내려받아 파싱
    private func loadStructureFromRCSB(pdbId: String) async throws -> PDBStructure {
        let id = pdbId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://files.rcsb.org/download/\(id).pdb") else { throw NetError.badURL }
        let pdbText = try await Net.getText(url)
        return PDBParser.parse(pdbText: pdbText) // 프로젝트에 있는 파서 사용
    }

    /// PDBe: 리간드 메타 (이름/분자량/전하)
    private func fetchLigandsMetaFromPDBe(pdbId: String) async throws -> [LigandModel] {
        let id = pdbId.lowercased()
        guard let url = URL(string: "https://www.ebi.ac.uk/pdbe/api/pdb/entry/ligand_monomers/\(id)") else { throw NetError.badURL }
        
        // First get raw data to check if it's empty
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse else { throw NetError.badData }
        guard (200..<300).contains(http.statusCode) else { throw NetError.badStatus(http.statusCode) }
        
        // Check if data is empty or contains empty array
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entry = json[id] as? [String: Any],
              let ligandsArray = entry["ligandMonomers"] as? [Any] else {
            // Return empty array if parsing fails
            return []
        }
        
        // If we have an empty array, return empty ligands
        if ligandsArray.isEmpty {
            return []
        }
        
        // Otherwise decode normally
        let dict = try Net.decoder.decode([String: PDBeLigandRoot].self, from: data)
        let rows = dict[id]?.ligandMonomers ?? []

        return rows.map { r in
            LigandModel(
                name: r.chemCompId ?? "LIG",
                description: r.moleculeName?.first ?? "Small molecule",
                position: .zero,                               // 좌표는 아래 merge에서 보정
                molecularWeight: (r.formulaWeight ?? 0) / 1000,// g/mol → kDa
                charge: Double(r.charge ?? 0),
                type: "Ligand"
            )
        }
    }

    /// PDBe: PDB → UniProt 매핑
    private func mapPDBtoUniProt(_ pdbId: String) async throws -> String? {
        let id = pdbId.lowercased()
        guard let url = URL(string: "https://www.ebi.ac.uk/pdbe/api/mappings/uniprot/\(id)") else { return nil }
        let data = try await Net.getJSON(url, as: [String: [String: PDBeUniProtMapRoot]].self)
        return data[id]?["UniProt"]?.uniprotIds?.first
    }

    /// UniProt: 기능/생물종/GO 주석
    private func fetchAnnotations(uniprot: String) async throws -> AnnotationData {
        guard let url = URL(string: "https://rest.uniprot.org/uniprotkb/\(uniprot).json") else { throw NetError.badURL }
        let dto = try await Net.getJSON(url, as: UniProtDTO.self)

        let functionText =
            dto.comments?.first(where: { $0.commentType == "FUNCTION" })?.texts?.first?.value
            ?? dto.proteinDescription?.recommendedName?.fullName?.value
            ?? "Function not available"

        let gene = dto.genes?.first?.geneName?.value ?? (dto.primaryAccession ?? "Unknown")
        let organism = dto.organism?.scientificName ?? "Unknown organism"

        let goTerms = (dto.uniProtKBCrossReferences ?? [])
            .filter { $0.type == "GO" }
            .compactMap { $0.id }

        return AnnotationData(function: functionText, gene: gene, organism: organism, goTerms: goTerms, pathways: [])
    }

    /// 파싱된 구조에서 리간드 그룹을 찾아 PDBe 메타와 좌표 병합
    private func mergeLigands(meta: [LigandModel], with structure: PDBStructure) -> [LigandModel] {
        let het = structure.atoms.filter { $0.isLigandCandidate } // HETATM 후보
        let groups = Dictionary(grouping: het) { "\($0.residueName)_\($0.chain)_\($0.residueNumber)" }

        return meta.map { m in
            if let (_, atoms) = groups.first(where: { $0.key.hasPrefix(m.name + "_") }),
               let p = atoms.centerOfMass {
                return LigandModel(name: m.name, description: m.description, position: p,
                                   molecularWeight: m.molecularWeight, charge: m.charge, type: m.type)
            } else {
                return m
            }
        }
    }
}

// MARK: - Helpers
private extension SIMD3 where Scalar == Float {
    static var zero: SIMD3<Float> { SIMD3<Float>(0,0,0) }
}
private extension Array where Element == Atom {
    var centerOfMass: SIMD3<Float>? {
        guard !isEmpty else { return nil }
        let sx = reduce(0) { $0 + $1.position.x }
        let sy = reduce(0) { $0 + $1.position.y }
        let sz = reduce(0) { $0 + $1.position.z }
        let n = Float(count)
        return SIMD3<Float>(sx/n, sy/n, sz/n)
    }
}
private extension Atom {
    var isLigandCandidate: Bool {
        let lig = ["ATP","ADP","GTP","GDP","NAD","FAD","FMN","COA","HEM","MG","CA","ZN","FE","MN"]
        return lig.contains(residueName) && residueName != "HOH"
    }
}


