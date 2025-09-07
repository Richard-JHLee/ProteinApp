import SwiftUI

struct SecondaryStructureView: View {
    let protein: ProteinInfo
    @State private var secondaryStructures: [SecondaryStructure] = []
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
            .navigationTitle("Secondary Structure")
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
            loadSecondaryStructure()
        }
    }
    
    // MARK: - Loading View
    private var structureLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading secondary structure...")
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
                loadSecondaryStructure()
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
                Text("Secondary Structure Elements")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !secondaryStructures.isEmpty {
                    Text("\(secondaryStructures.count) elements found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 2차 구조 요소 표시
            if !secondaryStructures.isEmpty {
                ForEach(Array(secondaryStructures.enumerated()), id: \.offset) { index, structure in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(structure.type.capitalized)")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(structure.color)
                            
                            Spacer()
                            
                            Text("Residues \(structure.start)-\(structure.end)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Confidence: \(Int(structure.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("Length: \(structure.end - structure.start + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(structure.color.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                Text("No secondary structure data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadSecondaryStructure() {
        isLoadingStructure = true
        structureError = nil
        
        Task {
            do {
                // 실제 API 호출 대신 샘플 데이터 사용
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 지연
                
                await MainActor.run {
                    // 샘플 2차 구조 데이터
                    secondaryStructures = [
                        SecondaryStructure(type: "helix", start: 10, end: 25, confidence: 0.95, color: .blue),
                        SecondaryStructure(type: "sheet", start: 30, end: 40, confidence: 0.88, color: .green),
                        SecondaryStructure(type: "turn", start: 45, end: 48, confidence: 0.75, color: .orange),
                        SecondaryStructure(type: "helix", start: 55, end: 70, confidence: 0.92, color: .blue),
                        SecondaryStructure(type: "sheet", start: 75, end: 85, confidence: 0.85, color: .green)
                    ]
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
struct SecondaryStructure {
    let type: String
    let start: Int
    let end: Int
    let confidence: Double
    let color: Color
    
    init(type: String, start: Int, end: Int, confidence: Double, color: Color) {
        self.type = type
        self.start = start
        self.end = end
        self.confidence = confidence
        self.color = color
    }
}
