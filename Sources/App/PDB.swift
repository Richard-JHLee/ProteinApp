import Foundation
import simd

// Helper function for vector length
private func length(_ vector: SIMD3<Float>) -> Float {
    return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

enum SecondaryStructure: String, CaseIterable {
    case helix = "H"
    case sheet = "S" 
    case coil = "C"
    case unknown = ""
    
    var displayName: String {
        switch self {
        case .helix: return "α-Helix"
        case .sheet: return "β-Sheet"
        case .coil: return "Coil"
        case .unknown: return "Unknown"
        }
    }
}

struct Atom: Identifiable, Hashable {
    let id: Int
    let element: String
    let name: String
    let chain: String
    let residueName: String
    let residueNumber: Int
    let position: SIMD3<Float>
    let secondaryStructure: SecondaryStructure
    let isBackbone: Bool
    let isLigand: Bool
    let isPocket: Bool
    let occupancy: Float
    let temperatureFactor: Float
    
    // 색상 결정을 위한 computed property
    var atomicColor: (red: Float, green: Float, blue: Float) {
        switch element.uppercased() {
        case "C": return (0.2, 0.2, 0.2)   // 진한 회색
        case "N": return (0.2, 0.2, 1.0)   // 파란색
        case "O": return (1.0, 0.2, 0.2)   // 빨간색
        case "S": return (1.0, 1.0, 0.2)   // 노란색
        case "P": return (1.0, 0.5, 0.0)   // 주황색
        case "H": return (1.0, 1.0, 1.0)   // 흰색
        default: return (0.8, 0.0, 0.8)    // 보라색
        }
    }
}

struct Bond: Hashable {
    let atomA: Int
    let atomB: Int
    let order: BondOrder
    let distance: Float
}

enum BondOrder: Int, CaseIterable {
    case single = 1
    case double = 2
    case triple = 3
    case aromatic = 4
}

struct Annotation {
    let type: AnnotationType
    let value: String
    let description: String
}

enum AnnotationType: String, CaseIterable {
    case resolution = "Resolution"
    case molecularWeight = "Molecular Weight"
    case experimentalMethod = "Experimental Method"
    case organism = "Organism"
    case function = "Function"
    case depositionDate = "Deposition Date"
    case spaceGroup = "Space Group"
    
    var displayName: String {
        return rawValue
    }
}

struct PDBStructure {
    let atoms: [Atom]
    let bonds: [Bond]
    let annotations: [Annotation]
    let boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)
    let centerOfMass: SIMD3<Float>
    
    // 통계 정보
    var atomCount: Int { atoms.count }
    var residueCount: Int { Set(atoms.map { "\($0.chain)_\($0.residueNumber)" }).count }
    var chainCount: Int { Set(atoms.map { $0.chain }).count }
}

enum PDBParseError: Error, LocalizedError {
    case invalidFormat(String)
    case noValidAtoms
    case corruptedData(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let msg): return "Invalid PDB format: \(msg)"
        case .noValidAtoms: return "No valid atoms found in PDB data"
        case .corruptedData(let msg): return "Corrupted data: \(msg)"
        }
    }
}

enum PDBError: Error, LocalizedError {
    case invalidPDBID(String)
    case structureNotFound(String)
    case serverError(Int)
    case invalidResponse
    case emptyResponse
    case networkUnavailable
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidPDBID(let id): return "Invalid PDB ID: \(id)"
        case .structureNotFound(let id): return "Structure not found: \(id)"
        case .serverError(let code): return "Server error: \(code)"
        case .invalidResponse: return "Invalid response from server"
        case .emptyResponse: return "Empty response from server"
        case .networkUnavailable: return "Network unavailable"
        case .timeout: return "Request timeout"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidPDBID(let id):
            return "Invalid protein ID '\(id)'. Please check the ID and try again."
        case .structureNotFound(let id):
            return "Protein structure '\(id)' not found in the database. Please try a different protein."
        case .serverError(let code):
            return "Server error (\(code)). Please check your internet connection and try again."
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .emptyResponse:
            return "No data received from server. Please try again."
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        }
    }
}

final class PDBParser {
    
    // 표준 아미노산 잔기들
    private static let standardResidues: Set<String> = [
        "ALA", "ARG", "ASN", "ASP", "CYS", "GLN", "GLU", "GLY", "HIS", "ILE", 
        "LEU", "LYS", "MET", "PHE", "PRO", "SER", "THR", "TRP", "TYR", "VAL"
    ]
    
    // 백본 원자들
    private static let backboneAtoms: Set<String> = ["CA", "C", "N", "O", "P", "O5'", "C5'", "C4'", "C3'", "O3'"]
    
