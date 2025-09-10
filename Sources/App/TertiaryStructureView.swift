import SwiftUI

struct TertiaryStructureView: View {
    let protein: ProteinInfo
    @State private var tertiaryStructure: TertiaryStructure?
    @State private var isLoadingStructure = false
    @State private var structureError: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingStructure {
                        structureLoadingView
                    } else if let error = structureError {
                        structureErrorView(error)
                    } else {
                        structureContentView
                    }
                }
                .padding()
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
            loadTertiaryStructure()
        }
    }
    
    // MARK: - Loading View
    private var structureLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading tertiary structure...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func structureErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to load structure")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadTertiaryStructure()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Content View
    private var structureContentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("3D Folding & Domains")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let structure = tertiaryStructure {
                // 도메인 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Protein Domains")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.domains.enumerated()), id: \.offset) { index, domain in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(domain.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(protein.category.color)
                                
                                Spacer()
                                
                                Text("Residues \(domain.start)-\(domain.end)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(domain.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(protein.category.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 활성 부위 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Sites")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.activeSites.enumerated()), id: \.offset) { index, site in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(site.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Text("Residues \(site.start)-\(site.end)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(site.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 결합 부위 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("Binding Sites")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(Array(structure.bindingSites.enumerated()), id: \.offset) { index, site in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(site.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                Text("Residues \(site.start)-\(site.end)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(site.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No tertiary structure data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadTertiaryStructure() {
        isLoadingStructure = true
        structureError = nil
        
        Task {
            do {
                // 실제 API 호출 대신 샘플 데이터 사용
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 지연
                
                await MainActor.run {
                    // 샘플 3차 구조 데이터
                    tertiaryStructure = TertiaryStructure(
                        domains: [
                            Domain(name: "N-terminal domain", start: 1, end: 150, description: "Catalytic domain responsible for primary enzymatic activity"),
                            Domain(name: "C-terminal domain", start: 151, end: 300, description: "Regulatory domain involved in protein-protein interactions")
                        ],
                        activeSites: [
                            ActiveSite(name: "Catalytic site", start: 50, end: 60, description: "Primary catalytic center with essential residues"),
                            ActiveSite(name: "Cofactor binding site", start: 100, end: 110, description: "Binding site for essential cofactor molecules")
                        ],
                        bindingSites: [
                            BindingSite(name: "Substrate binding site", start: 80, end: 90, description: "Primary substrate recognition and binding region"),
                            BindingSite(name: "Allosteric site", start: 200, end: 210, description: "Allosteric regulation binding site")
                        ]
                    )
                    isLoadingStructure = false
                }
            } catch {
                await MainActor.run {
                    structureError = error.localizedDescription
                    isLoadingStructure = false
                }
            }
        }
    }
}

// MARK: - Data Models
struct TertiaryStructure {
    let domains: [Domain]
    let activeSites: [ActiveSite]
    let bindingSites: [BindingSite]
}

struct Domain {
    let name: String
    let start: Int
    let end: Int
    let description: String
}

struct ActiveSite {
    let name: String
    let start: Int
    let end: Int
    let description: String
}

struct BindingSite {
    let name: String
    let start: Int
    let end: Int
    let description: String
}
