import SwiftUI
import SceneKit
import UIKit

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
        case .secondaryStructure: return "dna"
        }
    }
}

struct ProteinSceneView: UIViewRepresentable {
    let structure: PDBStructure?
    let style: RenderStyle
    let colorMode: ColorMode
    let uniformColor: UIColor
    let autoRotate: Bool
    var onSelectAtom: ((Atom) -> Void)? = nil

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
        rebuild(view: uiView)
        
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

    private func rebuild(view: SCNView) {
        let scene = SCNScene()
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }

        // Professional lighting setup
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1000
        keyLight.color = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        keyLight.castsShadow = true
        keyLight.shadowRadius = 8
        keyLight.shadowColor = UIColor.black.withAlphaComponent(0.3)
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(20, 30, 40)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)
        
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 400
        fillLight.color = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-15, 10, 20)
        scene.rootNode.addChildNode(fillLightNode)
        
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 200
        ambient.color = UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        if let s = structure {
            addStructure(s, to: scene)
            frameScene(scene)
        }
        view.scene = scene
    }

    private func addStructure(_ s: PDBStructure, to scene: SCNScene) {
        switch style {
        case .spheres: addSpheresRepresentation(s, to: scene)
        case .sticks: addSticksRepresentation(s, to: scene)
        case .cartoon: addCartoonRepresentation(s, to: scene)
        case .surface: addSurfaceRepresentation(s, to: scene)
        }
    }
    
    private func addSpheresRepresentation(_ s: PDBStructure, to scene: SCNScene) {
        let atomRadius: CGFloat = 0.8
        for atom in s.atoms {
            let sphere = SCNSphere(radius: atomRadius)
            sphere.segmentCount = 24
            let mat = SceneKitUtils.createEnhancedMaterial(color: colorFor(atom: atom))
            sphere.materials = [mat]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(atom.position.x, atom.position.y, atom.position.z)
            node.name = "atom:\(atom.id)"
            scene.rootNode.addChildNode(node)
        }
    }
    
    private func addSticksRepresentation(_ s: PDBStructure, to scene: SCNScene) {
        let atomRadius: CGFloat = 0.3
        let bondRadius: CGFloat = 0.15
        
        for atom in s.atoms {
            let sphere = SCNSphere(radius: atomRadius)
            sphere.segmentCount = 20
            let mat = SceneKitUtils.createEnhancedMaterial(color: colorFor(atom: atom))
            sphere.materials = [mat]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(atom.position.x, atom.position.y, atom.position.z)
            node.name = "atom:\(atom.id)"
            scene.rootNode.addChildNode(node)
        }
        
        for b in s.bonds {
            let a = s.atoms[b.a]
            let c = s.atoms[b.b]
            let cylinder = SceneKitUtils.createCylinderBetween(
                SCNVector3(a.position.x, a.position.y, a.position.z),
                SCNVector3(c.position.x, c.position.y, c.position.z),
                radius: bondRadius,
                color: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
            )
            scene.rootNode.addChildNode(cylinder)
        }
    }
    
    private func addCartoonRepresentation(_ s: PDBStructure, to scene: SCNScene) {
        let backboneAtoms = s.atoms.filter { $0.isBackbone && $0.name == "CA" }
        let chainGroups = Dictionary(grouping: backboneAtoms) { $0.chain }
        
        for (_, chainAtoms) in chainGroups {
            let sortedAtoms = chainAtoms.sorted { $0.residueNumber < $1.residueNumber }
            
            for i in 0..<(sortedAtoms.count - 1) {
                let current = sortedAtoms[i]
                let next = sortedAtoms[i + 1]
                
                let tube = SceneKitUtils.createCylinderBetween(
                    SCNVector3(current.position.x, current.position.y, current.position.z),
                    SCNVector3(next.position.x, next.position.y, next.position.z),
                    radius: 0.3,
                    color: colorFor(atom: current)
                )
                scene.rootNode.addChildNode(tube)
            }
            
            for atom in sortedAtoms {
                let sphere = SCNSphere(radius: 0.2)
                sphere.segmentCount = 16
                let mat = SceneKitUtils.createEnhancedMaterial(color: colorFor(atom: atom))
                sphere.materials = [mat]
                let node = SCNNode(geometry: sphere)
                node.position = SCNVector3(atom.position.x, atom.position.y, atom.position.z)
                node.name = "atom:\(atom.id)"
                scene.rootNode.addChildNode(node)
            }
        }
    }
    
    private func addSurfaceRepresentation(_ s: PDBStructure, to scene: SCNScene) {
        for atom in s.atoms {
            let sphere = SCNSphere(radius: 1.2)
            sphere.segmentCount = 20
            let mat = SceneKitUtils.createEnhancedMaterial(color: colorFor(atom: atom))
            mat.transparency = 0.8
            sphere.materials = [mat]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(atom.position.x, atom.position.y, atom.position.z)
            node.name = "atom:\(atom.id)"
            scene.rootNode.addChildNode(node)
        }
    }

    private func colorFor(atom: Atom) -> UIColor {
        switch colorMode {
        case .uniform: return uniformColor
        case .chain:
            let colors: [UIColor] = [
                UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
                UIColor(red: 1.0, green: 0.3, blue: 0.5, alpha: 1.0),
                UIColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 1.0),
                UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0),
                UIColor(red: 0.7, green: 0.2, blue: 1.0, alpha: 1.0),
                UIColor(red: 0.0, green: 0.7, blue: 0.8, alpha: 1.0)
            ]
            if let ch = atom.chain.unicodeScalars.first {
                return colors[Int(ch.value) % colors.count]
            }
            return UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .element:
            switch atom.element.uppercased() {
            case "H": return UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
            case "C": return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            case "N": return UIColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1.0)
            case "O": return UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
            case "S": return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
            case "P": return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
            default: return UIColor(red: 0.4, green: 0.7, blue: 0.7, alpha: 1.0)
            }
        case .secondaryStructure:
            switch atom.secondaryStructure {
            case .helix: return UIColor(red: 0.9, green: 0.2, blue: 0.4, alpha: 1.0)
            case .sheet: return UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            case .coil: return UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
            case .unknown: return UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
            }
        }
    }


}