    static func parse(pdbText: String) throws -> PDBStructure {
        guard !pdbText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PDBParseError.invalidFormat("Empty PDB content")
        }
        
        var atoms: [Atom] = []
        var secondaryStructureMap: [String: SecondaryStructure] = [:]
        var annotations: [Annotation] = []
        
        let lines = pdbText.split(whereSeparator: { $0.isNewline })
        atoms.reserveCapacity(min(lines.count, 10000)) // 메모리 사전 할당
        
        // Parse header information and annotations
        parseHeaderInformation(lines: lines, annotations: &annotations)
        
        // First pass: Parse secondary structure information
        parseSecondaryStructure(lines: lines, secondaryStructureMap: &secondaryStructureMap)
        
        // Second pass: Parse atoms with better error handling
        try parseAtoms(lines: lines, secondaryStructureMap: secondaryStructureMap, atoms: &atoms)
        
        guard !atoms.isEmpty else {
            throw PDBParseError.noValidAtoms
        }
        
        // Generate bonds more efficiently
        let bonds = generateBonds(for: atoms)
        
        // Calculate structure properties
        let boundingBox = calculateBoundingBox(atoms: atoms)
        let centerOfMass = calculateCenterOfMass(atoms: atoms)
        
        // Add calculated annotations if not present
        addCalculatedAnnotations(atoms: atoms, annotations: &annotations)
        
