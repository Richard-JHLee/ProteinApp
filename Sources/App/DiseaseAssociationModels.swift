import Foundation

// MARK: - Disease Association Models

struct DiseaseAssociation: Codable, Identifiable {
    let id: String
    let diseaseName: String
    let diseaseId: String?
    let diseaseType: String?
    let evidenceLevel: EvidenceLevel
    let associationScore: Double?
    let associationType: AssociationType?
    let geneRole: String?
    let clinicalFeatures: [String]?
    let frequency: String?
    let treatability: String?
    let references: [Reference]?
    let dataSource: String?
    let lastUpdated: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case diseaseName = "disease_name"
        case diseaseId = "disease_id"
        case diseaseType = "disease_type"
        case evidenceLevel = "evidence_level"
        case associationScore = "association_score"
        case associationType = "association_type"
        case geneRole = "gene_role"
        case clinicalFeatures = "clinical_features"
        case frequency
        case treatability
        case references
        case dataSource = "data_source"
        case lastUpdated = "last_updated"
    }
}

enum EvidenceLevel: String, Codable, CaseIterable {
    case known = "Known"
    case predicted = "Predicted"
    case inferred = "Inferred"
    case uncertain = "Uncertain"
    
    var color: String {
        switch self {
        case .known: return "green"
        case .predicted: return "orange"
        case .inferred: return "blue"
        case .uncertain: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .known: return "checkmark.circle.fill"
        case .predicted: return "questionmark.circle.fill"
        case .inferred: return "arrow.right.circle.fill"
        case .uncertain: return "exclamationmark.circle.fill"
        }
    }
}

enum AssociationType: String, Codable, CaseIterable {
    case direct = "Direct"
    case indirect = "Indirect"
    case functional = "Functional"
    case structural = "Structural"
    
    var description: String {
        switch self {
        case .direct: return "Direct causal relationship"
        case .indirect: return "Indirect association"
        case .functional: return "Functional relationship"
        case .structural: return "Structural relationship"
        }
    }
}

struct Reference: Codable, Identifiable {
    let id: String
    let title: String
    let authors: String?
    let journal: String?
    let year: Int?
    let pmid: String?
    let doi: String?
    
    var displayTitle: String {
        if let year = year {
            return "\(title) (\(year))"
        }
        return title
    }
}

// MARK: - UniProt Disease Response Models

struct UniProtDiseaseResponse: Codable {
    let results: [UniProtDiseaseEntry]
    
    enum CodingKeys: String, CodingKey {
        case results
    }
}

struct UniProtDiseaseEntry: Codable {
    let primaryAccession: String?
    let organism: UniProtOrganism?
    let proteinDescription: UniProtProteinDescription?
    let comments: [UniProtComment]?
    let crossReferences: [UniProtCrossReference]?
    
    enum CodingKeys: String, CodingKey {
        case primaryAccession
        case organism
        case proteinDescription
        case comments
        case crossReferences
    }
}

struct UniProtOrganism: Codable {
    let scientificName: String
    let commonName: String?
    
    enum CodingKeys: String, CodingKey {
        case scientificName
        case commonName
    }
}


struct UniProtDiseaseComment: Codable {
    let type: String?
    let disease: [UniProtDisease]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case disease
    }
}

struct UniProtDisease: Codable {
    let diseaseId: String?
    let name: String?
    let acronym: String?
    let description: [UniProtDiseaseDescription]?
    
    enum CodingKeys: String, CodingKey {
        case diseaseId
        case name
        case acronym
        case description
    }
}

struct UniProtDiseaseDescription: Codable {
    let value: String
    let evidences: [UniProtEvidence]?
    
    enum CodingKeys: String, CodingKey {
        case value
        case evidences
    }
}

struct UniProtEvidence: Codable {
    let code: String?
    let source: UniProtEvidenceSource?
    
    enum CodingKeys: String, CodingKey {
        case code
        case source
    }
}

struct UniProtEvidenceSource: Codable {
    let name: String?
    let id: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case id
    }
}


struct UniProtCommentText: Codable {
    let value: String?
    
    enum CodingKeys: String, CodingKey {
        case value
    }
}


struct UniProtCrossReference: Codable {
    let database: String?
    let id: String?
    let properties: [UniProtProperty]?
    
    enum CodingKeys: String, CodingKey {
        case database
        case id
        case properties
    }
}

struct UniProtProperty: Codable {
    let key: String?
    let value: String?
    
    enum CodingKeys: String, CodingKey {
        case key
        case value
    }
}

// MARK: - Disease Association Summary

struct DiseaseAssociationSummary: Codable {
    let totalDiseases: Int
    let knownDiseases: Int
    let predictedDiseases: Int
    let topDiseases: [DiseaseAssociation]
    let categories: [String: Int]
    
    var hasDiseases: Bool {
        return totalDiseases > 0
    }
    
    var primaryDisease: DiseaseAssociation? {
        return topDiseases.first
    }
}
