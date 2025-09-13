import SwiftUI
import Foundation

// MARK: - Protein ViewModel
class ProteinViewModel: ObservableObject {
    @Published var structure: PDBStructure?
    @Published var isLoading = false
    @Published var loadingProgress: String = ""
    @Published var error: String?
    @Published var currentProteinId: String = ""
    @Published var currentProteinName: String = ""
    @Published var is3DStructureLoading = false
    @Published var structureLoadingProgress = ""
    
    // MARK: - Protein Loading Methods
    
    func loadDefaultProtein() {
        isLoading = true
        loadingProgress = "Loading default protein..."
        error = nil
        
        Task {
            do {
                let defaultPdbId = "1CRN"
                print("🔍 Loading default PDB structure: \(defaultPdbId)")
                
                let url = URL(string: "https://files.rcsb.org/download/\(defaultPdbId).pdb")!
                print("📡 Requesting PDB from: \(url)")
                
                await MainActor.run {
                    self.loadingProgress = "Downloading PDB file..."
                }
                
                // 네트워크 요청 타임아웃 설정
                var request = URLRequest(url: url)
                request.timeoutInterval = 30.0
                request.setValue("ProteinApp/1.0", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PDBError.invalidResponse
                }
                
                print("📥 HTTP Response: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 404 {
                        throw PDBError.structureNotFound(defaultPdbId)
                    } else {
                        throw PDBError.serverError(httpResponse.statusCode)
                    }
                }
                
                guard !data.isEmpty else {
                    throw PDBError.emptyResponse
                }
                
                print("📦 Downloaded \(data.count) bytes")
                
                await MainActor.run {
                    self.loadingProgress = "Parsing PDB structure..."
                }
                
                let pdbText = String(decoding: data, as: UTF8.self)
                print("📄 PDB text length: \(pdbText.count) characters")
                
                let loadedStructure = try PDBParser.parse(pdbText: pdbText)
                print("✅ Successfully parsed PDB structure with \(loadedStructure.atomCount) atoms")
                
                // Fetch actual protein name from PDB API
                let actualProteinName = await fetchProteinNameFromPDB(pdbId: defaultPdbId)
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.currentProteinId = defaultPdbId
                    self.currentProteinName = actualProteinName
                    self.isLoading = false
                    self.loadingProgress = ""
                    print("Successfully loaded default PDB structure: \(defaultPdbId) with name: \(actualProteinName)")
                }
            } catch let error as PDBError {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("❌ PDB Error: \(error.localizedDescription)")
            } catch let urlError as URLError {
                await MainActor.run {
                    self.error = urlError.userFriendlyMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("🌐 Network Error: \(urlError.localizedDescription)")
            } catch {
                await MainActor.run {
                    self.error = "Failed to load default protein structure: \(error.localizedDescription)"
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("💥 Unexpected Error: \(error)")
            }
        }
    }
    
    func loadSelectedProtein(_ pdbId: String) {
        isLoading = true
        loadingProgress = "Initializing..."
        error = nil
        
        Task {
            do {
                // PDB ID 유효성 검사
                let formattedPdbId = pdbId.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard formattedPdbId.count == 4 && formattedPdbId.allSatisfy({ $0.isLetter || $0.isNumber }) else {
                    throw PDBError.invalidPDBID(pdbId)
                }
                
                let url = URL(string: "https://files.rcsb.org/download/\(formattedPdbId).pdb")!
                print("🔍 Loading PDB structure for: \(formattedPdbId)")
                print("📡 Requesting PDB from: \(url)")
                
                await MainActor.run {
                    self.loadingProgress = "Downloading PDB file..."
                }
                
                // 네트워크 요청 타임아웃 설정
                var request = URLRequest(url: url)
                request.timeoutInterval = 30.0
                request.setValue("ProteinApp/1.0", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PDBError.invalidResponse
                }
                
                print("📥 HTTP Response: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 404 {
                        throw PDBError.structureNotFound(formattedPdbId)
                    } else {
                        throw PDBError.serverError(httpResponse.statusCode)
                    }
                }
                
                guard !data.isEmpty else {
                    throw PDBError.emptyResponse
                }
                
                print("📦 Downloaded \(data.count) bytes")
                
                await MainActor.run {
                    self.loadingProgress = "Parsing PDB structure..."
                }
                
                let pdbText = String(decoding: data, as: UTF8.self)
                print("📄 PDB text length: \(pdbText.count) characters")
                
                let loadedStructure = try PDBParser.parse(pdbText: pdbText)
                print("✅ Successfully parsed PDB structure with \(loadedStructure.atomCount) atoms")
                
                // Fetch actual protein name from PDB API
                let actualProteinName = await fetchProteinNameFromPDB(pdbId: formattedPdbId)
                
                await MainActor.run {
                    self.structure = loadedStructure
                    self.currentProteinId = formattedPdbId
                    self.currentProteinName = actualProteinName
                    self.isLoading = false
                    self.loadingProgress = ""
                    print("Successfully loaded PDB structure: \(formattedPdbId) with name: \(actualProteinName)")
                }
            } catch let error as PDBError {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("❌ PDB Error: \(error.localizedDescription)")
            } catch let urlError as URLError {
                await MainActor.run {
                    self.error = urlError.userFriendlyMessage
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("🌐 Network Error: \(urlError.localizedDescription)")
            } catch {
                await MainActor.run {
                    self.error = "Failed to load protein structure for \(pdbId): \(error.localizedDescription)"
                    self.isLoading = false
                    self.loadingProgress = ""
                }
                print("💥 Unexpected Error: \(error)")
            }
        }
    }
    
    // MARK: - PDB API Integration
    
    private func fetchProteinNameFromPDB(pdbId: String) async -> String {
        do {
            let name = try await loadProteinNameFromRCSB(pdbId: pdbId)
            return name.isEmpty ? "Protein \(pdbId)" : name
        } catch {
            print("⚠️ Failed to fetch protein name from PDB: \(error.localizedDescription)")
            return "Protein \(pdbId)"
        }
    }
    
    private func loadProteinNameFromRCSB(pdbId: String) async throws -> String {
        let id = pdbId.uppercased()
        guard let url = URL(string: "https://data.rcsb.org/rest/v1/core/entry/\(id)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Parse JSON response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Extract title from struct field
        if let structData = json?["struct"] as? [String: Any],
           let title = structData["title"] as? String,
           !title.isEmpty {
            
            // Clean up the title
            let cleanTitle = title
                .replacingOccurrences(of: "CRYSTAL STRUCTURE OF", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "X-RAY STRUCTURE OF", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "NMR STRUCTURE OF", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanTitle.isEmpty ? "Protein \(pdbId)" : cleanTitle
        }
        
        return "Protein \(pdbId)"
    }
    
    // MARK: - Helper Methods
    
    func getProteinName(from pdbId: String) -> String {
        // Common protein names mapping (fallback for known proteins)
        let proteinNames: [String: String] = [
            "1CRN": "Crambin",
            "1TUB": "Tubulin",
            "1HHO": "Hemoglobin",
            "1INS": "Insulin",
            "1LYZ": "Lysozyme",
            "1GFL": "Green Fluorescent Protein",
            "1UBQ": "Ubiquitin",
            "1PGA": "Protein G",
            "1TIM": "Triosephosphate Isomerase",
            "1AKE": "Adenylate Kinase"
        ]
        
        return proteinNames[pdbId] ?? "Protein \(pdbId)"
    }
}
