import SwiftUI
import SceneKit
import UIKit
import simd

// MARK: - Haptic Feedback
func provideHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    let impactFeedback = UIImpactFeedbackGenerator(style: style)
    impactFeedback.impactOccurred()
}


// MARK: - Advanced Geometry Cache for Performance Optimization
final class GeometryCache {
    static let shared = GeometryCache()
    
    // Cache for LOD spheres and cylinders with color-based materials
    private var lodSphereCache = [String: SCNGeometry]()
    private var lodCylinderCache = [String: SCNGeometry]()
    private var materialByColor = [UInt32: SCNMaterial]()
    
    private func colorKey(_ c: UIColor) -> UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Convert 8bit RGBA to 32bit key
        return (UInt32(r*255)<<24) | (UInt32(g*255)<<16) | (UInt32(b*255)<<8) | UInt32(a*255)
    }
    
    func material(color: UIColor) -> SCNMaterial {
        let k = colorKey(color)
        if let m = materialByColor[k] { return m }
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = color
        m.specular.contents = UIColor.white
        materialByColor[k] = m
        return m
    }
    
    func lodSphere(radius r: CGFloat, color: UIColor) -> SCNGeometry {
        let key = "S:\(r)-\(colorKey(color))"
        if let g = lodSphereCache[key] { return g }
        
        let hi = SCNSphere(radius: r); hi.segmentCount = 32
        let md = SCNSphere(radius: r); md.segmentCount = 16
        let lo = SCNSphere(radius: r); lo.segmentCount = 8
        
        let mat = material(color: color)
        [hi, md, lo].forEach { $0.firstMaterial = mat }
        
        let g = SCNSphere(radius: r)
        g.levelsOfDetail = [
            SCNLevelOfDetail(geometry: hi, screenSpaceRadius: 40.0),
            SCNLevelOfDetail(geometry: md, screenSpaceRadius: 20.0),
            SCNLevelOfDetail(geometry: lo, screenSpaceRadius: 8.0),
        ]
        g.firstMaterial = mat
        lodSphereCache[key] = g
        return g
    }
    
    // Cylinders have different heights for each bond, making reuse difficult.
    // Cache "unit cylinder (height=1)" and scale each bond with scale.y = distance.
    func unitLodCylinder(radius r: CGFloat, color: UIColor) -> SCNGeometry {
        let key = "C:\(r)-\(colorKey(color))"
        if let g = lodCylinderCache[key] { return g }
        
        let hi = SCNCylinder(radius: r, height: 1); hi.radialSegmentCount = 16
        let md = SCNCylinder(radius: r, height: 1); md.radialSegmentCount = 8
        let lo = SCNCylinder(radius: r, height: 1); lo.radialSegmentCount = 6
        
        let mat = material(color: color)
        [hi, md, lo].forEach { $0.firstMaterial = mat }
        
        let g = SCNCylinder(radius: r, height: 1)
        g.levelsOfDetail = [
            SCNLevelOfDetail(geometry: hi, screenSpaceRadius: 30.0),
            SCNLevelOfDetail(geometry: md, screenSpaceRadius: 15.0),
            SCNLevelOfDetail(geometry: lo, screenSpaceRadius: 6.0),
        ]
        g.firstMaterial = mat
        lodCylinderCache[key] = g
        return g
    }
    
    func clearCache() {
        lodSphereCache.removeAll()
        lodCylinderCache.removeAll()
        materialByColor.removeAll()
    }
}

enum RenderStyle: String, CaseIterable { 
    case spheres = "Spheres"
    case sticks = "Sticks" 
    case cartoon = "Cartoon"
    case surface = "Surface"
    
    var icon: String {
        switch self {
        case .spheres: return "circle.fill"
        case .sticks: return "line.3.horizontal"
        case .cartoon: return "waveform.path"
        case .surface: return "globe"
        }
    }
}

enum ColorMode: String, CaseIterable { 
    case element = "Element"
    case chain = "Chain" 
    case uniform = "Uniform"
    case secondaryStructure = "Secondary Structure"
    
    var icon: String {
        switch self {
        case .element: return "atom"
        case .chain: return "link"
        case .uniform: return "paintbrush"
        case .secondaryStructure: return "waveform.path"
        }
    }
}

enum InfoTabType: String, CaseIterable {
    case overview = "Overview"
    case chains = "Chains"
    case residues = "Residues"
    case ligands = "Ligands"
    case pockets = "Pockets"
    case sequence = "Sequence"
    case annotations = "Annotations"
}

enum ViewMode {
    case viewer
    case info
}

enum BottomPanel {
    case none
    case rendering
    case color
}

enum SecondaryBarType {
    case none
    case renderingStyles
    case colorSchemes
    case options
}

// MARK: - Viewer Mode UI Components
struct ViewerModeUI: View {
    let structure: PDBStructure?
    let proteinId: String?
    let proteinName: String?
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @Binding var highlightedChains: Set<String>
    @Binding var focusedElement: FocusedElement?
    @Binding var viewMode: ViewMode
    @Binding var isRendering3D: Bool
    @Binding var renderingProgress: String
    @Binding var highlightAllChains: Bool
    
    @State private var activePanel: BottomPanel = .none
    @State private var showSecondaryBar: Bool = false
    @State private var secondaryBarType: SecondaryBarType = .none
    @State private var rotationEnabled: Bool = false
    @State private var zoomLevel: Double = 1.0
    @State private var transparency: Double = 1.0
    @State private var atomSize: Double = 1.0
    
    var body: some View {
        ZStack {
            // 3D Viewer (기존 ProteinSceneView)
                ProteinSceneView(
                    structure: structure,
                    style: selectedStyle,
                    colorMode: selectedColorMode,
                    uniformColor: .systemBlue,
                        autoRotate: rotationEnabled,
                    isInfoMode: false,
                        showInfoBar: .constant(false),
                        highlightedChains: highlightedChains,
                        highlightedLigands: [],
                        highlightedPockets: [],
                        focusedElement: focusedElement,
                        onFocusRequest: { element in
                            focusedElement = element
                        },
                        isRendering3D: $isRendering3D,
                        renderingProgress: $renderingProgress,
                        zoomLevel: zoomLevel,
                        transparency: transparency,
                        atomSize: atomSize
                )
                .ignoresSafeArea()
                
                                // Viewer Mode UI Overlay
                    VStack(spacing: 0) {
                        // Top Bar
                        ViewerTopBar(
                            viewMode: $viewMode,
                            proteinName: proteinName,
                            proteinId: proteinId
                        )
                        
                        Spacer()
                        
                        // Bottom Secondary Bar (동적, Primary 위에)
                        if showSecondaryBar {
                            SecondaryOptionsBar(
                                type: secondaryBarType,
                                selectedStyle: $selectedStyle,
                                selectedColorMode: $selectedColorMode,
                                showSecondaryBar: $showSecondaryBar,
                                rotationEnabled: $rotationEnabled,
                                zoomLevel: $zoomLevel,
                                transparency: $transparency,
                                atomSize: $atomSize,
                                highlightAllChains: $highlightAllChains,
                                highlightedChains: $highlightedChains,
                                structure: structure
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                
                        // Bottom Primary Bar (맨 아래 고정)
                        PrimaryOptionsBar(
                            activePanel: $activePanel,
                            selectedStyle: $selectedStyle,
                            selectedColorMode: $selectedColorMode,
                            highlightedChains: $highlightedChains,
                            focusedElement: $focusedElement,
                            highlightAllChains: $highlightAllChains,
                            structure: structure,
                            showSecondaryBar: $showSecondaryBar,
                            secondaryBarType: $secondaryBarType
                        )
                    }
            
            // Bottom Sheet Panels
            if activePanel != .none {
                ViewerBottomSheet(
                    activePanel: activePanel,
                    selectedStyle: $selectedStyle,
                    selectedColorMode: $selectedColorMode,
                    activePanelBinding: $activePanel
                )
            }
            
            // Background tap to close secondary bar
            if showSecondaryBar {
                Color.clear
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            showSecondaryBar = false
                            secondaryBarType = .none
                        }
                    }
            }
        }
    }
}

// MARK: - Viewer Top Bar
struct ViewerTopBar: View {
    @Binding var viewMode: ViewMode
    let proteinName: String?
    let proteinId: String?
    
