import SwiftUI

struct PrimaryStructureView: View {
    let protein: ProteinInfo
    @State private var aminoAcidSequences: [String] = []
    @State private var isLoadingSequence = false
    @State private var sequenceError: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingSequence {
                        aminoAcidLoadingView
                    } else if let error = sequenceError {
                        aminoAcidErrorView(error)
                    } else {
                        aminoAcidContentView
                    }
                }
                .padding()
            }
            .navigationTitle("Primary Structure")
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
            loadAminoAcidSequence()
        }
    }
    
    // MARK: - Loading View
    private var aminoAcidLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(LanguageHelper.localizedText(
                korean: "아미노산 서열 로딩 중...",
                english: "Loading amino acid sequence..."
            ))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func aminoAcidErrorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(LanguageHelper.localizedText(
                korean: "서열 로드 실패",
                english: "Failed to load sequence"
            ))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(LanguageHelper.localizedText(
                korean: "다시 시도",
                english: "Retry"
            )) {
                loadAminoAcidSequence()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Content View
    private var aminoAcidContentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("Amino Acid Sequence")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("PDB ID: \(protein.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !aminoAcidSequences.isEmpty {
                    Text("\(aminoAcidSequences.count) chain(s) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 아미노산 서열 표시
            if !aminoAcidSequences.isEmpty {
                ForEach(Array(aminoAcidSequences.enumerated()), id: \.offset) { index, sequence in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Chain \(String(UnicodeScalar(65 + index)!))")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(protein.category.color)
                            
                            Spacer()
                            
                            Text("\(sequence.count) residues")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(sequence)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            } else {
                Text("No amino acid sequence available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadAminoAcidSequence() {
        isLoadingSequence = true
        sequenceError = nil
        
        Task {
            do {
                // 실제 API 호출 대신 샘플 데이터 사용
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 지연
                
                await MainActor.run {
                    // 샘플 아미노산 서열 데이터
                    aminoAcidSequences = [
                        "MKLLILTCLVAVALARPKHPIKHQGLPQEVLNENLLRFFVAPFPEVFGKEKVNEL",
                        "MKLLILTCLVAVALARPKHPIKHQGLPQEVLNENLLRFFVAPFPEVFGKEKVNEL",
                        "MKLLILTCLVAVALARPKHPIKHQGLPQEVLNENLLRFFVAPFPEVFGKEKVNEL"
                    ]
                    isLoadingSequence = false
                }
            } catch {
                await MainActor.run {
                    sequenceError = error.localizedDescription
                    isLoadingSequence = false
                }
            }
        }
    }
}
