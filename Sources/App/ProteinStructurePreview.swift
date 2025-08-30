import SwiftUI
import SceneKit

// MARK: - Simplified Protein Structure Preview
struct ProteinStructurePreview: View {
    let proteinId: String
    @State private var structure: PDBStructure?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if error != nil {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            } else if let structure = structure {
                // ProteinSceneView를 직접 임베드하여 일관된 렌더링 제공
                ProteinSceneView(
                    structure: structure,
                    style: .spheres, // 기본 스타일
                    colorMode: .secondaryStructure, // 2차 구조별 색상
                    uniformColor: UIColor.systemBlue,
                    autoRotate: false, // 카드에서는 자동 회전 비활성화
                    showInfoBar: .constant(false), // 카드에서는 정보 바 숨김
                    onSelectAtom: { _ in } // 카드에서는 원자 선택 비활성화
                )
                .frame(width: 120, height: 120) // 크기를 2배로 증가
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .background(Color(.systemGray6)) // 배경색 추가로 렌더링 영역 명확화
            } else {
                Image(systemName: "cube.box.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadStructure()
        }
    }
    
    // MARK: - 단순화된 구조 로딩
    private func loadStructure() {
        Task {
            do {
                print("🔄 Loading structure for \(proteinId)...")
                
                guard isValidPDBId(proteinId) else {
                    throw NSError(domain: "PDBError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid PDB ID: \(proteinId)"])
                }
                
                let loadedStructure = try await loadStructureFromRCSB(pdbId: proteinId)
                print("✅ Successfully loaded structure for \(proteinId): \(loadedStructure.atoms.count) atoms")
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.isLoading = false
                    self.error = nil
                }
                
            } catch {
                print("❌ Failed to load structure for \(proteinId): \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    self.structure = nil
                }
            }
        }
    }
}

// MARK: - Helper Functions
private func isValidPDBId(_ pdbId: String) -> Bool {
    let pattern = "^[0-9][A-Z0-9]{3}$"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: pdbId.utf16.count)
    return regex.firstMatch(in: pdbId, options: [], range: range) != nil
}

private func loadStructureFromRCSB(pdbId: String) async throws -> PDBStructure {
    let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
    
    print("🌐 Fetching PDB file from: \(url)")
    
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 404 {
                throw NSError(domain: "PDBError", code: 404, userInfo: [NSLocalizedDescriptionKey: "PDB ID '\(pdbId)' not found"])
            } else if httpResponse.statusCode != 200 {
                throw NSError(domain: "PDBError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): Failed to download PDB file"])
            }
        }
        
        print("📦 Downloaded \(data.count) bytes")
        
        guard let pdbString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "PDBError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode PDB data as UTF-8"])
        }
        
        print("📝 PDB content length: \(pdbString.count) characters")
        
        let structure = PDBParser.parse(pdbText: pdbString)
        print("🔬 Parsed structure: \(structure.atoms.count) atoms, \(structure.bonds.count) bonds")
        
        return structure
        
    } catch let urlError as URLError {
        print("🌐 Network error: \(urlError.localizedDescription)")
        throw NSError(domain: "PDBError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Network error: \(urlError.localizedDescription)"])
    } catch {
        print("❌ Unexpected error: \(error.localizedDescription)")
        throw error
    }
}