private func frameScene(_ scene: SCNScene) {
    SceneKitUtils.frameScene(scene)
}

final class Coordinator: NSObject {
    private let parent: ProteinSceneView
    init(parent: ProteinSceneView) { self.parent = parent }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? SCNView else { return }
        let point = gesture.location(in: view)
        let results = view.hitTest(point, options: [SCNHitTestOption.categoryBitMask: 0xFFFFFFFF])
        guard let node = results.first?.node else { return }
        let target = node.name ?? node.parent?.name
        guard let name = target, name.hasPrefix("atom:"),
              let id = Int(name.dropFirst("atom:".count)),
              let atoms = parent.structure?.atoms,
              let atom = atoms.first(where: { $0.id == id }) else { return }
        parent.onSelectAtom?(atom)
    }
}

// MARK: - Main Container View
struct ProteinSceneContainer: View {
    @State private var pdbId: String = "1CRN"
    @State private var structure: PDBStructure? = nil
    @State private var style: RenderStyle = .cartoon
    @State private var color: ColorMode = .secondaryStructure
    @State private var uniformColor: Color = .purple
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var selectedAtom: Atom? = nil
    @State private var showControls = false
    @State private var autoRotate = false
    @State private var showingLibrary = false

    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
        VStack(spacing: 0) {
                    // Main 3D Viewer
                    ZStack {
                        ProteinSceneView(
                            structure: structure,
                            style: style,
                            colorMode: color,
                            uniformColor: UIColor(uniformColor),
                            autoRotate: autoRotate,
                            onSelectAtom: { atom in 
                                selectedAtom = atom
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // Loading overlay
                        if isLoading {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .scaleEffect(1.5)
                                            .tint(.blue)
                                        
                                        Text("Loading \(pdbId.uppercased())")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Bottom controls
                    VStack(spacing: 16) {
                        // Quick style selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(RenderStyle.allCases, id: \.self) { renderStyle in
                                    StyleButton(
                                        style: renderStyle,
                                        isSelected: style == renderStyle
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
                        
                        // Color mode selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ColorMode.allCases, id: \.self) { colorMode in
                                    ColorButton(
                                        colorMode: colorMode,
                                        isSelected: color == colorMode
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            self.color = colorMode
                                        }
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                    }
                    }
                    
                    if color == .uniform {
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
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Selected atom info
                    if let atom = selectedAtom {
                        AtomInfoView(atom: atom) {
                            selectedAtom = nil
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                
                // Floating action button
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            FloatingActionButton(
                                icon: autoRotate ? "pause.circle.fill" : "play.circle.fill",
                                color: .blue
                            ) {
                                autoRotate.toggle()
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            
                            FloatingActionButton(
                                icon: "info.circle.fill",
                                color: .green
                            ) {
                                // Show info
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        }
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Protein Viewer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLibrary = true
                    } label: {
                        Image(systemName: "books.vertical.fill")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        TextField("PDB ID", text: $pdbId)
                            .textCase(.uppercase)
                        
                        Button("Load Structure") {
                            Task { await load() }
                        }
                        .disabled(isLoading)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingLibrary) {
                ProteinLibraryView { selectedProteinId in
                    pdbId = selectedProteinId
                    showingLibrary = false
                    Task { await load() }
                }
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .onAppear {
            Task { await load() }
        }
    }

    private func load() async {
        guard !pdbId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Please enter a valid PDB ID"
            return
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
        isLoading = true
        error = nil
        }
        
        defer {
            withAnimation(.easeInOut(duration: 0.3)) {
                isLoading = false
            }
        }
        
        do {
            let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { 
                throw URLError(.badServerResponse) 
            }
            let text = String(decoding: data, as: UTF8.self)
            
            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            structure = PDBParser.parse(pdbText: text)
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load \(pdbId.uppercased())"
            }
        }
    }
}

// MARK: - Supporting Views

struct StyleButton: View {
    let style: RenderStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(style.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 64)
            .background(
                isSelected ? 
                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                LinearGradient(colors: [Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? .clear : Color(.systemGray4), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct ColorButton: View {
    let colorMode: ColorMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: colorMode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(colorMode.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 80, height: 64)
            .background(
                isSelected ? 
                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                LinearGradient(colors: [Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? .clear : Color(.systemGray4), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct AtomInfoView: View {
    let atom: Atom
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Atom")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ELEMENT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(atom.element)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("NAME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(atom.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("CHAIN")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(atom.chain)
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("RESIDUE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("\(atom.residueName) \(atom.residueNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}