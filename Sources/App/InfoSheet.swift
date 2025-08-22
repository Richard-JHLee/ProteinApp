import SwiftUI

struct InfoSheet: View {
    let protein: ProteinInfo
    let onProteinSelected: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingProteinView = false
    @State private var showingPDBWebsite = false
    
    init(protein: ProteinInfo, onProteinSelected: ((String) -> Void)? = nil) {
        self.protein = protein
        self.onProteinSelected = onProteinSelected
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 헤더 섹션 (단백질명, 카테고리)
                    headerSection
                    
                    // 주요 정보 섹션 (기능 요약, PDB 링크, 질병 연관성)
                    mainInfoSection
                    
                    // 상세 정보 섹션
                    detailedInfoSection
                    
                    // 키워드 및 관련 정보
                    additionalInfoSection
                    
                    // 액션 버튼들
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Protein Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingProteinView) {
            ProteinViewSheet(proteinId: protein.id)
        }
        .sheet(isPresented: $showingPDBWebsite) {
            PDBWebsiteSheet(proteinId: protein.id)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // 단백질 아이콘과 카테고리
            HStack(spacing: 20) {
                // 단백질 아이콘
                ZStack {
                    Circle()
                        .fill(protein.category.color.opacity(0.1))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: protein.category.icon)
                        .font(.system(size: 35))
                        .foregroundColor(protein.category.color)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // 단백질 이름
                    Text(protein.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    // PDB ID
                    Text("PDB ID: \(protein.id)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    // 카테고리 태그
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(protein.category.color)
                            .font(.caption)
                        Text(protein.category.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(protein.category.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(protein.category.color.opacity(0.1))
                    .cornerRadius(16)
                }
                
                Spacer()
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Main Info Section
    private var mainInfoSection: some View {
        VStack(spacing: 20) {
            // 기능 요약
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Function Summary", icon: "function")
                
                Text(protein.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
            
            // PDB 링크 및 외부 정보
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("External Resources", icon: "link")
                
                VStack(spacing: 12) {
                    // PDB 웹사이트 링크
                    Button(action: {
                        showingPDBWebsite = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("View on PDB Website")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                Text("rcsb.org/structure/\(protein.id)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                        .padding(16)
                        .background(Color(.systemBlue).opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // UniProt 링크 (나중에 구현)
                    Button(action: {
                        // TODO: UniProt 링크 구현
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "database")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("View on UniProt")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                Text("Protein sequence & function")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.green)
                        }
                        .padding(16)
                        .background(Color(.systemGreen).opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            // 질병 연관성
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Disease Association", icon: "cross.case")
                
                VStack(spacing: 12) {
                    // 질병 연관성 정보 (샘플 데이터)
                    diseaseAssociationCard
                    
                    // 관련 연구 정보
                    researchInfoCard
                }
            }
        }
    }
    
    // MARK: - Disease Association Card
    private var diseaseAssociationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Disease Associations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // 질병 연관성 정보 (샘플 데이터)
            VStack(alignment: .leading, spacing: 8) {
                Text("This protein is associated with several diseases:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    diseaseItem(name: "Inflammatory diseases", severity: "Moderate", color: .orange)
                    diseaseItem(name: "Autoimmune disorders", severity: "High", color: .red)
                    diseaseItem(name: "Metabolic syndrome", severity: "Low", color: .blue)
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Research Info Card
    private var researchInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundColor(.purple)
                Text("Research Status")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current research focus:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    researchStatusItem(title: "Active Studies", count: "12", color: .green)
                    researchStatusItem(title: "Clinical Trials", count: "3", color: .blue)
                    researchStatusItem(title: "Publications", count: "47", color: .purple)
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Helper Views for Disease & Research
    private func diseaseItem(name: String, severity: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
            Text(severity)
                .font(.caption2)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.1))
                .cornerRadius(4)
        }
    }
    
    private func researchStatusItem(title: String, count: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Detailed Info Section
    private var detailedInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Additional Information", icon: "info.circle")
            
            VStack(spacing: 12) {
                // 구조 정보
                infoRow(title: "Structure Type", value: "X-ray Crystallography", icon: "cube.box")
                infoRow(title: "Resolution", value: "2.1 Å", icon: "scope")
                infoRow(title: "Organism", value: "Homo sapiens", icon: "person")
                infoRow(title: "Expression", value: "Ubiquitous", icon: "leaf")
            }
        }
    }
    
    // MARK: - Additional Info Section
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Keywords & Tags", icon: "key.fill")
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 8)
            ], spacing: 8) {
                ForEach(protein.keywords, id: \.self) { keyword in
                    Text(keyword)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(protein.category.color.opacity(0.1))
                        .foregroundColor(protein.category.color)
                        .cornerRadius(16)
                }
            }
            
            // 관련 단백질 정보
            VStack(alignment: .leading, spacing: 12) {
                Text("Related Proteins")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        relatedProteinChip(id: "1CAT", name: "Catalase")
                        relatedProteinChip(id: "1TIM", name: "Triose Phosphate Isomerase")
                        relatedProteinChip(id: "1HRP", name: "Horseradish Peroxidase")
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Protein View 버튼
            Button(action: {
                if let onProteinSelected = onProteinSelected {
                    onProteinSelected(protein.id)
                    dismiss()
                } else {
                    showingProteinView = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "cube.box.fill")
                        .font(.title2)
                    Text("View 3D Structure")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(protein.category.color)
                .cornerRadius(16)
            }
            
            // 즐겨찾기 버튼 (나중에 구현)
            Button(action: {
                // TODO: 즐겨찾기 토글 기능 구현
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.title2)
                    Text("Add to Favorites")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(protein.category.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(protein.category.color.opacity(0.1))
                .cornerRadius(16)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(protein.category.color)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .foregroundColor(.primary)
    }
    
    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(protein.category.color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func relatedProteinChip(id: String, name: String) -> some View {
        VStack(spacing: 4) {
            Text(id)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            Text(name)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.quaternarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Protein View Sheet
struct ProteinViewSheet: View {
    let proteinId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ProteinSceneView(proteinId: proteinId)
                .navigationTitle("3D Structure")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - PDB Website Sheet
struct PDBWebsiteSheet: View {
    let proteinId: String
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // PDB 링크 정보
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("PDB Website")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("View detailed information about this protein structure on the official PDB website.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // PDB 링크
                VStack(spacing: 12) {
                    Text("Direct Link:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Link(destination: URL(string: "https://www.rcsb.org/structure/\(proteinId)")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                            Text("rcsb.org/structure/\(proteinId)")
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBlue).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 추가 정보
                VStack(alignment: .leading, spacing: 12) {
                    Text("What you'll find:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        featureItem(icon: "cube.box", text: "3D structure visualization")
                        featureItem(icon: "doc.text", text: "Detailed experimental data")
                        featureItem(icon: "chart.bar", text: "Sequence information")
                        featureItem(icon: "person.2", text: "Publication references")
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 30)
            .navigationTitle("PDB Website")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func featureItem(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

// MARK: - Preview
struct InfoSheet_Previews: PreviewProvider {
    static var previews: some View {
        InfoSheet(protein: ProteinInfo(
            id: "1LYZ",
            name: "Lysozyme",
            category: .enzymes,
            description: "항균 작용을 하는 효소, 눈물과 침에 존재하며 세균의 세포벽을 분해하는 역할을 합니다.",
            keywords: ["항균", "효소", "lysozyme", "antibacterial", "tears"]
        ))
    }
}
