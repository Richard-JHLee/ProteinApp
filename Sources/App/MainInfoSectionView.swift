import SwiftUI
import UIKit

struct MainInfoSectionView: View {
    let protein: ProteinInfo
    @Binding var showingPDBWebsite: Bool
    @State private var showingStructureDetails = false // 구조 세부 정보 표시 상태
    @State private var showingAminoAcidSequence = false // 아미노산 서열 화면 표시 상태
    @State private var aminoAcidSequences: [String] = [] // 아미노산 서열 데이터
    @State private var isLoadingSequence = false // 서열 로딩 상태
    @State private var sequenceError: String? = nil // 서열 오류 메시지
    @State private var showingPrimaryStructure = false // Primary Structure 팝업 상태
    @State private var showingSecondaryStructure = false // Secondary Structure 팝업 상태
    @State private var showingTertiaryStructure = false // Tertiary Structure 팝업 상태
    @State private var showingQuaternaryStructure = false // Quaternary Structure 팝업 상태
    @State private var showingFunctionDetails = false // Function Details 팝업 상태

    var body: some View {
        VStack(spacing: 14) {
            // 기능 요약
            InfoCard(icon: "function",
                     title: "Function Summary",
                     tint: protein.category.color) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(protein.description)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button(action: {
                        showingFunctionDetails = true
                    }) {
                        HStack {
                            Text("View Details")
                                .font(.caption.weight(.medium))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                        }
                        .foregroundColor(protein.category.color)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 핵심 포인트
            HStack(spacing: 10) {
                // 구조 단계 버튼 (클릭 가능)
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingStructureDetails.toggle()
                    }
                }) {
                    MetricPill(title: "Structure", value: "1→4 단계", icon: "square.grid.2x2")
                }
                .buttonStyle(.plain)
                
                MetricPill(title: "Coloring",  value: "Element/Chain/SS", icon: "paintbrush")
                MetricPill(title: "Interact",  value: "Rotate/Zoom/Slice", icon: "hand.tap")
            }
            
            // 구조 단계별 세부 정보
            if showingStructureDetails {
                structureDetailsView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }

            // 외부 리소스
            InfoCard(icon: "link",
                     title: "External Resources",
                     tint: .blue) {
                VStack(spacing: 10) {
                    LinkRow(
                        title: "View on PDB Website",
                        subtitle: "rcsb.org/structure/\(protein.id)",
                        systemImage: "globe",
                        tint: .blue
                    ) { showingPDBWebsite = true }

                    LinkRow(
                        title: "View on UniProt",
                        subtitle: "Protein sequence & function",
                        systemImage: "externaldrive.fill",
                        tint: .green
                    ) {
                        // TODO: UniProt 링크
                    }
                }
            }

