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
    let isLigand: Bool
    let isPocket: Bool
}

struct Bond: Hashable {
    let a: Int
    let b: Int
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
}

struct PDBStructure {
    let atoms: [Atom]
    let bonds: [Bond]
    let annotations: [Annotation]
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
            let xStr = substr(s, 30..<38).trimmingCharacters(in: .whitespaces)
            let yStr = substr(s, 38..<46).trimmingCharacters(in: .whitespaces)
            let zStr = substr(s, 46..<54).trimmingCharacters(in: .whitespaces)
            
            guard let x = Float(xStr), x.isFinite,
                  let y = Float(yStr), y.isFinite,
                  let z = Float(zStr), z.isFinite else {
                print("Warning: Invalid coordinates for atom: x=\(xStr), y=\(yStr), z=\(zStr)")
                continue
            }
            var element = substr(s, 76..<78).trimmingCharacters(in: .whitespaces)
            
            if element.isEmpty {
                // guess from name
                let letters = name.filter { $0.isLetter }
                element = String(letters.prefix(2)).trimmingCharacters(in: .whitespaces)
            }
            
            // Determine if backbone atom
            let isBackbone = ["CA", "C", "N", "O"].contains(name)
            
            // Determine if ligand (HETATM records or non-standard residues)
            let isLigand = line.hasPrefix("HETATM") || !["ALA", "ARG", "ASN", "ASP", "CYS", "GLN", "GLU", "GLY", "HIS", "ILE", "LEU", "LYS", "MET", "PHE", "PRO", "SER", "THR", "TRP", "TYR", "VAL"].contains(resName)
            
            // Determine if pocket (surface atoms, simplified logic)
            let isPocket = !isBackbone && !isLigand
            
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
                isBackbone: isBackbone,
                isLigand: isLigand,
                isPocket: isPocket
            ))
            idx += 1
        }
        
        let bonds = naiveBonds(for: atoms)
        
        // Create basic annotations
        let annotations = [
            Annotation(type: .resolution, value: "2.0 Å", description: "Estimated resolution"),
            Annotation(type: .molecularWeight, value: "\(atoms.count * 14) Da", description: "Approximate molecular weight"),
            Annotation(type: .experimentalMethod, value: "X-ray", description: "Structure determination method"),
            Annotation(type: .organism, value: "Unknown", description: "Source organism"),
            Annotation(type: .function, value: "Structural protein", description: "Protein function")
        ]
        
        // 최소한 하나의 원자가 있어야 함
        guard !atoms.isEmpty else {
            print("Error: No valid atoms found in PDB data")
            // 기본 구조 반환
            return PDBStructure(
                atoms: [],
                bonds: [],
                annotations: [
                    Annotation(type: .resolution, value: "N/A", description: "No structure data"),
                    Annotation(type: .molecularWeight, value: "0 Da", description: "No atoms"),
                    Annotation(type: .experimentalMethod, value: "N/A", description: "No data"),
                    Annotation(type: .organism, value: "N/A", description: "No data"),
                    Annotation(type: .function, value: "N/A", description: "No data")
                ]
            )
        }
        
        return PDBStructure(atoms: atoms, bonds: bonds, annotations: annotations)
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