        return PDBStructure(
            atoms: atoms,
            bonds: bonds,
            annotations: annotations,
            boundingBox: boundingBox,
            centerOfMass: centerOfMass
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func parseHeaderInformation(lines: [Substring], annotations: inout [Annotation]) {
        for line in lines {
            let lineStr = String(line)
            
            if line.hasPrefix("HEADER") && line.count >= 50 {
                let classification = safeSubstring(lineStr, 10, 50).trimmingCharacters(in: .whitespaces)
                let depositDate = safeSubstring(lineStr, 50, 59).trimmingCharacters(in: .whitespaces)
                
                if !classification.isEmpty {
                    annotations.append(Annotation(type: .function, value: classification, description: "Protein classification"))
                }
                if !depositDate.isEmpty {
                    annotations.append(Annotation(type: .depositionDate, value: depositDate, description: "Structure deposition date"))
                }
            }
            else if line.hasPrefix("REMARK   2 RESOLUTION") {
                let resolutionStr = safeSubstring(lineStr, 23, 30).trimmingCharacters(in: .whitespaces)
                if !resolutionStr.isEmpty {
                    annotations.append(Annotation(type: .resolution, value: "\(resolutionStr) Å", description: "X-ray diffraction resolution"))
                }
            }
            else if line.hasPrefix("EXPDTA") {
                let method = safeSubstring(lineStr, 10, 70).trimmingCharacters(in: .whitespaces)
                if !method.isEmpty {
                    annotations.append(Annotation(type: .experimentalMethod, value: method, description: "Structure determination method"))
                }
            }
        }
    }
    
    private static func parseSecondaryStructure(lines: [Substring], secondaryStructureMap: inout [String: SecondaryStructure]) {
        for line in lines {
            let lineStr = String(line)
            
            if line.hasPrefix("HELIX") && line.count >= 37 {
                parseHelixRecord(lineStr, secondaryStructureMap: &secondaryStructureMap)
            }
            else if line.hasPrefix("SHEET") && line.count >= 37 {
                parseSheetRecord(lineStr, secondaryStructureMap: &secondaryStructureMap)
            }
        }
    }
    
    private static func parseHelixRecord(_ line: String, secondaryStructureMap: inout [String: SecondaryStructure]) {
        let chain = safeSubstring(line, 19, 20).trimmingCharacters(in: .whitespaces)
        let startResStr = safeSubstring(line, 21, 25).trimmingCharacters(in: .whitespaces)
        let endResStr = safeSubstring(line, 33, 37).trimmingCharacters(in: .whitespaces)
        
        guard let startRes = Int(startResStr), let endRes = Int(endResStr) else { return }
        
        for resNum in startRes...endRes {
            secondaryStructureMap["\(chain)_\(resNum)"] = .helix
        }
    }
    
    private static func parseSheetRecord(_ line: String, secondaryStructureMap: inout [String: SecondaryStructure]) {
        let chain = safeSubstring(line, 21, 22).trimmingCharacters(in: .whitespaces)
        let startResStr = safeSubstring(line, 22, 26).trimmingCharacters(in: .whitespaces)
        let endResStr = safeSubstring(line, 33, 37).trimmingCharacters(in: .whitespaces)
        
        guard let startRes = Int(startResStr), let endRes = Int(endResStr) else { return }
        
        for resNum in startRes...endRes {
            secondaryStructureMap["\(chain)_\(resNum)"] = .sheet
        }
    }
    
    private static func parseAtoms(lines: [Substring], secondaryStructureMap: [String: SecondaryStructure], atoms: inout [Atom]) throws {
        var atomIndex = 0
        
        for line in lines {
            guard line.hasPrefix("ATOM") || line.hasPrefix("HETATM") else { continue }
            
            let lineStr = String(line)
            guard lineStr.count >= 54 else { continue } // 최소 좌표까지는 있어야 함
            
            // Parse atom information with safer extraction
            let atomName = safeSubstring(lineStr, 12, 16).trimmingCharacters(in: .whitespaces)
            let residueName = safeSubstring(lineStr, 17, 20).trimmingCharacters(in: .whitespaces)
            let chain = safeSubstring(lineStr, 21, 22).trimmingCharacters(in: .whitespaces)
            let residueNumberStr = safeSubstring(lineStr, 22, 26).trimmingCharacters(in: .whitespaces)
            
            // Parse coordinates with validation
            let xStr = safeSubstring(lineStr, 30, 38).trimmingCharacters(in: .whitespaces)
            let yStr = safeSubstring(lineStr, 38, 46).trimmingCharacters(in: .whitespaces)
            let zStr = safeSubstring(lineStr, 46, 54).trimmingCharacters(in: .whitespaces)
            
            guard let residueNumber = Int(residueNumberStr),
                  let x = Float(xStr), x.isFinite,
                  let y = Float(yStr), y.isFinite,
                  let z = Float(zStr), z.isFinite else {
                continue // Skip invalid atoms
            }
            
            // Parse optional fields
            let occupancy = Float(safeSubstring(lineStr, 54, 60).trimmingCharacters(in: .whitespaces)) ?? 1.0
            let tempFactor = Float(safeSubstring(lineStr, 60, 66).trimmingCharacters(in: .whitespaces)) ?? 0.0
            var element = safeSubstring(lineStr, 76, 78).trimmingCharacters(in: .whitespaces)
            
            // Guess element from atom name if not provided
            if element.isEmpty {
                element = guessElement(from: atomName)
            }
            
            // Determine atom properties
            let isBackbone = backboneAtoms.contains(atomName)
            let isLigand = line.hasPrefix("HETATM") || !standardResidues.contains(residueName)
            let isPocket = !isBackbone && !isLigand
            
            // Get secondary structure
            let structureKey = "\(chain)_\(residueNumber)"
            let secondaryStructure = secondaryStructureMap[structureKey] ?? (isLigand ? .unknown : .coil)
            
            let atom = Atom(
                id: atomIndex,
                element: element.capitalized,
                name: atomName,
                chain: chain.isEmpty ? "A" : chain, // Default chain
                residueName: residueName,
                residueNumber: residueNumber,
                position: SIMD3<Float>(x, y, z),
                secondaryStructure: secondaryStructure,
                isBackbone: isBackbone,
                isLigand: isLigand,
                isPocket: isPocket,
                occupancy: occupancy,
                temperatureFactor: tempFactor
            )
            
            atoms.append(atom)
            atomIndex += 1
        }
    }
    
    private static func generateBonds(for atoms: [Atom]) -> [Bond] {
        guard atoms.count > 1 else { return [] }
        
        var bonds: [Bond] = []
        bonds.reserveCapacity(atoms.count * 2) // 보통 원자당 2-3개 본드
        
        // Spatial hashing for efficient neighbor finding
        let spatialHash = buildSpatialHash(atoms: atoms)
        
        for (i, atom) in atoms.enumerated() {
            let nearbyAtoms = findNearbyAtoms(atom: atom, spatialHash: spatialHash, atoms: atoms)
            
            for j in nearbyAtoms where j > i { // j > i to avoid duplicates
                let distance = length(atom.position - atoms[j].position)
                
                // Skip too close atoms (likely overlapping)
                guard distance > 0.4 else { continue }
                
                let bondCutoff = (covalentRadius(for: atom.element) + covalentRadius(for: atoms[j].element)) * 1.3
                
                if distance <= bondCutoff {
                    bonds.append(Bond(atomA: i, atomB: j, order: .single, distance: distance))
                }
            }
        }
        
        return bonds
    }
    
    // Spatial hashing for O(n) bond generation instead of O(n²)
    private static func buildSpatialHash(atoms: [Atom]) -> [SIMD3<Int>: [Int]] {
        var spatialHash: [SIMD3<Int>: [Int]] = [:]
        let cellSize: Float = 3.0 // 3Å cells
        
        for (index, atom) in atoms.enumerated() {
            let cell = SIMD3<Int>(
                Int(atom.position.x / cellSize),
                Int(atom.position.y / cellSize),
                Int(atom.position.z / cellSize)
            )
            spatialHash[cell, default: []].append(index)
        }
        
        return spatialHash
    }
    
    private static func findNearbyAtoms(atom: Atom, spatialHash: [SIMD3<Int>: [Int]], atoms: [Atom]) -> [Int] {
        let cellSize: Float = 3.0
        let cell = SIMD3<Int>(
            Int(atom.position.x / cellSize),
            Int(atom.position.y / cellSize),
            Int(atom.position.z / cellSize)
        )
        
        var nearbyAtoms: [Int] = []
        
        // Check surrounding cells
        for dx in -1...1 {
            for dy in -1...1 {
                for dz in -1...1 {
                    let neighborCell = cell &+ SIMD3<Int>(dx, dy, dz)
                    if let atomsInCell = spatialHash[neighborCell] {
                        nearbyAtoms.append(contentsOf: atomsInCell)
                    }
                }
            }
        }
        
        return nearbyAtoms
    }
    
    private static func calculateBoundingBox(atoms: [Atom]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard let firstAtom = atoms.first else {
            return (min: SIMD3<Float>(0, 0, 0), max: SIMD3<Float>(0, 0, 0))
        }
        
        var min = firstAtom.position
        var max = firstAtom.position
        
        for atom in atoms.dropFirst() {
            min = simd_min(min, atom.position)
            max = simd_max(max, atom.position)
        }
        
        return (min: min, max: max)
    }
    
    private static func calculateCenterOfMass(atoms: [Atom]) -> SIMD3<Float> {
        guard !atoms.isEmpty else { return SIMD3<Float>(0, 0, 0) }
        
        let sum = atoms.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1.position }
        return sum / Float(atoms.count)
    }
    
