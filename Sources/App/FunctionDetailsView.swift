import SwiftUI

struct FunctionDetailsView: View {
    let protein: ProteinInfo
    @State private var functionDetails: FunctionDetails?
    @State private var isLoadingFunction = false
    @State private var functionError: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingFunction {
                        functionLoadingView
                    } else if let error = functionError {
                        functionErrorView(error)
                    } else if let details = functionDetails {
                        functionContentView(details)
                    } else {
                        Text("No function data available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Function Details")
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
            loadFunctionDetails()
        }
    }
    
    // MARK: - Loading View
    private var functionLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(LanguageHelper.localizedText(
                korean: "기능 세부사항 로딩 중...",
                english: "Loading function details..."
            ))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func functionErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to load function details")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadFunctionDetails()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Content View
    private func functionContentView(_ details: FunctionDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("Protein Function Information")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Molecular Function
            InfoCard(icon: "function", title: "Molecular Function", tint: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(details.molecularFunction)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Biological Process
            InfoCard(icon: "arrow.triangle.branch", title: "Biological Process", tint: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(details.biologicalProcess)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Cellular Component
            InfoCard(icon: "cell", title: "Cellular Component", tint: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(details.cellularComponent)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // GO Terms
            if !details.goTerms.isEmpty {
                InfoCard(icon: "tag", title: "GO Terms", tint: .purple) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(details.goTerms, id: \.id) { term in
                            HStack {
                                Text(term.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text(term.category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(term.categoryColor.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
            
            // EC Numbers
            if !details.ecNumbers.isEmpty {
                InfoCard(icon: "number", title: "EC Numbers", tint: .red) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(details.ecNumbers, id: \.self) { ecNumber in
                            Text(ecNumber)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            
            // Catalytic Activity
            if !details.catalyticActivity.isEmpty {
                InfoCard(icon: "flask", title: "Catalytic Activity", tint: .cyan) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(details.catalyticActivity)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            // Structure Information
            InfoCard(icon: "cube", title: "Structure Information", tint: .indigo) {
                VStack(alignment: .leading, spacing: 8) {
                    if let resolution = details.resolution {
                        HStack {
                            Text("Resolution:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(String(format: "%.2f", resolution)) Å")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let method = details.method {
                        HStack {
                            Text("Method:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(method)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadFunctionDetails() {
        isLoadingFunction = true
        functionError = nil
        
        Task {
            do {
                // 실제 API 호출 대신 샘플 데이터 사용
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5초 지연
                
                await MainActor.run {
                    // 샘플 Function 데이터
                    functionDetails = FunctionDetails(
                        molecularFunction: "Catalyzes the hydrolysis of peptide bonds in proteins and peptides. Acts as a key enzyme in protein degradation and recycling processes.",
                        biologicalProcess: "Protein catabolic process, proteolysis, cellular protein metabolic process, protein folding, and regulation of protein stability.",
                        cellularComponent: "Cytoplasm, lysosome, proteasome complex, and endoplasmic reticulum lumen.",
                        goTerms: [
                            GOTerm(id: "GO:0004252", name: "serine-type endopeptidase activity", category: "MF"),
                            GOTerm(id: "GO:0006508", name: "proteolysis", category: "BP"),
                            GOTerm(id: "GO:0005622", name: "intracellular", category: "CC"),
                            GOTerm(id: "GO:0004175", name: "endopeptidase activity", category: "MF")
                        ],
                        ecNumbers: ["3.4.21.1", "3.4.21.2"],
                        catalyticActivity: "Hydrolyzes peptide bonds with broad specificity, cleaving preferentially at hydrophobic residues. Requires a serine residue in the active site for catalysis.",
                        resolution: 2.1,
                        method: "X-RAY DIFFRACTION"
                    )
                    isLoadingFunction = false
                }
            } catch {
                await MainActor.run {
                    functionError = error.localizedDescription
                    isLoadingFunction = false
                }
            }
        }
    }
}

// MARK: - Data Models
struct FunctionDetails {
    let molecularFunction: String
    let biologicalProcess: String
    let cellularComponent: String
    let goTerms: [GOTerm]
    let ecNumbers: [String]
    let catalyticActivity: String
    let resolution: Double?
    let method: String?
}

struct GOTerm {
    let id: String
    let name: String
    let category: String
    
    var categoryColor: Color {
        switch category {
        case "MF": return .blue      // Molecular Function
        case "BP": return .green     // Biological Process
        case "CC": return .orange    // Cellular Component
        default: return .gray
        }
    }
}