    var body: some View {
        HStack {
            // Back to Info Mode
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewMode = .info
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .accessibilityLabel("Back to Info")
            
            Spacer()
            
            // Protein Title
            VStack(spacing: 2) {
                if let id = proteinId {
                    Text(id)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                if let name = proteinName {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            // Empty space for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Secondary Options Bar
struct SecondaryOptionsBar: View {
    let type: SecondaryBarType
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @Binding var showSecondaryBar: Bool
    @Binding var rotationEnabled: Bool
    @Binding var zoomLevel: Double
    @Binding var transparency: Double
    @Binding var atomSize: Double
    @Binding var highlightAllChains: Bool
    @Binding var highlightedChains: Set<String>
    let structure: PDBStructure?
    
    private func toggleHighlightAllChains() {
        highlightAllChains.toggle()
        
        if highlightAllChains {
            // Highlight all chains
            if let structure = structure {
                let allChains = Set(structure.atoms.map { $0.chain })
                highlightedChains = allChains
            }
        } else {
            // Clear all highlights
            highlightedChains.removeAll()
        }
        
        // Haptic feedback
        provideHapticFeedback(style: .light)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top separator
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator))
                .frame(maxWidth: .infinity)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    switch type {
                    case .renderingStyles:
                        ForEach(RenderStyle.allCases, id: \.self) { style in
                            Button(action: {
                                selectedStyle = style
                                // Secondary bar 유지
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: style.icon)
                                        .font(.system(size: 20, weight: .medium))
                                    Text(style.rawValue)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .foregroundColor(selectedStyle == style ? .blue : .primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(selectedStyle == style ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Highlight All Chains 버튼 추가
                        Button(action: { toggleHighlightAllChains() }) {
                            VStack(spacing: 6) {
                                Image(systemName: highlightAllChains ? "lightbulb.circle.fill" : "lightbulb.circle")
                                    .font(.system(size: 20, weight: .medium))
                                Text("Highlight All")
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .foregroundColor(highlightAllChains ? .yellow : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(highlightAllChains ? Color.yellow.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity)
                        }
                    case .colorSchemes:
                        ForEach(ColorMode.allCases, id: \.self) { mode in
                            Button(action: {
                                selectedColorMode = mode
                                // Secondary bar 유지
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 20, weight: .medium))
                                    Text(mode.rawValue)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .foregroundColor(selectedColorMode == mode ? .green : .primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .background(selectedColorMode == mode ? Color.green.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    case .options:
                        OptionsSecondaryBar(
                            rotationEnabled: $rotationEnabled,
                            zoomLevel: $zoomLevel,
                            transparency: $transparency,
                            atomSize: $atomSize
                        )
                    case .none:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

// MARK: - Options Secondary Bar
struct OptionsSecondaryBar: View {
    @Binding var rotationEnabled: Bool
    @Binding var zoomLevel: Double
    @Binding var transparency: Double
    @Binding var atomSize: Double
    
    var body: some View {
        HStack(spacing: 0) {
            // Rotation Toggle
            Button(action: {
                rotationEnabled.toggle()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: rotationEnabled ? "rotate.3d.fill" : "rotate.3d")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(rotationEnabled ? .orange : .primary)
                    Text("Rotate")
                        .font(.caption2)
                        .foregroundColor(rotationEnabled ? .orange : .secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(rotationEnabled ? Color.orange.opacity(0.1) : Color.clear)
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
            
            // Zoom Level
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.caption)
                    Spacer()
                    Text("Zoom")
                        .font(.caption2)
                                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption)
                }
                Slider(value: $zoomLevel, in: 0.5...3.0, step: 0.1)
                    .frame(width: 60)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .frame(maxWidth: .infinity)
            
            // Transparency
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "eye.slash")
                        .font(.caption)
                            Spacer()
                    Text("Opacity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "eye")
                        .font(.caption)
                }
                Slider(value: $transparency, in: 0.1...1.0, step: 0.1)
                    .frame(width: 60)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
            .frame(maxWidth: .infinity)
            
            // Atom Size
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "circle")
                        .font(.caption)
                    Spacer()
                    Text("Size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "circle.fill")
                        .font(.caption)
                }
                Slider(value: $atomSize, in: 0.5...2.0, step: 0.1)
                    .frame(width: 60)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            .frame(maxWidth: .infinity)
            
            // Reset Button
                            Button(action: {
                resetToDefaults()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.red)
                    Text("Reset")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 60)
    }
    
    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.3)) {
            rotationEnabled = false
            zoomLevel = 1.0
            transparency = 1.0
            atomSize = 1.0
        }
        
        // Haptic feedback
        provideHapticFeedback(style: .medium)
    }
}

// MARK: - Primary Options Bar
struct PrimaryOptionsBar: View {
    @Binding var activePanel: BottomPanel
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @Binding var highlightedChains: Set<String>
    @Binding var focusedElement: FocusedElement?
    @Binding var highlightAllChains: Bool
    let structure: PDBStructure?
    @Binding var showSecondaryBar: Bool
    @Binding var secondaryBarType: SecondaryBarType
    
    var body: some View {
        HStack(spacing: 0) {
            // Rendering Style
            Button(action: { toggleRenderingStyle() }) {
                VStack(spacing: 4) {
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(showSecondaryBar && secondaryBarType == .renderingStyles ? .blue : .primary)
                    Text("Style")
                        .font(.caption2)
                        .foregroundColor(showSecondaryBar && secondaryBarType == .renderingStyles ? .blue : .secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .accessibilityLabel("Rendering Style")
            
            // Options Menu
            Button(action: { toggleOptionsMenu() }) {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(showSecondaryBar && secondaryBarType == .options ? .orange : .primary)
                    Text("Options")
                        .font(.caption2)
                        .foregroundColor(showSecondaryBar && secondaryBarType == .options ? .orange : .secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .accessibilityLabel("Options Menu")
            
            // Color Scheme
            Button(action: { toggleColorScheme() }) {
                VStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(showSecondaryBar && secondaryBarType == .colorSchemes ? .green : .primary)
                    Text("Colors")
                        .font(.caption2)
                        .foregroundColor(showSecondaryBar && secondaryBarType == .colorSchemes ? .green : .secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .accessibilityLabel("Color Scheme")
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator))
                .frame(maxWidth: .infinity),
            alignment: .top
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    // MARK: - Action Functions
    private func toggleRenderingStyle() {
        withAnimation(.easeInOut(duration: 0.28)) {
            if showSecondaryBar && secondaryBarType == .renderingStyles {
                // 이미 열려있으면 닫기
                showSecondaryBar = false
                secondaryBarType = .none
            } else {
                // 렌더링 스타일 Secondary bar 열기
                showSecondaryBar = true
                secondaryBarType = .renderingStyles
            }
        }
        
        // Haptic feedback
        provideHapticFeedback(style: .light)
    }
    
    private func toggleOptionsMenu() {
        withAnimation(.easeInOut(duration: 0.28)) {
            if showSecondaryBar && secondaryBarType == .options {
                // 이미 열려있으면 닫기
                showSecondaryBar = false
                secondaryBarType = .none
            } else {
                // Options Secondary bar 열기
                showSecondaryBar = true
                secondaryBarType = .options
            }
        }
        
        // Haptic feedback
        provideHapticFeedback(style: .light)
    }
    
    private func toggleColorScheme() {
        withAnimation(.easeInOut(duration: 0.28)) {
            if showSecondaryBar && secondaryBarType == .colorSchemes {
                // 이미 열려있으면 닫기
                showSecondaryBar = false
                secondaryBarType = .none
            } else {
                // 색상 스킴 Secondary bar 열기
                showSecondaryBar = true
                secondaryBarType = .colorSchemes
            }
        }
        
        // Haptic feedback
        provideHapticFeedback(style: .light)
    }
}

// MARK: - Viewer Bottom Controls (기존, 호환성을 위해 유지)
struct ViewerBottomControls: View {
    @Binding var activePanel: BottomPanel
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @Binding var highlightedChains: Set<String>
    @Binding var focusedElement: FocusedElement?
    @Binding var highlightAllChains: Bool
    let structure: PDBStructure?
    
    var body: some View {
        VStack(spacing: 16) {
            // Row 1: Quick Options
            HStack(spacing: 16) {
                // Rendering Style
                Button(action: { togglePanel(.rendering) }) {
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.title2)
                        .foregroundColor(activePanel == .rendering ? .blue : .primary)
                }
                .accessibilityLabel("Rendering Style")
                
                // Chain Highlight Toggle
                Button(action: { toggleHighlightAllChains() }) {
                    Image(systemName: highlightAllChains ? "lightbulb.circle.fill" : "lightbulb.circle")
                        .font(.title2)
                        .foregroundColor(highlightAllChains ? .yellow : .primary)
                }
                .accessibilityLabel("Highlight All Chains")
                
                // Focus
                Button(action: { focusOnCurrentSelection() }) {
                    Image(systemName: "scope")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                }
                .accessibilityLabel("Focus")
                
                // Color Scheme
                Button(action: { togglePanel(.color) }) {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundColor(activePanel == .color ? .blue : .primary)
                }
                .accessibilityLabel("Color Scheme")
            }
            
            // Row 2: Primary Actions
            HStack(spacing: 16) {
                // Apply
                Button(action: { applyViewerSettings() }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .accessibilityLabel("Apply Settings")
                
                // Reset
                Button(action: { resetViewerToDefaults() }) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .accessibilityLabel("Reset")
                
                // More
                Button(action: { showViewerMoreOptions() }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("More Options")
                            }
                        }
                        .padding(.horizontal, 16)
        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Action Functions
    private func togglePanel(_ panel: BottomPanel) {
        withAnimation(.easeInOut(duration: 0.28)) {
            if activePanel == panel {
                activePanel = .none
            } else {
                activePanel = panel
            }
        }
        
        // Haptic feedback
        provideHapticFeedback(style: .light)
    }
    
    private func toggleHighlightAllChains() {
        highlightAllChains.toggle()
        
        if highlightAllChains {
            // Highlight all chains
            if let structure = structure {
                let allChains = Set(structure.atoms.map { $0.chain })
                highlightedChains = allChains
            }
        } else {
            // Clear all highlights
            highlightedChains.removeAll()
        }
        
        // Haptic feedback
        provideHapticFeedback(style: .light)
    }
    
    private func focusOnCurrentSelection() {
        // Focus on whole protein
        focusedElement = nil
        
        // Haptic feedback
        provideHapticFeedback(style: .light)
    }
    
    private func applyViewerSettings() {
        // Settings are already applied in real-time
        // This is mainly for haptic feedback
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func resetViewerToDefaults() {
        // Reset to defaults
        selectedStyle = .spheres
        selectedColorMode = .element
        highlightedChains.removeAll()
        focusedElement = nil
        activePanel = .none
        highlightAllChains = false
        
        // Haptic feedback
        provideHapticFeedback(style: .medium)
    }
    
    private func showViewerMoreOptions() {
        // TODO: Implement more options action sheet
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Viewer Bottom Sheet
struct ViewerBottomSheet: View {
    let activePanel: BottomPanel
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @Binding var activePanelBinding: BottomPanel
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                switch activePanel {
                case .rendering:
                    RenderingStylePanel(selectedStyle: $selectedStyle, activePanel: $activePanelBinding)
                case .color:
                    ColorSchemePanel(selectedColorMode: $selectedColorMode, activePanel: $activePanelBinding)
                case .none:
                    EmptyView()
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onTapGesture {
            // Prevent tap from propagating
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        activePanelBinding = .none
                    }
                }
        )
    }
}

// MARK: - Rendering Style Panel
struct RenderingStylePanel: View {
    @Binding var selectedStyle: RenderStyle
    @Binding var activePanel: BottomPanel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Rendering Style")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(RenderStyle.allCases, id: \.self) { style in
                    Button(action: {
                        selectedStyle = style
                        withAnimation(.easeInOut(duration: 0.28)) {
                            activePanel = .none
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: style.icon)
                                .font(.title2)
                            Text(style.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(selectedStyle == style ? .blue : .primary)
                        .padding()
                        .background(selectedStyle == style ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - Color Scheme Panel
struct ColorSchemePanel: View {
    @Binding var selectedColorMode: ColorMode
    @Binding var activePanel: BottomPanel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Color Scheme")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(ColorMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedColorMode = mode
                        withAnimation(.easeInOut(duration: 0.28)) {
                            activePanel = .none
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                            Text(mode.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(selectedColorMode == mode ? .green : .primary)
                        .padding()
                        .background(selectedColorMode == mode ? Color.green.opacity(0.1) : Color.clear)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

enum FocusedElement: Equatable {
    case chain(String)
    case ligand(String)
    case pocket(String)
    case atom(Int)
    
    var displayName: String {
        switch self {
        case .chain(let chainId):
            return "Chain \(chainId)"
        case .ligand(let ligandName):
            return "Ligand \(ligandName)"
        case .pocket(let pocketName):
            return "Pocket \(pocketName)"
        case .atom(let atomId):
            return "Atom \(atomId)"
        }
    }
}

struct ProteinSceneContainer: View {
    let structure: PDBStructure?
    let proteinId: String?
    let proteinName: String?
    let onProteinLibraryTap: (() -> Void)?
    
    // External loading state (optional)
    @Binding var externalIsProteinLoading: Bool
    @Binding var externalProteinLoadingProgress: String
    @Binding var externalIs3DStructureLoading: Bool
    @Binding var externalStructureLoadingProgress: String
    
    // Size class for iPad detection
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(structure: PDBStructure?, proteinId: String?, proteinName: String?, onProteinLibraryTap: (() -> Void)? = nil, externalIsProteinLoading: Binding<Bool> = .constant(false), externalProteinLoadingProgress: Binding<String> = .constant(""), externalIs3DStructureLoading: Binding<Bool> = .constant(false), externalStructureLoadingProgress: Binding<String> = .constant("")) {
        self.structure = structure
        self.proteinId = proteinId
        self.proteinName = proteinName
        self.onProteinLibraryTap = onProteinLibraryTap
        self._externalIsProteinLoading = externalIsProteinLoading
        self._externalProteinLoadingProgress = externalProteinLoadingProgress
        self._externalIs3DStructureLoading = externalIs3DStructureLoading
        self._externalStructureLoadingProgress = externalStructureLoadingProgress
    }
    
    @State private var selectedStyle: RenderStyle = .spheres
    @State private var selectedColorMode: ColorMode = .element
    @State private var selectedTab: InfoTabType = .overview
    @State private var viewMode: ViewMode = .info
    @State private var showAdvancedControls = false
    @State private var showInfoBar = true
    
    // Auto-switch to overview tab when 3D structure is loading
    @State private var shouldSwitchToOverview = false
    
    // Tab loading state
    @State private var isTabLoading: Bool = false
    @State private var tabLoadingProgress: String = ""
    
    // Chain highlight state management
    @State private var highlightedChains: Set<String> = []
    @State private var highlightedLigands: Set<String> = []
    @State private var highlightedPockets: Set<String> = []
    
    // Focus state management (enabled for testing)
    @State private var enableFocusFeature: Bool = true
    @State private var focusedElement: FocusedElement? = nil
    @State private var isFocused: Bool = false
    
    // 3D Rendering loading state
    @State private var isRendering3D: Bool = false
    @State private var renderingProgress: String = ""
    
    // Side menu state
    @State private var showingSideMenu: Bool = false
    @State private var showingDetailView = false
    @State private var selectedMenuItem: MenuItemType? = nil
    
    // Protein loading state
    @State private var isProteinLoading: Bool = false
    @State private var proteinLoadingProgress: String = ""
    
    // Viewer Mode UI state
    @State private var activePanel: BottomPanel = .none
    @State private var highlightAllChains: Bool = false
    
    var body: some View {
        ZStack {
            if viewMode == .viewer {
                ViewerModeUI(
                    structure: structure,
                    proteinId: proteinId,
                    proteinName: proteinName,
                    selectedStyle: $selectedStyle,
                    selectedColorMode: $selectedColorMode,
                    highlightedChains: $highlightedChains,
                    focusedElement: $focusedElement,
                    viewMode: $viewMode,
                    isRendering3D: $isRendering3D,
                    renderingProgress: $renderingProgress,
                    highlightAllChains: $highlightAllChains
                )
                } else {
                    // Info mode with NavigationView + .toolbar(.bottomBar)
                    NavigationView {
                        VStack(spacing: 0) {
                            // Fixed header with navigation and tabs
                            VStack(spacing: 0) {
                                // Info mode header
                                HStack {
                                    // iPad에서는 햄버거 메뉴 숨김 (외부 사이드바 사용)
                                    if horizontalSizeClass != .regular {
                                        Button(action: {
                                            // 사이드 메뉴 표시 (애니메이션과 함께)
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showingSideMenu = true
                                            }
                                        }) {
                                            Image(systemName: "line.3.horizontal")
                                                .font(.title2)
                                                .foregroundColor(.primary)
                                        }
                                        .frame(minWidth: 44, minHeight: 44) // 터치 영역 확보
                                    } else {
                                        // iPad에서는 빈 공간으로 대체
                                        Color.clear
                                            .frame(width: 44, height: 44)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 4) {
                                        if let id = proteinId {
                                            Text(id)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                        }
                                        if let name = proteinName {
                                            Text(name)
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                                .lineLimit(name.count > 40 ? 1 : 2)
                                                .truncationMode(.tail)
                                                .minimumScaleFactor(0.85)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if let onProteinLibraryTap = onProteinLibraryTap {
                                        Button(action: onProteinLibraryTap) {
                                            Image(systemName: "books.vertical")
                                                .font(.title2)
                                                .foregroundColor(.primary)
                                        }
                                        .frame(minWidth: 44, minHeight: 44)
                                    }
                                    
                                    Button(action: {
                                        viewMode = .viewer
                                    }) {
                                        Image(systemName: "eye")
                                            .font(.title2)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(minWidth: 44, minHeight: 44)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8) // PrimaryOptionsBar 방식 적용
                                .padding(.bottom, 12)
                                .background(.ultraThinMaterial)
                        
                            // Focus status indicator and clear button (moved to header)
                            HStack {
                                // Focus status indicator
                                if let focusElement = focusedElement {
                                    HStack(spacing: 6) {
                                        Image(systemName: "scope.fill")
                                            .font(.callout)
                                            .foregroundColor(.green)
                                        Text("Focused: \(focusElement.displayName)")
                                            .font(.footnote)
                                            .fontWeight(.medium)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(16)
                                }
                                
                                Spacer()
                                
                                // Clear highlights and focus button
                                if !highlightedChains.isEmpty || !highlightedLigands.isEmpty || !highlightedPockets.isEmpty || isFocused {
                                    Button(action: {
                                        highlightedChains.removeAll()
                                        highlightedLigands.removeAll()
                                        highlightedPockets.removeAll()
                                        focusedElement = nil
                                        isFocused = false
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.callout)
                                            Text("Clear")
                                                .font(.footnote)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.red)
                                        .cornerRadius(16)
                                    }
                                    .frame(minHeight: 44)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .background(.ultraThinMaterial)
                            .overlay(Divider(), alignment: .bottom)
                        }
                            
                            // 3D Structure Preview
                            VStack(alignment: .leading, spacing: 12) {
                                Text("3D Structure Preview")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 16)
                        
                                if let structure = structure {
                                    ProteinSceneView(
                                        structure: structure,
                                        style: selectedStyle,
                                        colorMode: selectedColorMode,
                                        uniformColor: .systemBlue,
                                        autoRotate: false,
                                        isInfoMode: true,
                                        showInfoBar: .constant(false),
                                        highlightedChains: highlightedChains,
                                        highlightedLigands: highlightedLigands,
                                        highlightedPockets: highlightedPockets,
                                        focusedElement: focusedElement,
                                        onFocusRequest: { element in
                                            focusedElement = element
                                            isFocused = true
                                        }
                                    )
                                    .frame(height: 220)
                                    .padding(.horizontal, 16)
                                    .background(Color(.systemGray6).opacity(0.3))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                            .background(Color(.systemBackground))
                    
                            // Scrollable tab content area below fixed elements
                            ScrollView {
                                VStack(spacing: 20) {
                                    Spacer(minLength: 0) // 탭바를 제외한 공간 최대 활용
                                    
                                    if let structure = structure {
                                        if isTabLoading {
                                            // Tab loading indicator
                                            VStack(spacing: 20) {
                                                ProgressView()
                                                    .scaleEffect(1.3)
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                
                                                Text(tabLoadingProgress)
                                                    .font(.title3)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 220)
                                            .background(Color(.systemGray6))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                        } else {
                                            // Tab content
                                            switch selectedTab {
                                            case .overview:
                                                overviewContent(structure: structure)
                                            case .chains:
                                                chainsContent(structure: structure)
                                            case .residues:
                                                residuesContent(structure: structure)
                                            case .ligands:
                                                ligandsContent(structure: structure)
                                            case .pockets:
                                                pocketsContent(structure: structure)
                                            case .sequence:
                                                sequenceContent(structure: structure)
                                            case .annotations:
                                                annotationsContent(structure: structure)
                                            }
                                        }
                                    }
                                    
                                    Spacer(minLength: 0) // 하단 공간도 최대 활용
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 6)
                            }
                            .background(Color(.systemBackground))
                        }
                        .background(Color(.systemBackground))
                        .toolbar {
                            ToolbarItemGroup(placement: .bottomBar) {
                                ScrollView(.horizontal, showsIndicators: true) {
                                    HStack(spacing: 0) {
                                        ForEach(InfoTabType.allCases, id: \.self) { tab in
                                            Button(action: {
                                                // 즉시 상태 변경 (highlight 버튼처럼)
                                                selectedTab = tab
                                                
                                                // 햅틱 피드백
                                                provideHapticFeedback(style: .light)
                                                
                                                isTabLoading = true
                                                tabLoadingProgress = "Loading \(tab.rawValue)..."
                                                
                                                // Simulate tab data loading
                                                Task {
                                                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                                    await MainActor.run {
                                                        isTabLoading = false
                                                        tabLoadingProgress = ""
                                                    }
                                                }
                                            }) {
                                                VStack(spacing: 4) {
                                                    Image(systemName: tabIcon(for: tab))
                                                        .font(.system(size: 18, weight: .medium))
                                                        .foregroundColor(selectedTab == tab ? .blue : .gray)
                                                    
                                                    Text(tab.rawValue)
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(selectedTab == tab ? .blue : .gray)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                }
                                                .frame(width: 80)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .navigationViewStyle(.stack)
                    }
                .overlay(
                    // 사이드 메뉴 오버레이
                    Group {
                        if showingSideMenu {
                            ZStack {
                                // 배경 오버레이
                                Color.black.opacity(0.3)
                                    .ignoresSafeArea()
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showingSideMenu = false
                                        }
                                    }
                                
                                // 사이드 메뉴 (전체 화면)
                                SideMenuView(
                                    isPresented: $showingSideMenu,
                                    onItemSelected: { item in
                                        selectedMenuItem = item
                                        showingDetailView = true
                                        showingSideMenu = false
                                    }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemBackground))
                                .transition(.move(edge: .leading))
                            }
                        }
                    }
                )
            }
            
            // 3D Rendering Loading Overlay
            if isRendering3D {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Rendering 3D Structure...")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if !renderingProgress.isEmpty {
                                Text(renderingProgress)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    )
            }
            
            // Protein Loading Overlay
            if isProteinLoading || externalIsProteinLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Loading Protein Data...")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            let progressText = externalIsProteinLoading ? externalProteinLoadingProgress : proteinLoadingProgress
                            if !progressText.isEmpty {
                                Text(progressText)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    )
            }
            
            // 3D Structure Loading Overlay
            if isRendering3D || externalIs3DStructureLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            let progressText = externalIs3DStructureLoading ? externalStructureLoadingProgress : renderingProgress
                            Text(progressText.isEmpty ? "Loading 3D Structure..." : progressText)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    )
            }
        }
        .background(Color(.systemBackground))
        .sheet(
            isPresented: $showingDetailView,
            onDismiss: {
                // Sheet가 닫힐 때 사이드 메뉴 다시 열기
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSideMenu = true
                }
            }
        ) {
            if let item = selectedMenuItem {
                MenuDetailView(item: item)
            }
        }
        .onChange(of: externalIs3DStructureLoading) { isLoading in
            if isLoading {
                // 3D structure 로딩이 시작되면 overview tab으로 자동 전환
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = .overview
                    shouldSwitchToOverview = true
                }
            }
        }
        .onChange(of: shouldSwitchToOverview) { shouldSwitch in
            if shouldSwitch {
                // overview tab으로 전환 완료 후 플래그 리셋
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    shouldSwitchToOverview = false
                }
            }
        }
    }
    
    // MARK: - Tab Icon Helper
    private func tabIcon(for tab: InfoTabType) -> String {
        switch tab {
        case .overview:
            return "info.circle"
        case .chains:
            return "link"
        case .residues:
            return "circle.grid.2x2"
        case .ligands:
            return "pills"
        case .pockets:
            return "hexagon"
        case .sequence:
            return "textformat.abc"
        case .annotations:
            return "note.text"
        }
    }
    
    // MARK: - Protein Loading Functions
    func startProteinLoading(progress: String = "Loading protein data...") {
        isProteinLoading = true
        proteinLoadingProgress = progress
    }
    
    func stopProteinLoading() {
        isProteinLoading = false
        proteinLoadingProgress = ""
    }
    
    // Content functions
    private func overviewContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Basic statistics with enhanced information
            HStack(spacing: 16) {
                StatCard(title: "Atoms", value: "\(structure.atoms.count)", color: .blue)
                StatCard(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", color: .green)
                StatCard(title: "Residues", value: "\(Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count)", color: .orange)
            }
            
            // Structure Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Structure Information")
                    .font(.title3) // .headline에서 .title3로 개선
                    .fontWeight(.semibold) // 가독성 향상
                
                VStack(spacing: 8) {
                    InfoRow(title: "PDB ID", value: proteinId ?? "Unknown", description: "Protein Data Bank identifier - unique code for this structure")
                    InfoRow(title: "Total Atoms", value: "\(structure.atoms.count)", description: "All atoms in the structure including protein and ligands")
                    InfoRow(title: "Total Bonds", value: "\(structure.bonds.count)", description: "Chemical bonds connecting atoms in the structure")
                    InfoRow(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", description: "Number of polypeptide chains in the protein")
                    
                    let uniqueElements = Set(structure.atoms.map { $0.element })
                    InfoRow(title: "Elements", value: "\(uniqueElements.count)", description: "Number of different chemical elements present")
                    
                    let elementTypes = Array(uniqueElements).sorted().joined(separator: ", ")
                    InfoRow(title: "Element Types", value: elementTypes, description: "Chemical elements found in this structure")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1) // 다크 모드에서 경계선 추가
            )
            
            // Chemical Composition
            VStack(alignment: .leading, spacing: 12) {
                Text("Chemical Composition")
                    .font(.title3) // .headline에서 .title3로 개선
                    .fontWeight(.semibold) // 가독성 향상
                
                VStack(spacing: 8) {
                    let uniqueResidues = Set(structure.atoms.map { $0.residueName })
                    InfoRow(title: "Residue Types", value: "\(uniqueResidues.count)", description: "Number of different amino acid types present")
                    
                    let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
                    InfoRow(title: "Total Residues", value: "\(totalResidues)", description: "Total number of amino acid residues across all chains")
                    
                    let chainList = Array(Set(structure.atoms.map { $0.chain })).sorted()
                    InfoRow(title: "Chain IDs", value: chainList.joined(separator: ", "), description: "Identifiers for each polypeptide chain")
                    
                    let hasLigands = structure.atoms.contains { $0.isLigand }
                    InfoRow(title: "Ligands", value: hasLigands ? "Present" : "None", description: hasLigands ? "Small molecules or ions bound to the protein" : "No small molecules detected in this structure")
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1) // 다크 모드에서 경계선 추가
            )
            
            // Experimental Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Experimental Details")
                    .font(.title3) // .headline에서 .title3로 개선
                    .fontWeight(.semibold) // 가독성 향상
                
                VStack(spacing: 8) {
                    InfoRow(title: "Structure Type", value: "Protein", description: "This is a protein structure determined by experimental methods")
                    InfoRow(title: "Data Source", value: "PDB", description: "Protein Data Bank - worldwide repository of 3D structure data")
                    InfoRow(title: "Quality", value: "Experimental", description: "Structure determined through experimental techniques like X-ray crystallography")
                    
                    if let firstAtom = structure.atoms.first {
                        InfoRow(title: "First Residue", value: firstAtom.residueName, description: "Chain \(firstAtom.chain)")
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1) // 다크 모드에서 경계선 추가
            )
        }
    }
    
    private func chainsContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            let chains = Set(structure.atoms.map { $0.chain })
            
            ForEach(Array(chains).sorted(), id: \.self) { chain in
                let chainAtoms = structure.atoms.filter { $0.chain == chain }
                let residues = Set(chainAtoms.map { "\($0.chain):\($0.residueNumber)" })
                let uniqueResidues = Set(chainAtoms.map { $0.residueName })
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chain \(chain)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Chain overview
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Length")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(residues.count) residues")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(chainAtoms.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Residue Types")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(uniqueResidues.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    
                    // Sequence information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sequence Information")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        let sortedResidues = Array(Set(chainAtoms.map { $0.residueNumber })).sorted()
                        let sequence = sortedResidues.map { resNum in
                            let resName = chainAtoms.first { $0.residueNumber == resNum }?.residueName ?? "X"
                            return residue3to1(resName)
                        }.joined()
                        
                        Text("Length: \(sequence.count) amino acids")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(sequence)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Structural characteristics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Structural Characteristics")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        let backboneAtoms = chainAtoms.filter { $0.isBackbone }
                        let sidechainAtoms = chainAtoms.filter { !$0.isBackbone }
                        
                        HStack {
                            Text("Backbone atoms: \(backboneAtoms.count)")
                                .font(.caption)
                            Spacer()
                            Text("Side chain atoms: \(sidechainAtoms.count)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        // Secondary structure elements
                        let helixAtoms = chainAtoms.filter { $0.secondaryStructure == .helix }
                        let sheetAtoms = chainAtoms.filter { $0.secondaryStructure == .sheet }
                        let coilAtoms = chainAtoms.filter { $0.secondaryStructure == .coil }
                        
                        HStack {
                            Text("α-helix: \(helixAtoms.count) atoms")
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                            Text("β-sheet: \(sheetAtoms.count) atoms")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Spacer()
                            Text("Coil: \(coilAtoms.count) atoms")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Interactive buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            // Toggle chain highlight - 즉시 UI 피드백
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if highlightedChains.contains(chain) {
                                    highlightedChains.remove(chain)
                                } else {
                                    highlightedChains.insert(chain)
                                }
                            }
                            
                            // 3D 이미지 업데이트를 위한 로딩 상태 시작
                            isRendering3D = true
                            renderingProgress = "Updating highlights..."
                            
                            // Haptic feedback for immediate response
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // 로딩 상태를 잠시 후 자동으로 해제 (실제로는 3D 렌더링 완료 시 해제됨)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isRendering3D = false
                                renderingProgress = ""
                            }
                        }) {
                            HStack {
                                Image(systemName: highlightedChains.contains(chain) ? "pencil.and.outline" : "pencil")
                                Text(highlightedChains.contains(chain) ? "Unhighlight" : "Highlight")
                            }
                            .font(.caption)
                            .foregroundColor(highlightedChains.contains(chain) ? .white : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(highlightedChains.contains(chain) ? Color.blue : Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Button(action: {
                            // Toggle chain focus
                            if let currentFocus = focusedElement,
                               case .chain(let currentChain) = currentFocus,
                               currentChain == chain {
                                // Unfocus if already focused on this chain
                                focusedElement = nil
                                isFocused = false
                            } else {
                                // Focus on this chain
                                focusedElement = .chain(chain)
                                isFocused = true
                            }
                            
                            // 3D 이미지 업데이트를 위한 로딩 상태 시작
                            isRendering3D = true
                            renderingProgress = "Updating focus..."
                            
                            // Haptic feedback for immediate response
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // 로딩 상태를 잠시 후 자동으로 해제 (실제로는 3D 렌더링 완료 시 해제됨)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isRendering3D = false
                                renderingProgress = ""
                            }
                        }) {
                            let isCurrentlyFocused = {
                                if let currentFocus = focusedElement,
                                   case .chain(let currentChain) = currentFocus {
                                    return currentChain == chain
                                }
                                return false
                            }()
                            
                            HStack {
                                Image(systemName: isCurrentlyFocused ? "scope.fill" : "scope")
                                Text(isCurrentlyFocused ? "Unfocus" : "Focus")
                            }
                            .font(.caption)
                            .foregroundColor(isCurrentlyFocused ? .white : .green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isCurrentlyFocused ? Color.green : Color.green.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func residuesContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Residue composition overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Residue Composition")
                    .font(.headline)
                
                let residueCounts = Dictionary(grouping: structure.atoms, by: { $0.residueName })
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }
                
                let totalResidues = residueCounts.map { $0.value }.reduce(0, +)
                
                VStack(spacing: 8) {
                    ForEach(Array(residueCounts.prefix(15)), id: \.key) { residue, count in
                        HStack {
                            Text(residue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .leading)
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            Spacer()
                            
                            let percentage = Double(count) / Double(totalResidues) * 100
                            Rectangle()
                                .fill(residueColor(residue))
                                .frame(width: CGFloat(percentage) * 3, height: 20)
                                .cornerRadius(4)
                            
                            Text("\(String(format: "%.1f", percentage))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Physical-chemical properties
            VStack(alignment: .leading, spacing: 12) {
                Text("Physical-Chemical Properties")
                    .font(.headline)
                
                let hydrophobicResidues = ["ALA", "VAL", "ILE", "LEU", "MET", "PHE", "TRP", "PRO"]
                let polarResidues = ["SER", "THR", "ASN", "GLN", "TYR", "CYS"]
                let chargedResidues = ["LYS", "ARG", "HIS", "ASP", "GLU"]
                
                let hydrophobicCount = structure.atoms.filter { hydrophobicResidues.contains($0.residueName) }.count
                let polarCount = structure.atoms.filter { polarResidues.contains($0.residueName) }.count
                let chargedCount = structure.atoms.filter { chargedResidues.contains($0.residueName) }.count
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Hydrophobic")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(hydrophobicCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Polar")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(polarCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Charged")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(chargedCount) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Structural roles
            VStack(alignment: .leading, spacing: 12) {
                Text("Structural Roles")
                    .font(.headline)
                
                let backboneAtoms = structure.atoms.filter { $0.isBackbone }
                let sidechainAtoms = structure.atoms.filter { !$0.isBackbone }
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Backbone")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                        Spacer()
                        Text("\(backboneAtoms.count) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Side Chain")
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("\(sidechainAtoms.count) atoms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // Helper function for residue color coding
    private func residueColor(_ residue: String) -> Color {
        let hydrophobicResidues = ["ALA", "VAL", "ILE", "LEU", "MET", "PHE", "TRP", "PRO"]
        let polarResidues = ["SER", "THR", "ASN", "GLN", "TYR", "CYS"]
        let chargedResidues = ["LYS", "ARG", "HIS", "ASP", "GLU"]
        
        if hydrophobicResidues.contains(residue) {
            return .orange
        } else if polarResidues.contains(residue) {
            return .blue
        } else if chargedResidues.contains(residue) {
            return .red
        } else {
            return .gray
        }
    }
    
    private func ligandsContent(structure: PDBStructure) -> some View {
                                    VStack(spacing: 16) {
            let ligands = structure.atoms.filter { $0.isLigand }
            let ligandGroups = Dictionary(grouping: ligands, by: { $0.residueName })
            
            if ligands.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "molecule")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Ligands Detected")
                                            .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This structure does not contain any small molecules or ions bound to the protein.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Ligand overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ligand Overview")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Ligands")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(ligandGroups.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(ligands.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Individual ligands
                ForEach(Array(ligandGroups.keys).sorted(), id: \.self) { ligandName in
                    let ligandAtoms = ligandGroups[ligandName] ?? []
                    let uniqueChains = Set(ligandAtoms.map { $0.chain })
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ligandName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Ligand information
                        VStack(spacing: 8) {
                            HStack {
                                Text("Atoms")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(ligandAtoms.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Chains")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Array(uniqueChains).sorted().joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // Element composition
                            let elementCounts = Dictionary(grouping: ligandAtoms, by: { $0.element })
                                .mapValues { $0.count }
                                .sorted { $0.value > $1.value }
                            
                            HStack {
                                Text("Elements")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(elementCounts.map { "\($0.key)\($0.value)" }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Binding information
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Binding Information")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("Binding Sites")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(uniqueChains.count) chain(s)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Molecular Weight")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("~\(ligandAtoms.count * 12) Da")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Interactive buttons
                            HStack(spacing: 12) {
                            Button(action: {
                                // Toggle ligand highlight - 즉시 UI 피드백
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if highlightedLigands.contains(ligandName) {
                                        highlightedLigands.remove(ligandName)
                                    } else {
                                        highlightedLigands.insert(ligandName)
                                    }
                                }
                                
                                // 3D 이미지 업데이트를 위한 로딩 상태 시작
                                isRendering3D = true
                                renderingProgress = "Updating highlights..."
                                
                                // Haptic feedback for immediate response
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                // 로딩 상태를 잠시 후 자동으로 해제 (실제로는 3D 렌더링 완료 시 해제됨)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isRendering3D = false
                                    renderingProgress = ""
                                }
                            }) {
                                HStack {
                                    Image(systemName: highlightedLigands.contains(ligandName) ? "highlighter.fill" : "highlighter")
                                    Text(highlightedLigands.contains(ligandName) ? "Unhighlight" : "Highlight")
                                }
                                .font(.caption)
                                .foregroundColor(highlightedLigands.contains(ligandName) ? .white : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(highlightedLigands.contains(ligandName) ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                // Toggle ligand focus
                                if let currentFocus = focusedElement,
                                   case .ligand(let currentLigand) = currentFocus,
                                   currentLigand == ligandName {
                                    // Unfocus if already focused on this ligand
                                    focusedElement = nil
                                    isFocused = false
                                } else {
                                    // Focus on this ligand
                                    focusedElement = .ligand(ligandName)
                                    isFocused = true
                                }
                                
                                // 3D 이미지 업데이트를 위한 로딩 상태 시작
                                isRendering3D = true
                                renderingProgress = "Updating focus..."
                                
                                // Haptic feedback for immediate response
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                // 로딩 상태를 잠시 후 자동으로 해제 (실제로는 3D 렌더링 완료 시 해제됨)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isRendering3D = false
                                    renderingProgress = ""
                                }
                            }) {
                                let isCurrentlyFocused = {
                                    if let currentFocus = focusedElement,
                                       case .ligand(let currentLigand) = currentFocus {
                                        return currentLigand == ligandName
                                    }
                                    return false
                                }()
                                
                                HStack {
                                    Image(systemName: isCurrentlyFocused ? "scope.fill" : "scope")
                                    Text(isCurrentlyFocused ? "Unfocus" : "Focus")
                                }
                                .font(.caption)
                                .foregroundColor(isCurrentlyFocused ? .white : .green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isCurrentlyFocused ? Color.green : Color.green.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func pocketsContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            let pockets = structure.atoms.filter { $0.isPocket }
            let pocketGroups = Dictionary(grouping: pockets, by: { $0.residueName })
            
            if pockets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Binding Pockets Detected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This structure does not contain any identified binding pockets or active sites.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Pocket overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Binding Pocket Overview")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Pockets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pocketGroups.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Atoms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pockets.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
                
                // Individual pockets
                ForEach(Array(pocketGroups.keys).sorted(), id: \.self) { pocketName in
                    let pocketAtoms = pocketGroups[pocketName] ?? []
                    let uniqueChains = Set(pocketAtoms.map { $0.chain })
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(pocketName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Pocket information
                        VStack(spacing: 8) {
                    HStack {
                                Text("Atoms")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                        Spacer()
                                Text("\(pocketAtoms.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Chains")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Array(uniqueChains).sorted().joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // Element composition
                            let elementCounts = Dictionary(grouping: pocketAtoms, by: { $0.element })
                                .mapValues { $0.count }
                                .sorted { $0.value > $1.value }
                            
                            HStack {
                                Text("Elements")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(elementCounts.map { "\($0.key)\($0.value)" }.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Pocket characteristics
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pocket Characteristics")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("Accessibility")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                    Spacer()
                                Text("Surface exposed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Size")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(pocketAtoms.count) atoms")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Depth")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Medium")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Functional importance
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Functional Importance")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("Binding Potential")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("High")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Conservation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Unknown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Interactive buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                // Toggle pocket highlight - 즉시 UI 피드백
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if highlightedPockets.contains(pocketName) {
                                        highlightedPockets.remove(pocketName)
                                    } else {
                                        highlightedPockets.insert(pocketName)
                                    }
                                }
                                
                                // 3D 이미지 업데이트를 위한 로딩 상태 시작
                                isRendering3D = true
                                renderingProgress = "Updating highlights..."
                                
                                // Haptic feedback for immediate response
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                // 로딩 상태를 잠시 후 자동으로 해제 (실제로는 3D 렌더링 완료 시 해제됨)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isRendering3D = false
                                    renderingProgress = ""
                                }
                            }) {
                                HStack {
                                    Image(systemName: highlightedPockets.contains(pocketName) ? "highlighter.fill" : "highlighter")
                                    Text(highlightedPockets.contains(pocketName) ? "Unhighlight" : "Highlight")
                                }
                                .font(.caption)
                                .foregroundColor(highlightedPockets.contains(pocketName) ? .white : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(highlightedPockets.contains(pocketName) ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                // Toggle pocket focus
                                if let currentFocus = focusedElement,
                                   case .pocket(let currentPocket) = currentFocus,
                                   currentPocket == pocketName {
                                    // Unfocus if already focused on this pocket
                                    focusedElement = nil
                                    isFocused = false
                                } else {
                                    // Focus on this pocket
                                    focusedElement = .pocket(pocketName)
                                    isFocused = true
                                }
                                
                                // 3D 이미지 업데이트를 위한 로딩 상태 시작
                                isRendering3D = true
                                renderingProgress = "Updating focus..."
                                
                                // Haptic feedback for immediate response
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                // 로딩 상태를 잠시 후 자동으로 해제 (실제로는 3D 렌더링 완료 시 해제됨)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isRendering3D = false
                                    renderingProgress = ""
                                }
                            }) {
                                let isCurrentlyFocused = {
                                    if let currentFocus = focusedElement,
                                       case .pocket(let currentPocket) = currentFocus {
                                        return currentPocket == pocketName
                                    }
                                    return false
                                }()
                                
                                HStack {
                                    Image(systemName: isCurrentlyFocused ? "scope.fill" : "scope")
                                    Text(isCurrentlyFocused ? "Unfocus" : "Focus")
                                }
                                .font(.caption)
                                .foregroundColor(isCurrentlyFocused ? .white : .green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isCurrentlyFocused ? Color.green : Color.green.opacity(0.1))
                                .cornerRadius(16)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func sequenceContent(structure: PDBStructure) -> some View {
        let chains = Set(structure.atoms.map { $0.chain })
        let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
        
        return VStack(spacing: 16) {
            // Sequence overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Sequence Overview")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chains")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(chains.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Residues")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalResidues)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Individual chain sequences
            ForEach(Array(chains).sorted(), id: \.self) { chain in
                let chainAtoms = structure.atoms
                    .filter { $0.chain == chain }
                    .sorted { $0.residueNumber < $1.residueNumber }
                
                let uniqueResidues = Array(Set(chainAtoms.map { $0.residueNumber })).sorted()
                let sequence = uniqueResidues.map { resNum in
                    let resName = chainAtoms.first { $0.residueNumber == resNum }?.residueName ?? "X"
                    return residue3to1(resName)
                }.joined()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chain \(chain) Sequence")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Sequence information
                    HStack {
                        Text("Length: \(sequence.count) amino acids")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Residues: \(uniqueResidues.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Full sequence display
                    ScrollView {
                        Text(sequence)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                    
                    // Sequence composition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sequence Composition")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        let chainResidues = chainAtoms.map { $0.residueName }
                        let composition = Dictionary(grouping: chainResidues, by: { $0 })
                            .mapValues { $0.count }
                            .sorted { $0.value > $1.value }
                        
                        ForEach(Array(composition.prefix(10)), id: \.key) { residue, count in
                            HStack {
                                Text(residue)
                                    .font(.caption)
                                    .frame(width: 50, alignment: .leading)
                                
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                Spacer()
                                
                                let percentage = Double(count) / Double(chainResidues.count) * 100
                                Rectangle()
                                    .fill(residueColor(residue))
                                    .frame(width: CGFloat(percentage) * 2, height: 16)
                                    .cornerRadius(2)
                                
                                Text("\(String(format: "%.1f", percentage))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Overall sequence analysis
            VStack(alignment: .leading, spacing: 12) {
                Text("Overall Sequence Analysis")
                    .font(.headline)
                
                let allResidues = structure.atoms.map { $0.residueName }
                let composition = Dictionary(grouping: allResidues, by: { $0 })
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }
                
                // Most common residues
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Common Residues")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(composition.prefix(5)), id: \.key) { residue, count in
                        HStack {
                            Text(residue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .leading)
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            Spacer()
                            
                            let percentage = Double(count) / Double(allResidues.count) * 100
                            Rectangle()
                                .fill(residueColor(residue))
                                .frame(width: CGFloat(percentage) * 3, height: 20)
                                .cornerRadius(4)
                            
                            Text("\(String(format: "%.1f", percentage))%")
                    .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // Sequence statistics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sequence Statistics")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Unique Residue Types")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(composition.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Average Residue Frequency")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", Double(allResidues.count) / Double(composition.count)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func annotationsContent(structure: PDBStructure) -> some View {
        VStack(spacing: 16) {
            // Structure Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Structure Information")
                    .font(.headline)
                
            VStack(spacing: 8) {
                    InfoRow(title: "PDB ID", value: proteinId ?? "Unknown", description: "Protein Data Bank identifier - unique code for this structure")
                    InfoRow(title: "Total Atoms", value: "\(structure.atoms.count)", description: "All atoms in the structure including protein and ligands")
                    InfoRow(title: "Total Bonds", value: "\(structure.bonds.count)", description: "Chemical bonds connecting atoms in the structure")
                    InfoRow(title: "Chains", value: "\(Set(structure.atoms.map { $0.chain }).count)", description: "Number of polypeptide chains in the protein")
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // Chemical Composition
            VStack(alignment: .leading, spacing: 12) {
                Text("Chemical Composition")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueElements = Set(structure.atoms.map { $0.element })
                    InfoRow(title: "Elements", value: "\(uniqueElements.count)", description: "Number of different chemical elements present")
                    
                    let elementList = Array(uniqueElements).sorted().joined(separator: ", ")
                    InfoRow(title: "Element Types", value: elementList, description: "Chemical elements found in this structure")
                    
                    let chainList = Array(Set(structure.atoms.map { $0.chain })).sorted()
                    InfoRow(title: "Chain IDs", value: chainList.joined(separator: ", "), description: "Identifiers for each polypeptide chain")
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // Protein Classification
            VStack(alignment: .leading, spacing: 12) {
                Text("Protein Classification")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    let uniqueResidues = Set(structure.atoms.map { $0.residueName })
                    InfoRow(title: "Residue Types", value: "\(uniqueResidues.count)", description: "Number of different amino acid types present")
                    
                    let residueList = Array(uniqueResidues).sorted().joined(separator: ", ")
                    InfoRow(title: "Residue Names", value: residueList, description: "Three-letter codes of amino acids in this protein")
                    
                    let totalResidues = Set(structure.atoms.map { "\($0.chain):\($0.residueNumber)" }).count
                    InfoRow(title: "Total Residues", value: "\(totalResidues)", description: "Total number of amino acid residues across all chains")
                }
            }
            .padding()
            .background(Color.cyan.opacity(0.1))
            .cornerRadius(12)
            
            // Biological Context
            VStack(alignment: .leading, spacing: 12) {
                Text("Biological Context")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    InfoRow(title: "Structure Type", value: "Protein", description: "This is a protein structure determined by experimental methods")
                    InfoRow(title: "Data Source", value: "PDB", description: "Protein Data Bank - worldwide repository of 3D structure data")
                    InfoRow(title: "Quality", value: "Experimental", description: "Structure determined through experimental techniques like X-ray crystallography")
                    
                    let hasLigands = structure.atoms.contains { $0.isLigand }
                    InfoRow(title: "Ligands", value: hasLigands ? "Present" : "None", description: hasLigands ? "Small molecules or ions bound to the protein" : "No small molecules detected in this structure")
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Show original annotations if available
            if !structure.annotations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.title2)
                            .foregroundColor(.indigo)
                        
                        Text("Additional Annotations")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(structure.annotations.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(structure.annotations, id: \.type) { annotation in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(annotation.type.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text(annotation.value)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if !annotation.description.isEmpty {
                                    Text(annotation.description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(16)
                .background(.indigo.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // Helper function for amino acid conversion
    private func residue3to1(_ code: String) -> String {
        switch code.uppercased() {
        case "ALA": return "A"
        case "ARG": return "R"
        case "ASN": return "N"
        case "ASP": return "D"
        case "CYS": return "C"
        case "GLN": return "Q"
        case "GLU": return "E"
        case "GLY": return "G"
        case "HIS": return "H"
        case "ILE": return "I"
        case "LEU": return "L"
        case "LYS": return "K"
        case "MET": return "M"
        case "PHE": return "F"
        case "PRO": return "P"
        case "SER": return "S"
        case "THR": return "T"
        case "TRP": return "W"
        case "TYR": return "Y"
        case "VAL": return "V"
        default: return "X"
        }
    }
    

}

struct ProteinSceneView: UIViewRepresentable {
    let structure: PDBStructure?
    let style: RenderStyle
    let colorMode: ColorMode
    let uniformColor: UIColor
    let autoRotate: Bool
    let isInfoMode: Bool
    var showInfoBar: Binding<Bool>? = nil
    var onSelectAtom: ((Atom) -> Void)? = nil
    
    // Highlight parameters
    let highlightedChains: Set<String>
    let highlightedLigands: Set<String>
    let highlightedPockets: Set<String>
    
    // Focus parameters
    let focusedElement: FocusedElement?
    var onFocusRequest: ((FocusedElement) -> Void)? = nil
    
    // Loading parameters
    var isRendering3D: Binding<Bool>? = nil
    var renderingProgress: Binding<String>? = nil
    
    // Options parameters (기본값 설정으로 기존 코드 영향 최소화)
    let zoomLevel: Double
    let transparency: Double
    let atomSize: Double
    
    // 기본 초기화
    init(structure: PDBStructure?, style: RenderStyle, colorMode: ColorMode, uniformColor: UIColor, autoRotate: Bool, isInfoMode: Bool, showInfoBar: Binding<Bool>? = nil, onSelectAtom: ((Atom) -> Void)? = nil, highlightedChains: Set<String>, highlightedLigands: Set<String>, highlightedPockets: Set<String>, focusedElement: FocusedElement?, onFocusRequest: ((FocusedElement) -> Void)? = nil, isRendering3D: Binding<Bool>? = nil, renderingProgress: Binding<String>? = nil, zoomLevel: Double = 1.0, transparency: Double = 1.0, atomSize: Double = 1.0) {
        self.structure = structure
        self.style = style
        self.colorMode = colorMode
        self.uniformColor = uniformColor
        self.autoRotate = autoRotate
        self.isInfoMode = isInfoMode
        self.showInfoBar = showInfoBar
        self.onSelectAtom = onSelectAtom
        self.highlightedChains = highlightedChains
        self.highlightedLigands = highlightedLigands
        self.highlightedPockets = highlightedPockets
        self.focusedElement = focusedElement
        self.onFocusRequest = onFocusRequest
        self.isRendering3D = isRendering3D
        self.renderingProgress = renderingProgress
        self.zoomLevel = zoomLevel
        self.transparency = transparency
        self.atomSize = atomSize
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        rebuild(view: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // 실제 변경된 경우에만 빌드 (성능 최적화)
        let structureChanged = context.coordinator.lastStructure?.atoms.count != structure?.atoms.count
        let styleChanged = context.coordinator.lastStyle != style
        let colorModeChanged = context.coordinator.lastColorMode != colorMode
        let chainsChanged = context.coordinator.lastHighlightedChains != highlightedChains
        let ligandsChanged = context.coordinator.lastHighlightedLigands != highlightedLigands
        let pocketsChanged = context.coordinator.lastHighlightedPockets != highlightedPockets
        let focusChanged = context.coordinator.lastFocusElement != focusedElement
        
        // Options 변경사항 감지
        let zoomChanged = abs(context.coordinator.lastZoomLevel - zoomLevel) > 0.01
        let transparencyChanged = abs(context.coordinator.lastTransparency - transparency) > 0.01
        let atomSizeChanged = abs(context.coordinator.lastAtomSize - atomSize) > 0.01
        
        let needsRebuild = structureChanged || styleChanged || colorModeChanged || chainsChanged || ligandsChanged || pocketsChanged || focusChanged || zoomChanged || transparencyChanged || atomSizeChanged
        
        if needsRebuild {
            print("🔧 3D 구조 변경 감지 - 한 번만 빌드")
            
            // Loading 시작
            DispatchQueue.main.async {
                self.isRendering3D?.wrappedValue = true
                if chainsChanged {
                    self.renderingProgress?.wrappedValue = "Updating highlights..."
                } else {
                    self.renderingProgress?.wrappedValue = "Updating 3D structure..."
                }
            }
            
            rebuild(view: uiView)
            
            // 현재 상태 저장
            context.coordinator.lastStructure = structure
            context.coordinator.lastStyle = style
            context.coordinator.lastColorMode = colorMode
            context.coordinator.lastHighlightedChains = highlightedChains
            context.coordinator.lastHighlightedLigands = highlightedLigands
            context.coordinator.lastHighlightedPockets = highlightedPockets
            context.coordinator.lastFocusElement = focusedElement
            
            // Options 상태 저장
            context.coordinator.lastZoomLevel = zoomLevel
            context.coordinator.lastTransparency = transparency
            context.coordinator.lastAtomSize = atomSize
        }
        
        // autoRotate는 별도 처리 (빌드와 무관)
        if autoRotate {
            let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8.0)
            let repeatAction = SCNAction.repeatForever(rotateAction)
            uiView.scene?.rootNode.runAction(repeatAction, forKey: "autoRotate")
        } else {
            uiView.scene?.rootNode.removeAction(forKey: "autoRotate")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // Improved rebuild method for ProteinSceneView
    private func rebuild(view: SCNView) {
        // Protein structure rebuild
        // Start loading indicator
        DispatchQueue.main.async {
            self.isRendering3D?.wrappedValue = true
            self.renderingProgress?.wrappedValue = "Initializing 3D scene..."
        }
        
        // 비동기로 3D 렌더링 처리
        Task {
            await performAsyncRendering(view: view)
        }
    }
    
    @MainActor
    private func performAsyncRendering(view: SCNView) async {
        
        // Scene 재사용 로직 - 기존 scene이 있으면 재사용, 없으면 새로 생성
        let scene: SCNScene
        if view.scene == nil {
            scene = SCNScene()
            view.scene = scene
        } else {
            scene = view.scene!
            // 기존 proteinNode만 제거
            scene.rootNode.childNodes.forEach { node in
                if node.name == "protein" {
                    node.removeFromParentNode()
                }
            }
        }

        // Improved lighting setup
        self.renderingProgress?.wrappedValue = "Setting up lighting..."
        setupLighting(scene: scene)

        if let structure = structure {
            print("Creating protein node with \(structure.atoms.count) atoms and \(structure.bonds.count) bonds")
            
            self.renderingProgress?.wrappedValue = "Creating protein structure..."
            
            // 백그라운드에서 무거운 3D 처리
            let proteinNode = await Task.detached {
                return await self.createProteinNode(from: structure)
            }.value
            
            proteinNode.name = "protein"
            scene.rootNode.addChildNode(proteinNode)
            
            // Calculate bounds based on focus state
            let (center, boundingSize): (SCNVector3, Float)
            if let focusElement = focusedElement {
                (center, boundingSize) = calculateFocusBounds(structure: structure, focusElement: focusElement)
                print("Focus bounds - center: \(center), size: \(boundingSize)")
            } else {
                (center, boundingSize) = calculateProteinBounds(structure: structure)
            print("Protein center: \(center), bounding size: \(boundingSize)")
            }
            
            // Move protein to origin
            proteinNode.position = SCNVector3(-center.x, -center.y, -center.z)
            
            // Improved camera setup
            self.renderingProgress?.wrappedValue = "Setting up camera..."
            setupCamera(scene: scene, view: view, boundingSize: boundingSize)
            
        } else {
            print("No structure provided to ProteinSceneView")
            // Default camera setup
            setupDefaultCamera(scene: scene, view: view)
        }

        view.scene = scene
        
        // End loading indicator
        self.isRendering3D?.wrappedValue = false
        self.renderingProgress?.wrappedValue = ""
    }

    private func createProteinNode(from structure: PDBStructure) -> SCNNode {
        let rootNode = SCNNode()
        
        // Performance optimization settings - 사용자 설정 반영
        let maxAtomsLimit = UserDefaults.standard.integer(forKey: "maxAtomsLimit")
        let enableOptimization = UserDefaults.standard.bool(forKey: "enableOptimization")
        let samplingRatio = UserDefaults.standard.double(forKey: "samplingRatio")
        
        // Use default values if not set
        let effectiveMaxAtoms = maxAtomsLimit > 0 ? maxAtomsLimit : 5000
        let effectiveOptimization = enableOptimization
        let effectiveSamplingRatio = samplingRatio > 0 ? samplingRatio : 0.25
        
        print("🔧 Performance settings: maxAtoms=\(effectiveMaxAtoms), optimization=\(effectiveOptimization), sampling=\(effectiveSamplingRatio)")
        print("🔧 Structure atoms: \(structure.atoms.count), condition: \(structure.atoms.count > effectiveMaxAtoms)")
        
        // Apply optimization if enabled
        let atomsToRender: [Atom]
        if effectiveOptimization && structure.atoms.count > effectiveMaxAtoms {
            print("🔧 Applying optimization: \(structure.atoms.count) atoms → max \(effectiveMaxAtoms)")
            
            // Proportional sampling to maintain overall shape
            let chainAtoms = Dictionary(grouping: structure.atoms) { $0.chain }
            let samplingRatio = effectiveSamplingRatio // 사용자 설정 샘플링 비율 사용
            
            var proportionalAtoms: [Atom] = []
            for (chainId, atoms) in chainAtoms {
                let targetCount = Int(Double(atoms.count) * samplingRatio)
                let selectedAtoms = sampleAtomsEvenly(atoms, targetCount: targetCount)
                proportionalAtoms.append(contentsOf: selectedAtoms)
                print("🔧 Chain \(chainId): \(atoms.count) → \(selectedAtoms.count) atoms (\(String(format: "%.1f", Double(selectedAtoms.count) / Double(atoms.count) * 100))%)")
            }
            atomsToRender = proportionalAtoms
        } else {
            atomsToRender = structure.atoms
        }
        
        print("Creating \(atomsToRender.count) atoms...")
        
        // Create atoms with progress updates
        let totalAtoms = atomsToRender.count
        for (index, atom) in atomsToRender.enumerated() {
            let atomNode = createAtomNode(atom)
            rootNode.addChildNode(atomNode)
            
            // Update progress every 100 atoms or at the end
            if index % 100 == 0 || index == totalAtoms - 1 {
                DispatchQueue.main.async {
                    self.renderingProgress?.wrappedValue = "Creating atoms (\(index + 1)/\(totalAtoms))..."
                }
            }
            
            if index < 5 { // Log first 5 atoms for debugging
                print("Atom \(index): \(atom.element) at position \(atom.position)")
            }
        }
        
        // Filter bonds to only include those between rendered atoms
        let renderedAtomIds = Set(atomsToRender.map { $0.id })
        let filteredBonds = structure.bonds.filter { bond in
            renderedAtomIds.contains(bond.atomA) && renderedAtomIds.contains(bond.atomB)
        }
        
        print("Creating \(filteredBonds.count) bonds...")
        
        // Create bonds with progress updates
        let totalBonds = filteredBonds.count
        for (index, bond) in filteredBonds.enumerated() {
            let bondNode = createBondNode(bond, atoms: atomsToRender)
            rootNode.addChildNode(bondNode)
            
            // Update progress every 100 bonds or at the end
            if index % 100 == 0 || index == totalBonds - 1 {
                DispatchQueue.main.async {
                    self.renderingProgress?.wrappedValue = "Creating bonds (\(index + 1)/\(totalBonds))..."
                }
            }
            
            if index < 5 { // Log first 5 bonds for debugging
                print("Bond \(index): \(bond.atomA) - \(bond.atomB)")
            }
        }
        
        return rootNode
    }
    
    // Helper function for proportional sampling
    private func sampleAtomsEvenly(_ atoms: [Atom], targetCount: Int) -> [Atom] {
        if atoms.count <= targetCount {
            return atoms
        }
        
        let step = Double(atoms.count) / Double(targetCount)
        var sampledAtoms: [Atom] = []
        
        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            if index < atoms.count {
                sampledAtoms.append(atoms[index])
            }
        }
        
        return sampledAtoms
    }
    
    // Improved bounding box calculation
    private func calculateProteinBounds(structure: PDBStructure) -> (center: SCNVector3, size: Float) {
        guard !structure.atoms.isEmpty else {
            return (SCNVector3Zero, 10.0)
        }
        
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        for atom in structure.atoms {
            minX = min(minX, atom.position.x)
            maxX = max(maxX, atom.position.x)
            minY = min(minY, atom.position.y)
            maxY = max(maxY, atom.position.y)
            minZ = min(minZ, atom.position.z)
            maxZ = max(maxZ, atom.position.z)
        }
        
        let center = SCNVector3(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )
        
        let sizeX = maxX - minX
        let sizeY = maxY - minY
        let sizeZ = maxZ - minZ
        let maxSize = max(sizeX, max(sizeY, sizeZ))
        
        return (center, maxSize)
    }
    
    // Focus-specific bounding box calculations
    private func calculateFocusBounds(structure: PDBStructure, focusElement: FocusedElement) -> (center: SCNVector3, size: Float) {
        let atoms: [Atom]
        
        switch focusElement {
        case .chain(let chainId):
            atoms = structure.atoms.filter { $0.chain == chainId }
        case .ligand(let ligandName):
            atoms = structure.atoms.filter { $0.residueName == ligandName }
        case .pocket(let pocketName):
            atoms = structure.atoms.filter { $0.residueName == pocketName }
        case .atom(let atomId):
            atoms = structure.atoms.filter { $0.id == atomId }
        }
        
        guard !atoms.isEmpty else {
            return calculateProteinBounds(structure: structure)
        }
        
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        for atom in atoms {
            minX = min(minX, atom.position.x)
            maxX = max(maxX, atom.position.x)
            minY = min(minY, atom.position.y)
            maxY = max(maxY, atom.position.y)
            minZ = min(minZ, atom.position.z)
            maxZ = max(maxZ, atom.position.z)
        }
        
        let center = SCNVector3(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )
        
        let sizeX = maxX - minX
        let sizeY = maxY - minY
        let sizeZ = maxZ - minZ
        let maxSize = max(sizeX, max(sizeY, sizeZ))
        
        return (center, maxSize)
    }
    
    // Improved camera setup
    private func setupCamera(scene: SCNScene, view: SCNView, boundingSize: Float) {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 1000
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        // Calculate appropriate camera distance
        // Info 모드일 때는 카메라를 2배 가깝게 (3.0 → 1.5)하여 이미지를 2배 크게 보이게 함
        let multiplier: Float = isInfoMode ? 1.5 : 3.0
        let baseCameraDistance: Float = max(boundingSize * multiplier, 20.0)
        let cameraDistance = min(baseCameraDistance, 200.0) // Maximum value limit
        
        // Zoom Level 적용
        let adjustedDistance = cameraDistance / Float(zoomLevel)
        
        cameraNode.position = SCNVector3(0, 0, adjustedDistance)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        
        print("Camera positioned at distance: \(cameraDistance), bounding size: \(boundingSize), isInfoMode: \(isInfoMode)")
        
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode
    }
    
    // Default camera setup (when no structure is available)
    private func setupDefaultCamera(scene: SCNScene, view: SCNView) {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 1000
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 50)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode
    }
    
    // Separated lighting setup
    private func setupLighting(scene: SCNScene) {
        // Key light (main lighting)
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 800 // Slightly reduced
        keyLight.color = UIColor.white
        keyLight.castsShadow = false // Disable shadows for performance improvement
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(10, 20, 30)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)
        
        // Fill light
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 300
        fillLight.color = UIColor(white: 0.8, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-15, 15, -15)
        scene.rootNode.addChildNode(fillLightNode)
        
        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 200
        ambientLight.color = UIColor(white: 0.4, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
    }
    
    // Improved atom node creation
    private func createAtomNode(_ atom: Atom) -> SCNNode {
        let baseRadius: CGFloat = 1.0 // Smaller base size
        let radius: CGFloat
        let color: UIColor
        
        // Check if atom should be highlighted
        let isHighlighted = highlightedChains.contains(atom.chain) || 
                           highlightedLigands.contains(atom.residueName) || 
                           highlightedPockets.contains(atom.residueName)
        
        // Check if atom is in focus
        let isInFocus = isAtomInFocus(atom)
        
        // Determine opacity based on focus and highlight state
        let baseOpacity: CGFloat
        if isInFocus {
            baseOpacity = 1.0 // Full opacity for focused atoms
        } else if isHighlighted {
            baseOpacity = 0.9 // High opacity for highlighted atoms
        } else if focusedElement != nil {
            baseOpacity = 0.2 // Low opacity for non-focused atoms when something is focused
        } else {
            baseOpacity = 0.4 // Normal opacity when nothing is focused
        }
        
        // Apply transparency slider
        let opacity = baseOpacity * CGFloat(transparency)
        
        if isHighlighted {
            // Highlighted atoms: brighter colors and slightly larger
            radius = baseRadius * 1.2 * (atom.element.atomicRadius / 0.7) * CGFloat(atomSize)
        switch colorMode {
        case .element:
                color = UIColor(atom.element.color).withAlphaComponent(opacity)
        case .chain:
                color = chainColor(for: atom.chain).withAlphaComponent(opacity)
        case .uniform:
                color = uniformColor.withAlphaComponent(opacity)
        case .secondaryStructure:
                color = UIColor(atom.secondaryStructure.color).withAlphaComponent(opacity)
            }
        } else {
            // Normal atoms: standard colors with appropriate opacity
            radius = baseRadius * (atom.element.atomicRadius / 0.7) * CGFloat(atomSize)
            switch colorMode {
            case .element:
                color = UIColor(atom.element.color).withAlphaComponent(opacity)
            case .chain:
                color = chainColor(for: atom.chain).withAlphaComponent(opacity)
            case .uniform:
                color = uniformColor.withAlphaComponent(opacity)
            case .secondaryStructure:
                color = UIColor(atom.secondaryStructure.color).withAlphaComponent(opacity)
            }
        }
        
        // Size adjustment based on style
        let finalRadius = radius * styleSizeMultiplier()
        
        let geometry: SCNGeometry
        switch style {
        case .spheres:
            geometry = GeometryCache.shared.lodSphere(radius: finalRadius, color: color)
        case .sticks:
            geometry = GeometryCache.shared.lodSphere(radius: finalRadius * 0.5, color: color)
        case .cartoon:
            geometry = createCartoonGeometry(for: atom, radius: finalRadius, color: color)
        case .surface:
            geometry = createSurfaceGeometry(for: atom, radius: finalRadius, color: color)
        }
        
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(atom.position.x, atom.position.y, atom.position.z)
        node.name = "atom_\(atom.id)"
        
        return node
    }
    
    // Improved bond node creation
    private func createBondNode(_ bond: Bond, atoms: [Atom]) -> SCNNode {
        guard let atom1 = atoms.first(where: { $0.id == bond.atomA }),
              let atom2 = atoms.first(where: { $0.id == bond.atomB }) else {
            return SCNNode()
        }
        
        let start = atom1.position
        let end = atom2.position
        
        // Vector calculation
        let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let distance = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        
        // Skip if distance is too small
        guard distance > 0.01 else { return SCNNode() }
        
        let bondRadius: CGFloat
        let bondColor: UIColor
        
        switch style {
        case .sticks:
            bondRadius = 0.2
            bondColor = .lightGray
        case .cartoon:
            bondRadius = 0.3  // Thicker bonds for cartoon style
            bondColor = .systemBlue
        case .surface:
            bondRadius = 0.0  // No visible bonds for surface style
            bondColor = .clear
        default:
            bondRadius = 0.1
            bondColor = .lightGray
        }
        
        // Skip bond creation for surface style
        guard style != .surface else { return SCNNode() }
        
        let cylinder = GeometryCache.shared.unitLodCylinder(radius: bondRadius, color: bondColor)
        let node = SCNNode(geometry: cylinder)
        
        // Midpoint position
        let midPoint = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        node.position = midPoint
        
        // Improved rotation calculation
        let normalizedDirection = SCNVector3(
            direction.x / distance,
            direction.y / distance,
            direction.z / distance
        )
        
        // Calculate angle with Y-axis
        let yAxis = SCNVector3(0, 1, 0)
        let rotationAxis = SCNVector3(
            yAxis.y * normalizedDirection.z - yAxis.z * normalizedDirection.y,
            yAxis.z * normalizedDirection.x - yAxis.x * normalizedDirection.z,
            yAxis.x * normalizedDirection.y - yAxis.y * normalizedDirection.x
        )
        
        let dotProduct = yAxis.y * normalizedDirection.y
        let angle = acos(max(-1, min(1, dotProduct)))
        
        if abs(angle) > 0.001 {
            node.rotation = SCNVector4(rotationAxis.x, rotationAxis.y, rotationAxis.z, angle)
        }
        
        // Apply scale (adjust height only)
        node.scale = SCNVector3(1, distance, 1)
        
        return node
    }
    
    // Style-based size multiplier
    private func styleSizeMultiplier() -> CGFloat {
        switch style {
        case .spheres: return 1.0
        case .sticks: return 0.8
        case .cartoon: return 1.2
        case .surface: return 0.9
        }
    }
    
    // Create cartoon-style geometry (small sphere for atoms)
    private func createCartoonGeometry(for atom: Atom, radius: CGFloat, color: UIColor) -> SCNGeometry {
        // Cartoon style: small spheres for atoms, bonds will be handled separately
        let smallRadius = radius * 0.25 // Much smaller than normal spheres
        return GeometryCache.shared.lodSphere(radius: smallRadius, color: color)
    }
    
    // Create surface-style geometry (larger sphere with surface-like appearance)
    private func createSurfaceGeometry(for atom: Atom, radius: CGFloat, color: UIColor) -> SCNGeometry {
        // Surface style: larger spheres that represent the molecular surface
        let surfaceRadius = radius * 1.2 // Larger than normal spheres
        let sphere = GeometryCache.shared.lodSphere(radius: surfaceRadius, color: color)
        
        // Apply surface-like material properties
        if let material = sphere.firstMaterial {
            material.transparency = 0.7 // Semi-transparent
            material.specular.contents = UIColor.white
            material.shininess = 0.8
            material.lightingModel = .physicallyBased
        }
        
        return sphere
    }
    
    // Improved chain-specific color generation
    private func chainColor(for chain: String) -> UIColor {
        let hue = CGFloat(abs(chain.hashValue) % 360) / 360.0
        return UIColor(hue: hue, saturation: 0.7, brightness: 0.8, alpha: 1.0)
    }
    
    // Check if atom is in focus
    private func isAtomInFocus(_ atom: Atom) -> Bool {
        guard let focusElement = focusedElement else { return false }
        
        switch focusElement {
        case .chain(let chainId):
            return atom.chain == chainId
        case .ligand(let ligandName):
            return atom.residueName == ligandName
        case .pocket(let pocketName):
            return atom.residueName == pocketName
        case .atom(let atomId):
            return atom.id == atomId
        }
    }
    
    // Animate camera to focus on specific element
    private func animateCameraToFocus(view: SCNView, target: SCNVector3, boundingSize: Float) {
        guard let camera = view.pointOfView else { return }
        
        // Calculate new camera position
        let distance = boundingSize * 2.5
        let newPosition = SCNVector3(
            target.x,
            target.y + distance * 0.5,
            target.z + distance
        )
        
        // Animate camera movement
        let moveAction = SCNAction.move(to: newPosition, duration: 1.0)
        moveAction.timingMode = .easeInEaseOut
        
        camera.runAction(moveAction)
        
        // Look at target
        let lookAtAction = SCNAction.rotateTo(x: CGFloat(-Float.pi / 6), y: 0, z: 0, duration: 1.0)
        lookAtAction.timingMode = .easeInEaseOut
        camera.runAction(lookAtAction)
    }
    
    // Bounding box visualization for debugging (optional)
    private func addBoundingBoxVisualization(to scene: SCNScene, center: SCNVector3, size: Float) {
        let box = SCNBox(width: CGFloat(size), height: CGFloat(size), length: CGFloat(size), chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red.withAlphaComponent(0.2)
        material.isDoubleSided = true
        box.materials = [material]
        
        let boxNode = SCNNode(geometry: box)
        boxNode.position = SCNVector3(-center.x, -center.y, -center.z)
        scene.rootNode.addChildNode(boxNode)
    }

    class Coordinator: NSObject {
        var parent: ProteinSceneView
        var lastStructure: PDBStructure?
        var lastStyle: RenderStyle?
        var lastColorMode: ColorMode?
        var lastHighlightedChains: Set<String> = []
        var lastHighlightedLigands: Set<String> = []
        var lastHighlightedPockets: Set<String> = []
        var lastFocusElement: FocusedElement?
        var lastUpdateTime: TimeInterval = 0
        
        // Options tracking variables
        var lastZoomLevel: Double = 1.0
        var lastTransparency: Double = 1.0
        var lastAtomSize: Double = 1.0
        
        init(parent: ProteinSceneView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let view = gesture.view as! SCNView
            let location = gesture.location(in: view)
            
            let hitResults = view.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .ignoreHiddenNodes: true
            ])
            
            if let result = hitResults.first,
               let nodeName = result.node.name,
               nodeName.hasPrefix("atom_"),
               let atomId = Int(nodeName.replacingOccurrences(of: "atom_", with: "")),
               let atom = parent.structure?.atoms.first(where: { $0.id == atomId }) {
                parent.onSelectAtom?(atom)
            }
        }
    }
}

// MARK: - Improved Control Components
struct ImprovedStylePicker: View {
    @Binding var selectedStyle: RenderStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rendering Style")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RenderStyle.allCases, id: \.self) { style in
                        StyleButton(
                            style: style,
                            isSelected: selectedStyle == style
                        ) {
                            selectedStyle = style
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct StyleButton: View {
    let style: RenderStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: style.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(style.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ImprovedColorModePicker: View {
    @Binding var selectedColorMode: ColorMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Scheme")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        ColorModeButton(
                            mode: mode,
                            isSelected: selectedColorMode == mode
                        ) {
                            selectedColorMode = mode
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct ColorModeButton: View {
    let mode: ColorMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(mode.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Advanced Controls
struct EnhancedAdvancedControlsView: View {
    @Binding var autoRotate: Bool
    @Binding var showBonds: Bool
    @Binding var transparency: Double
    @Binding var atomSize: Double
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    
    // Callbacks for actions
    let onResetView: () -> Void
    let onScreenshot: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Quick Actions Row
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "arrow.clockwise",
                    title: "Reset View",
                    color: .blue
                ) {
                    onResetView()
                }
                
                QuickActionButton(
                    icon: "camera",
                    title: "Screenshot",
                    color: .green
                ) {
                    onScreenshot()
                }
                
                QuickActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    color: .orange
                ) {
                    onShare()
                }
                
                Spacer()
            }
            
            // Detailed Controls
            VStack(spacing: 12) {
                // Auto-rotate toggle
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text("Auto Rotate")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoRotate)
                        .scaleEffect(0.8)
                }
                
                // Show bonds toggle
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    
                    Text("Show Bonds")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $showBonds)
                        .scaleEffect(0.8)
                }
                
                // Transparency slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "opacity")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        
                        Text("Transparency")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(Int(transparency * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $transparency, in: 0.1...1.0)
                        .accentColor(.purple)
                }
                
                // Atom size slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle.grid.cross")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        
                        Text("Atom Size")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(Int(atomSize * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $atomSize, in: 0.5...2.0)
                        .accentColor(.orange)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tab-based Control Layout
struct TabBasedViewerControls: View {
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @State private var selectedTab: ControlTab = .style
    @State private var showAdvancedControls = false
    
    // Advanced controls state
    @State private var autoRotate = false
    @State private var showBonds = true
    @State private var transparency: Double = 1.0
    @State private var atomSize: Double = 1.0
    
    enum ControlTab: String, CaseIterable {
        case style = "Rendering Style"
        case color = "Color Scheme"
        
        var title: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selection
            HStack(spacing: 0) {
                ForEach(ControlTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: selectedTab == tab ? "largecircle.fill.circle" : "circle")
                                .font(.title3)
                                .foregroundColor(selectedTab == tab ? .blue : .gray)
                            
                            Text(tab.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedTab == tab ? .blue : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Selected tab's options
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if selectedTab == .style {
                            ForEach(RenderStyle.allCases, id: \.self) { style in
                                TabOptionButton(
                                    title: style.rawValue,
                                    icon: style.icon,
                                    isSelected: selectedStyle == style,
                                    color: .blue
                                ) {
                                    selectedStyle = style
                                }
                            }
                        } else {
                            ForEach(ColorMode.allCases, id: \.self) { mode in
                                TabOptionButton(
                                    title: mode.rawValue,
                                    icon: mode.icon,
                                    isSelected: selectedColorMode == mode,
                                    color: .green
                                ) {
                                    selectedColorMode = mode
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Advanced controls (collapsible)
                if showAdvancedControls {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    EnhancedAdvancedControlsView(
                        autoRotate: $autoRotate,
                        showBonds: $showBonds,
                        transparency: $transparency,
                        atomSize: $atomSize,
                        selectedStyle: $selectedStyle,
                        selectedColorMode: $selectedColorMode,
                        onResetView: {
                            // Reset camera to default position
                            print("Reset View - Camera position reset")
                        },
                        onScreenshot: {
                            // Take screenshot of 3D view
                            print("Screenshot - Capturing 3D view")
                        },
                        onShare: {
                            // Share protein structure
                            print("Share - Sharing protein structure")
                        }
                    )
                    .transition(.opacity.combined(with: .slide))
                }
            }
            .padding(.bottom, 12)
            
            // Expand/Collapse button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAdvancedControls.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showAdvancedControls ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(showAdvancedControls ? "Less Options" : "More Options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .padding(.top, 8)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TabOptionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legacy UpdatedViewerControls (for backward compatibility)
struct UpdatedViewerControls: View {
    @Binding var selectedStyle: RenderStyle
    @Binding var selectedColorMode: ColorMode
    @State private var showAdvancedControls = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main controls panel
            VStack(spacing: 16) {
                // Style and Color pickers in horizontal layout
                HStack(alignment: .top, spacing: 20) {
                    ImprovedStylePicker(selectedStyle: $selectedStyle)
                    ImprovedColorModePicker(selectedColorMode: $selectedColorMode)
                }
                
                // Advanced controls (collapsible)
                if showAdvancedControls {
                    Divider()
                        .padding(.horizontal, -16)
                    
                    EnhancedAdvancedControlsView(
                        autoRotate: .constant(false),
                        showBonds: .constant(true),
                        transparency: .constant(1.0),
                        atomSize: .constant(1.0),
                        selectedStyle: $selectedStyle,
                        selectedColorMode: $selectedColorMode,
                        onResetView: {
                            print("Reset View - Camera position reset")
                        },
                        onScreenshot: {
                            print("Screenshot - Capturing 3D view")
                        },
                        onShare: {
                            print("Share - Sharing protein structure")
                        }
                    )
                    .transition(.opacity.combined(with: .slide))
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // Expand/Collapse button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAdvancedControls.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showAdvancedControls ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(showAdvancedControls ? "Less Options" : "More Options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Legacy UI Components (for backward compatibility)
struct StylePicker: View {
    @Binding var selectedStyle: RenderStyle
    
    var body: some View {
        Picker("Style", selection: $selectedStyle) {
            ForEach(RenderStyle.allCases, id: \.self) { style in
                Label(style.rawValue, systemImage: style.icon)
                    .tag(style)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

struct ColorModePicker: View {
    @Binding var selectedColorMode: ColorMode
    
    var body: some View {
        Picker("Color", selection: $selectedColorMode) {
            ForEach(ColorMode.allCases, id: \.self) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

struct AdvancedControlsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Advanced Controls")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Auto-rotate")
                Spacer()
                Toggle("", isOn: .constant(false))
            }
            .font(.caption)
        }
    }
}

struct InfoTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout) // .subheadline에서 .callout로 개선 (16pt)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.horizontal, 20) // 패딩 증가
                .padding(.vertical, 12) // 패딩 증가 (44pt 터치 영역 확보)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(24) // 모서리 둥글기 증가
        }
        .frame(minHeight: 44) // 최소 터치 영역 확보
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { // 간격 증가
            HStack {
                Text(title)
                    .font(.callout) // .subheadline에서 .callout로 개선 (16pt)
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .font(.callout) // .subheadline에서 .callout로 개선 (16pt)
                    .fontWeight(.medium) // 가독성 향상
                    .foregroundColor(.primary)
            }
            Text(description)
                .font(.footnote) // .caption에서 .footnote로 개선 (13pt)
                .foregroundColor(.secondary)
                .lineLimit(3) // 최대 3줄로 제한
        }
        .padding(.vertical, 8) // 패딩 증가
    }
}





// MARK: - Extensions
extension String {
    var atomicRadius: CGFloat {
        switch self.uppercased() {
        case "H": return 0.3
        case "C": return 0.7
        case "N": return 0.65
        case "O": return 0.6
        case "S": return 1.0
        case "P": return 1.0
        default: return 0.8
        }
    }
    
    var color: Color {
        switch self.uppercased() {
        case "H": return .white
        case "C": return .gray
        case "N": return .blue
        case "O": return .red
        case "S": return .yellow
        case "P": return .orange
        default: return .purple
        }
    }
}

extension SecondaryStructure {
    var color: Color {
        switch self {
        case .helix: return .red
        case .sheet: return .yellow
        case .coil: return .gray
        case .unknown: return Color(UIColor.lightGray)
        }
    }
}