    private static func addCalculatedAnnotations(atoms: [Atom], annotations: inout [Annotation]) {
        // Add molecular weight if not present
        if !annotations.contains(where: { $0.type == .molecularWeight }) {
            let estimatedWeight = atoms.reduce(0.0) { sum, atom in
                sum + atomicWeight(for: atom.element)
            }
            annotations.append(Annotation(
                type: .molecularWeight,
                value: String(format: "%.0f Da", estimatedWeight),
                description: "Calculated molecular weight"
            ))
        }
        
        // Add default values for missing annotations
        let defaultAnnotations: [(AnnotationType, String, String)] = [
            (.resolution, "Unknown", "Resolution not specified"),
            (.experimentalMethod, "Unknown", "Method not specified"),
            (.organism, "Unknown", "Source organism not specified")
        ]
        
        for (type, value, description) in defaultAnnotations {
            if !annotations.contains(where: { $0.type == type }) {
                annotations.append(Annotation(type: type, value: value, description: description))
            }
        }
    }
    
    // MARK: - Utility Functions
    
    private static func safeSubstring(_ string: String, _ start: Int, _ end: Int) -> String {
        let startIndex = string.index(string.startIndex, offsetBy: min(max(0, start), string.count))
        let endIndex = string.index(string.startIndex, offsetBy: min(max(start, end), string.count))
        return String(string[startIndex..<endIndex])
    }
    
    private static func guessElement(from atomName: String) -> String {
        let cleaned = atomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = cleaned.filter { $0.isLetter }
        
        if letters.count >= 2 {
            let twoChar = String(letters.prefix(2))
            // Common two-letter elements
            if ["CA", "MG", "FE", "ZN", "CU", "MN", "NI", "CO"].contains(twoChar.uppercased()) {
                return twoChar
            }
        }
        
        return letters.isEmpty ? "C" : String(letters.prefix(1))
    }
    
    private static func covalentRadius(for element: String) -> Float {
        switch element.uppercased() {
        case "H": return 0.31
        case "C": return 0.76
        case "N": return 0.71
        case "O": return 0.66
        case "S": return 1.05
        case "P": return 1.07
        case "CA": return 1.74
        case "MG": return 1.30
        case "FE": return 1.25
        case "ZN": return 1.22
        case "CU": return 1.28
        case "MN": return 1.39
        default: return 0.85
        }
    }
    
    private static func atomicWeight(for element: String) -> Float {
        switch element.uppercased() {
        case "H": return 1.008
        case "C": return 12.01
        case "N": return 14.01
        case "O": return 16.00
        case "S": return 32.07
        case "P": return 30.97
        case "CA": return 40.08
        case "MG": return 24.31
        case "FE": return 55.85
        case "ZN": return 65.38
        case "CU": return 63.55
        case "MN": return 54.94
        default: return 14.0 // Average approximation
        }
    }
}