            // 질병 연관성
            InfoCard(icon: "cross.case",
                     title: "Disease Association",
                     tint: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This protein is associated with several diseases:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 6) {
                        diseaseItem(name: "Inflammatory diseases", severity: "Moderate", color: .orange)
                        diseaseItem(name: "Autoimmune disorders",  severity: "High",    color: .red)
                        diseaseItem(name: "Metabolic syndrome",     severity: "Low",     color: .blue)
                    }
                }
            }

            // 연구 상태
            InfoCard(icon: "flask.fill",
                     title: "Research Status",
                     tint: .purple) {
                HStack(spacing: 12) {
                    researchStatusItem(title: "Active Studies",  count: "12", color: .green)
                    researchStatusItem(title: "Clinical Trials", count: "3",  color: .blue)
                    researchStatusItem(title: "Publications",    count: "47", color: .purple)
                }
            }
        }
        .sheet(isPresented: $showingAminoAcidSequence) {
            aminoAcidSequenceSheet
        }
        .sheet(isPresented: $showingPrimaryStructure) {
            PrimaryStructureView(protein: protein)
        }
        .sheet(isPresented: $showingSecondaryStructure) {
            SecondaryStructureView(protein: protein)
        }
        .sheet(isPresented: $showingTertiaryStructure) {
            TertiaryStructureView(protein: protein)
        }
        .sheet(isPresented: $showingQuaternaryStructure) {
            QuaternaryStructureView(protein: protein)
        }
        // .sheet(isPresented: $showingFunctionDetails) {
        //     FunctionDetailsView(protein: protein)
        // }
    }

    // MARK: - Structure Details View
    private var structureDetailsView: some View {
        InfoCard(icon: "cube.box",
                 title: "Protein Structure Levels",
                 tint: .cyan) {
            VStack(spacing: 16) {
                // 각 단계별 정보
                structureLevel(
                    number: "1",
                    title: "Primary Structure",
                    description: "Amino acid sequence",
                    apiEndpoint: "polymer_entity/\(protein.id)/1",
                    color: .blue
                )
                
                structureLevel(
                    number: "2",
                    title: "Secondary Structure",
                    description: "Alpha helices, beta sheets",
                    apiEndpoint: "secondary_structure/\(protein.id)",
                    color: .green
                )
                
                structureLevel(
                    number: "3",
                    title: "Tertiary Structure",
                    description: "3D protein fold (PDB file)",
                    apiEndpoint: "files.rcsb.org/download/\(protein.id).pdb",
                    color: .orange
                )
                
                structureLevel(
                    number: "4",
                    title: "Quaternary Structure",
                    description: "Multi-subunit assembly",
                    apiEndpoint: "assembly/\(protein.id)/1",
                    color: .purple
                )
            }
        }
    }
    
    private func structureLevel(number: String, title: String, description: String, apiEndpoint: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                // 단계 번호
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Text(number)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // API 엔드포인트 버튼
                Button(action: {
                    switch title {
                    case "Primary Structure":
                        showingPrimaryStructure = true
                    case "Secondary Structure":
                        showingSecondaryStructure = true
                    case "Tertiary Structure":
                        showingTertiaryStructure = true
                    case "Quaternary Structure":
                        showingQuaternaryStructure = true
                    default:
                        // 기타는 웹브라우저로 열기
                        openAPIEndpoint(apiEndpoint)
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.title3)
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
            }
            
            // 구분선
            if number != "4" {
                Divider()
                    .opacity(0.5)
            }
        }
    }
        
    // MARK: - Amino Acid Sequence Sheet
    private var aminoAcidSequenceSheet: some View {
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
                .padding(20)
            }
            .navigationTitle("Primary Structure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { 
                        showingAminoAcidSequence = false 
                    }
                }
            }
        }
        .onAppear {
            if aminoAcidSequences.isEmpty {
                Task {
                    await loadAminoAcidSequence()
                }
            }
        }
    }
        
    private var aminoAcidLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
                
            Text("아미노산 서열 데이터를 가져오는 중...")
                .font(.headline)
                .foregroundColor(.primary)
                
            Text("잠시만 기다려주세요")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
        
    private func aminoAcidErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                
            Text("데이터를 불러올 수 없습니다")
                .font(.headline)
                .foregroundColor(.primary)
                
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
            Button("다시 시도") {
                Task { await loadAminoAcidSequence() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
        
    private var aminoAcidContentView: some View {
        VStack(spacing: 20) {
            // 헤더 정보
            HStack {
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    
                VStack(alignment: .leading, spacing: 2) {
                    Text("Protein ID: \(protein.id)")
                        .font(.headline)
                        .foregroundColor(.primary)
                        
                    Text("\(aminoAcidSequences.count)개의 폴리머 체인")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                    
                Spacer()
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
            // 아미노산 서열들
            ForEach(aminoAcidSequences.indices, id: \.self) { index in
                aminoAcidSequenceCard(aminoAcidSequences[index], chainIndex: index + 1)
            }
        }
    }
        
    private func aminoAcidSequenceCard(_ sequence: String, chainIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 체인 헤더
            HStack {
                Text("Chain \(chainIndex)")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    
                Spacer()
                    
                Text("\(sequence.count) 아미노산")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.gray.opacity(0.2), in: Capsule())
            }
                
            // 아미노산 서열 그리드
            aminoAcidGrid(sequence)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
        
    private func aminoAcidGrid(_ sequence: String) -> some View {
        let aminoAcids = Array(sequence)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)
            
        return VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(aminoAcids.indices, id: \.self) { index in
                    aminoAcidCell(
                        aminoAcid: String(aminoAcids[index]),
                        position: index + 1
                    )
                }
            }
                
            // 범례
            aminoAcidLegend
        }
    }
        
    private func aminoAcidCell(aminoAcid: String, position: Int) -> some View {
        VStack(spacing: 2) {
            Text(aminoAcid)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(aminoAcidColor(aminoAcid), in: RoundedRectangle(cornerRadius: 6))
                
            Text("\(position)")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }
        
    private var aminoAcidLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("아미노산 분류")
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
                
            HStack(spacing: 16) {
                legendItem("비극성", color: .blue)
                legendItem("극성", color: .green)
                legendItem("산성", color: .red)
                legendItem("염기성", color: .purple)
            }
        }
        .padding(.top, 8)
    }
        
    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
                
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
        
    // MARK: - Amino Acid Helper Functions
    private func aminoAcidColor(_ aminoAcid: String) -> Color {
        switch aminoAcid.uppercased() {
        // 비극성 (소수성)
        case "A", "V", "L", "I", "M", "F", "W", "P", "G":
            return .blue
        // 극성 (친수성)
        case "S", "T", "C", "Y", "N", "Q":
            return .green
        // 산성 (음전하)
        case "D", "E":
            return .red
        // 염기성 (양전하)
        case "K", "R", "H":
            return .purple
        default:
            return .gray
        }
    }
        
    private func loadAminoAcidSequence() async {
        await MainActor.run {
            isLoadingSequence = true
            sequenceError = nil
        }
            
        do {
            let sequences = try await fetchAminoAcidSequence()
            await MainActor.run {
                self.aminoAcidSequences = sequences
                self.isLoadingSequence = false
            }
        } catch {
            let errorMessage: String
                
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "인터넷 연결을 확인해주세요"
                case .timedOut:
                    errorMessage = "요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요"
                case .badServerResponse:
                    errorMessage = "서버에서 오류를 반환했습니다"
                case .cannotParseResponse:
                    errorMessage = "데이터 형식을 인식할 수 없습니다"
                case .badURL:
                    errorMessage = "잘못된 요청 주소입니다"
                default:
                    errorMessage = "네트워크 오류: \(urlError.localizedDescription)"
                }
            } else {
                errorMessage = "알 수 없는 오류: \(error.localizedDescription)"
            }
                
            await MainActor.run {
                self.sequenceError = errorMessage
                self.isLoadingSequence = false
            }
        }
    }
        
    private func fetchAminoAcidSequence() async throws -> [String] {
        let urlString = "https://data.rcsb.org/rest/v1/core/polymer_entity/\(protein.id)"
            
        print("🔗 API 요청 URL: \(urlString)")
            
        guard let url = URL(string: urlString) else {
            print("❌ 잘못된 URL: \(urlString)")
            throw URLError(.badURL)
        }
            
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
                
            // HTTP 응답 상태 확인
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 HTTP 응답 상태: \(httpResponse.statusCode)")
                    
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP 오류: \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
            }
                
            print("📦 받은 데이터 크기: \(data.count) bytes")
                
            // 받은 데이터를 문자열로 출력 (디버깅용)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 받은 JSON: \(String(jsonString.prefix(500)))...") // 처음 500자만 출력
            }
                
            // JSON 구조 파싱 시도
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ JSON 파싱 성공")
                        
                    // polymer_entities 배열 확인
                    if let polymerEntities = json["polymer_entities"] as? [[String: Any]] {
                        print("📋 polymer_entities 개수: \(polymerEntities.count)")
                            
                        var sequences: [String] = []
                            
                        for (index, entity) in polymerEntities.enumerated() {
                            print("🔍 Entity \(index + 1) 처리 중...")
                                
                            if let entityPoly = entity["entity_poly"] as? [String: Any] {
                                if let sequence = entityPoly["pdbx_seq_one_letter_code_can"] as? String {
                                    print("✅ 서열 발견: \(sequence.count)개 아미노산")
                                    sequences.append(sequence)
                                } else {
                                    print("⚠️ pdbx_seq_one_letter_code_can 필드 없음")
                                }
                            } else {
                                print("⚠️ entity_poly 필드 없음")
                            }
                        }
                            
                        if sequences.isEmpty {
                            print("❌ 아미노산 서열을 찾을 수 없음")
                            throw URLError(.cannotParseResponse)
                        }
                            
                        print("🎉 총 \(sequences.count)개의 서열 발견")
                        return sequences
                            
                    } else {
                        print("❌ polymer_entities 배열 없음")
                            
                        // 대안으로 다른 구조 시도
                        if let polymerEntity = json["polymer_entity"] as? [String: Any],
                           let entityPoly = polymerEntity["entity_poly"] as? [String: Any],
                           let sequence = entityPoly["pdbx_seq_one_letter_code_can"] as? String {
                            print("✅ 대안 구조에서 서열 발견")
                            return [sequence]
                        }
                            
                        throw URLError(.cannotParseResponse)
                    }
                } else {
                    print("❌ JSON 형식이 아님")
                    throw URLError(.cannotParseResponse)
                }
            } catch {
                print("❌ JSON 파싱 오류: \(error.localizedDescription)")
                throw URLError(.cannotParseResponse)
            }
                
        } catch {
            print("❌ 네트워크 오류: \(error.localizedDescription)")
                
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    throw URLError(.notConnectedToInternet)
                case .timedOut:
                    throw URLError(.timedOut)
                case .cannotParseResponse:
                    throw URLError(.cannotParseResponse)
                default:
                    throw urlError
                }
            }
                
            throw error
        }
    }
    
    // MARK: - API Functions
    private func openAPIEndpoint(_ endpoint: String) {
        let baseURL: String
        
        if endpoint.contains("files.rcsb.org") {
            // PDB 파일 다운로드
            baseURL = "https://\(endpoint)"
        } else {
            // RCSB PDB Data API
            baseURL = "https://data.rcsb.org/rest/v1/core/\(endpoint)"
        }
        
        if let url = URL(string: baseURL) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - Local helpers
    private func diseaseItem(name: String, severity: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(.caption).foregroundStyle(.primary)
            Spacer()
            Text(severity)
                .font(.caption2)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private func researchStatusItem(title: String, count: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(count).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}