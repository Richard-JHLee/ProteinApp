import SwiftUI

struct ProteinStructurePreview: View {
    let proteinId: String
    @State private var structure: PDBStructure?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        Group {
            if isLoading {
                // 로딩 중일 때는 진행 상황 표시
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if error != nil {
                // 에러 시 에러 정보 표시
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("Error")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            } else if let structure = structure {
                // 2D 단백질 구조 다이어그램 (테스트 버전)
                VStack(spacing: 4) {
                    Text("✅ Loaded")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Text("\(structure.atoms.count) atoms")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    
                    Text("Chains: \(structure.atoms.map { $0.chain }.uniqued().sorted().joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                // 데이터 없을 때 기본 아이콘 표시
                Image(systemName: "cube.box")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadStructure()
        }
    }
    
    private func loadStructure() {
        Task {
            do {
                print("🔄 Loading structure for \(proteinId)...")
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

// MARK: - 2D Protein Structure Diagram (Lightweight)
struct ProteinStructure2D: View {
    let structure: PDBStructure
    
    var body: some View {
        ZStack {
            // 배경
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
            
            // 디버깅 정보 추가
            VStack(spacing: 4) {
                // 체인 정보
                let chains = structure.atoms.map { $0.chain }.uniqued().sorted()
                Text("Chains: \(chains.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.primary)
                
                // 체인별 색상 표시
                HStack(spacing: 4) {
                    ForEach(chains, id: \.self) { chain in
                        HStack(spacing: 2) {
                            Circle()
                                .fill(chainColor(for: chain))
                                .frame(width: 8, height: 8)
                            
                            Text(chain)
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // 원자 수
                Text("\(structure.atoms.count) atoms")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(4)
        }
        .onAppear {
            print("🔍 ProteinStructure2D appeared with \(structure.atoms.count) atoms")
            print("🔍 Chains found: \(structure.atoms.map { $0.chain }.uniqued().sorted())")
        }
    }
    
    private func chainColor(for chain: String) -> Color {
        switch chain {
        case "A": return .blue
        case "B": return .green
        case "C": return .orange
        case "D": return .red
        case "E": return .purple
        case "F": return .pink
        case "G": return .cyan
        case "H": return .mint
        default: return .gray
        }
    }
}

// MARK: - Helper Functions
private func loadStructureFromRCSB(pdbId: String) async throws -> PDBStructure {
    let url = URL(string: "https://files.rcsb.org/download/\(pdbId.uppercased()).pdb")!
    
    print("🌐 Fetching PDB file from: \(url)")
    
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // HTTP 응답 상태 확인
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
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

// MARK: - Extensions
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
