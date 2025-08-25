import Foundation
import simd

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
        let lines = pdbText.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
        atoms.reserveCapacity(1024)
        var idx = 0
        
        // First pass: extract secondary structure information from HELIX and SHEET records
        var helixRegions: [(chainID: String, startRes: Int, endRes: Int)] = []
        var sheetRegions: [(chainID: String, startRes: Int, endRes: Int)] = []
        
        for line in lines {
            if line.hasPrefix("HELIX ") {
                // HELIX record: chainID at col 20, startRes at cols 22-25, endRes at cols 34-37
                func substr(_ s: Substring, _ r: Range<Int>) -> String {
                    let start = s.index(s.startIndex, offsetBy: max(0, r.lowerBound), limitedBy: s.endIndex) ?? s.endIndex
                    let end = s.index(s.startIndex, offsetBy: min(s.count, r.upperBound), limitedBy: s.endIndex) ?? s.endIndex
                    return String(s[start..<end])
                }
                
                let chainID = substr(line, 19..<20).trimmingCharacters(in: .whitespaces)
                let startRes = Int(substr(line, 21..<25).trimmingCharacters(in: .whitespaces)) ?? 0
                let endRes = Int(substr(line, 33..<37).trimmingCharacters(in: .whitespaces)) ?? 0
                
                if chainID.isEmpty == false && startRes > 0 && endRes > 0 {
                    helixRegions.append((chainID, startRes, endRes))
                }
            } else if line.hasPrefix("SHEET ") {
                // SHEET record: chainID at col 22, startRes at cols 23-26, endRes at cols 34-37
                func substr(_ s: Substring, _ r: Range<Int>) -> String {
                    let start = s.index(s.startIndex, offsetBy: max(0, r.lowerBound), limitedBy: s.endIndex) ?? s.endIndex
                    let end = s.index(s.startIndex, offsetBy: min(s.count, r.upperBound), limitedBy: s.endIndex) ?? s.endIndex
                    return String(s[start..<end])
                }
                
                let chainID = substr(line, 21..<22).trimmingCharacters(in: .whitespaces)
                let startRes = Int(substr(line, 22..<26).trimmingCharacters(in: .whitespaces)) ?? 0
                let endRes = Int(substr(line, 33..<37).trimmingCharacters(in: .whitespaces)) ?? 0
                
                if chainID.isEmpty == false && startRes > 0 && endRes > 0 {
                    sheetRegions.append((chainID, startRes, endRes))
                }
            }
        }
        
        // Second pass: extract atoms and assign secondary structure
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
            
            // Assign secondary structure based on HELIX and SHEET records
            var ss: SecondaryStructure = .coil // Default to coil/loop instead of unknown
            
            // Check if this residue is part of a helix
            for region in helixRegions {
                if region.chainID == chain && resSeq >= region.startRes && resSeq <= region.endRes {
                    ss = .helix
                    break
                }
            }
            
            // Check if this residue is part of a sheet (only if not already assigned as helix)
            if ss == .coil {
                for region in sheetRegions {
                    if region.chainID == chain && resSeq >= region.startRes && resSeq <= region.endRes {
                        ss = .sheet
                        break
                    }
                }
            }
            
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
        
        // If no helix/sheet records found, use heuristic approach based on residue names and patterns
        if helixRegions.isEmpty && sheetRegions.isEmpty {
            assignSecondaryStructureHeuristically(&atoms)
        }
        
        let bonds = naiveBonds(for: atoms)
        return PDBStructure(atoms: atoms, bonds: bonds)
    }
    
    // Heuristic method to assign secondary structure when HELIX/SHEET records are not available
    private static func assignSecondaryStructureHeuristically(_ atoms: inout [Atom]) {
        // Group atoms by residue
        let residueGroups = Dictionary(grouping: atoms) { "\($0.chain)_\($0.residueNumber)" }
        
        // Simple heuristic based on amino acid propensities
        // Amino acids with high helix propensity
        let helixFavoringResidues = ["ALA", "LEU", "MET", "GLU", "LYS", "ARG", "GLN"]
        // Amino acids with high sheet propensity
        let sheetFavoringResidues = ["VAL", "ILE", "PHE", "TYR", "TRP", "THR"]
        
        // Process residues to identify potential secondary structures
        for (_, residueAtoms) in residueGroups {
            if let firstAtom = residueAtoms.first {
                let resName = firstAtom.residueName
                
                // Assign based on amino acid propensity
                let newSS: SecondaryStructure
                if helixFavoringResidues.contains(resName) {
                    newSS = .helix
                } else if sheetFavoringResidues.contains(resName) {
                    newSS = .sheet
                } else {
                    newSS = .coil
                }
                
                // Update all atoms in this residue
                for atomIndex in atoms.indices {
                    if atoms[atomIndex].chain == firstAtom.chain && 
                       atoms[atomIndex].residueNumber == firstAtom.residueNumber {
                        atoms[atomIndex] = Atom(
                            id: atoms[atomIndex].id,
                            element: atoms[atomIndex].element,
                            name: atoms[atomIndex].name,
                            chain: atoms[atomIndex].chain,
                            residueName: atoms[atomIndex].residueName,
                            residueNumber: atoms[atomIndex].residueNumber,
                            position: atoms[atomIndex].position,
                            secondaryStructure: newSS,
                            isBackbone: atoms[atomIndex].isBackbone
                        )
                    }
                }
            }
        }
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