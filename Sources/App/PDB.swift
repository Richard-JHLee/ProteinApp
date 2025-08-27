import Foundation
import simd

// Helper function for vector length
private func length(_ vector: SIMD3<Float>) -> Float {
    return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

enum SecondaryStructure: String {
    case helix = "H"
    case sheet = "S" 
    case coil = "C"
    case unknown = ""
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
}

struct Bond: Hashable {
    let a: Int
    let b: Int
}

struct PDBStructure {
    let atoms: [Atom]
    let bonds: [Bond]
}

final class PDBParser {
    static func parse(pdbText: String) -> PDBStructure {
        var atoms: [Atom] = []
        var secondaryStructureMap: [String: SecondaryStructure] = [:]
        let lines = pdbText.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
        atoms.reserveCapacity(1024)
        
        // First pass: Parse secondary structure information
        for line in lines {
            if line.hasPrefix("HELIX ") {
                // Parse HELIX records for alpha helices
                let chain = String(line[line.index(line.startIndex, offsetBy: 19)])
                let startRes = Int(String(line[line.index(line.startIndex, offsetBy: 21)..<line.index(line.startIndex, offsetBy: 25)]).trimmingCharacters(in: .whitespaces)) ?? 0
                let endRes = Int(String(line[line.index(line.startIndex, offsetBy: 33)..<line.index(line.startIndex, offsetBy: 37)]).trimmingCharacters(in: .whitespaces)) ?? 0
                
                for resNum in startRes...endRes {
                    let key = "\(chain)_\(resNum)"
                    secondaryStructureMap[key] = .helix
                }
            } else if line.hasPrefix("SHEET ") {
                // Parse SHEET records for beta sheets
                let chain = String(line[line.index(line.startIndex, offsetBy: 21)])
                let startRes = Int(String(line[line.index(line.startIndex, offsetBy: 22)..<line.index(line.startIndex, offsetBy: 26)]).trimmingCharacters(in: .whitespaces)) ?? 0
                let endRes = Int(String(line[line.index(line.startIndex, offsetBy: 33)..<line.index(line.startIndex, offsetBy: 37)]).trimmingCharacters(in: .whitespaces)) ?? 0
                
                for resNum in startRes...endRes {
                    let key = "\(chain)_\(resNum)"
                    secondaryStructureMap[key] = .sheet
                }
            }
        }
        
        // Second pass: Parse atoms
        var idx = 0
        for line in lines {
            guard line.hasPrefix("ATOM ") || line.hasPrefix("HETATM") else { continue }
            
            // PDB fixed columns
            // atom serial: cols 7-11, atom name: 13-16, altLoc: 17, resName: 18-20, chainID: 22, resSeq: 23-26
            // x: 31-38, y: 39-46, z: 47-54, element: 77-78
            func substr(_ s: Substring, _ r: Range<Int>) -> String {
                let start = s.index(s.startIndex, offsetBy: max(0, r.lowerBound), limitedBy: s.endIndex) ?? s.endIndex
                let end = s.index(s.startIndex, offsetBy: min(s.count, r.upperBound), limitedBy: s.endIndex) ?? s.endIndex
                return String(s[start..<end])
            }
            
            let s = line
            let name = substr(s, 12..<16).trimmingCharacters(in: .whitespaces)
            let resName = substr(s, 17..<20).trimmingCharacters(in: .whitespaces)
            let chain = substr(s, 21..<22).trimmingCharacters(in: .whitespaces)
            let resSeq = Int(substr(s, 22..<26).trimmingCharacters(in: .whitespaces)) ?? 0
            let x = Float(substr(s, 30..<38).trimmingCharacters(in: .whitespaces)) ?? 0
            let y = Float(substr(s, 38..<46).trimmingCharacters(in: .whitespaces)) ?? 0
            let z = Float(substr(s, 46..<54).trimmingCharacters(in: .whitespaces)) ?? 0
            var element = substr(s, 76..<78).trimmingCharacters(in: .whitespaces)
            
            if element.isEmpty {
                // guess from name
                let letters = name.filter { $0.isLetter }
                element = String(letters.prefix(2)).trimmingCharacters(in: .whitespaces)
            }
            
            // Determine if backbone atom
            let isBackbone = ["CA", "C", "N", "O"].contains(name)
            
            // Get secondary structure from map
            let key = "\(chain)_\(resSeq)"
            let ss = secondaryStructureMap[key] ?? .unknown
            
            atoms.append(Atom(
                id: idx, 
                element: element.capitalized, 
                name: name, 
                chain: chain, 
                residueName: resName, 
                residueNumber: resSeq, 
                position: SIMD3<Float>(x, y, z),
                secondaryStructure: ss,
                isBackbone: isBackbone
            ))
            idx += 1
        }
        
        let bonds = naiveBonds(for: atoms)
        return PDBStructure(atoms: atoms, bonds: bonds)
    }

    private static func naiveBonds(for atoms: [Atom]) -> [Bond] {
        // Distance-based bonding using covalent radii, limited neighbors
        let maxNeighbors = 4
        var bonds: [Bond] = []
        var neighborCounts = Array(repeating: 0, count: atoms.count)
        for i in 0..<atoms.count {
            for j in (i+1)..<atoms.count {
                if neighborCounts[i] >= maxNeighbors || neighborCounts[j] >= maxNeighbors { continue }
                let pi = atoms[i].position
                let pj = atoms[j].position
                let d = length(pi - pj)
                if d < 0.4 { continue }
                let cutoff = (covalentRadius(for: atoms[i].element) + covalentRadius(for: atoms[j].element)) * 1.2
                if d <= cutoff {
                    bonds.append(Bond(a: i, b: j))
                    neighborCounts[i] += 1
                    neighborCounts[j] += 1
                }
            }
        }
        return bonds
    }

    private static func covalentRadius(for element: String) -> Float {
        switch element.uppercased() {
        case "H": return 0.31
        case "C": return 0.76
        case "N": return 0.71
        case "O": return 0.66
        case "S": return 1.05
        case "P": return 1.07
        default: return 0.85
        }
    }
} 