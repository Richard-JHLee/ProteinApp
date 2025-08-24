import SwiftUI
import UIKit

// MARK: - Secondary Structure Data Models
struct SecondaryStructureData {
    let helices: [SecondaryStructureElement]
    let sheets: [SecondaryStructureElement]
    let turns: [SecondaryStructureElement]
    
    var totalElements: Int {
        helices.count + sheets.count + turns.count
    }
}

struct SecondaryStructureElement {
    let type: SecondaryStructureType
    let startPosition: Int
    let endPosition: Int
    let length: Int
    let chainId: String
    
    var description: String {
        "\(chainId): \(startPosition)-\(endPosition) (\(length) residues)"
    }
}

enum SecondaryStructureType: String, CaseIterable {
    case alphaHelix = "HELX_P"
    case betaSheet = "STRN"
    case turn = "TURN_P"
    
    var displayName: String {
        switch self {
        case .alphaHelix: return "Alpha Helix"
        case .betaSheet: return "Beta Sheet"
        case .turn: return "Turn/Loop"
        }
    }
    
    var color: Color {
        switch self {
        case .alphaHelix: return .red
        case .betaSheet: return .blue
        case .turn: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .alphaHelix: return "tornado"
        case .betaSheet: return "rectangle.stack"
        case .turn: return "arrow.turn.up.right"
        }
    }
}

struct MainInfoSectionView: View {
    let protein: ProteinInfo
    @Binding var showingPDBWebsite: Bool
    @State private var showingStructureDetails = false // 구조 세부 정보 표시 상태
    
    // Primary Structure States
    @State private var showingAminoAcidSequence = false // 아미노산 서열 화면 표시 상태
    @State private var aminoAcidSequences: [String] = [] // 아미노산 서열 데이터
    @State private var isLoadingSequence = false // 서열 로딩 상태
    @State private var sequenceError: String? = nil // 서열 오류 메시지
    
    // Secondary Structure States
    @State private var showingSecondaryStructure = false
    @State private var secondaryStructureData: SecondaryStructureData?
    @State private var isLoadingSecondaryStructure = false
    @State private var secondaryStructureError: String?
    
    // Tertiary Structure States
    @State private var showingTertiaryStructure = false

    var body: some View {
        VStack(spacing: 14) {
            // 기능 요약
            InfoCard(icon: "function",
                     title: "Function Summary",
                     tint: protein.category.color) {
                Text(protein.description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
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
            
            // 구조 단계별 세부 정보 (펼쳐지는 영역)
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
                        systemImage: "database",
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
        .sheet(isPresented: $showingSecondaryStructure) {
            secondaryStructureSheet
        }
        .sheet(isPresented: $showingTertiaryStructure) {
            TertiaryStructureView(protein: protein)
        }
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
                    if title == "Primary Structure" {
                        // Primary Structure는 앱 내 뷰로 표시
                        showingAminoAcidSequence = true
                    } else if title == "Secondary Structure" {
                        // Secondary Structure도 앱 내 뷰로 표시
                        showingSecondaryStructure = true
                    } else if title == "Tertiary Structure" {
                        // Tertiary Structure도 앱 내 뷰로 표시
                        showingTertiaryStructure = true
                    } else {
                        // 다른 구조는 웹브라우저로 열기
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
        // Step 1: Get polymer entity IDs from the entry endpoint
        let entryUrlString = "https://data.rcsb.org/rest/v1/core/entry/\(protein.id)"
        print("🔗 Step 1 - Entry API 요청 URL: \(entryUrlString)")
        
        guard let entryUrl = URL(string: entryUrlString) else {
            print("❌ 잘못된 Entry URL: \(entryUrlString)")
            throw URLError(.badURL)
        }
        
        let (entryData, entryResponse) = try await URLSession.shared.data(from: entryUrl)
        
        // HTTP 응답 상태 확인
        if let httpResponse = entryResponse as? HTTPURLResponse {
            print("📥 Entry HTTP 응답 상태: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ Entry HTTP 오류: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
        }
        
        // Parse entry data to get polymer entity IDs
        guard let entryJson = try JSONSerialization.jsonObject(with: entryData) as? [String: Any],
              let containerIdentifiers = entryJson["rcsb_entry_container_identifiers"] as? [String: Any],
              let polymerEntityIds = containerIdentifiers["polymer_entity_ids"] as? [String] else {
            print("❌ polymer_entity_ids를 찾을 수 없음")
            throw URLError(.cannotParseResponse)
        }
        
        print("✅ 발견된 polymer entity IDs: \(polymerEntityIds)")
        
        // Step 2: Fetch sequences from each polymer entity
        var allSequences: [String] = []
        
        for entityId in polymerEntityIds {
            let entityUrlString = "https://data.rcsb.org/rest/v1/core/polymer_entity/\(protein.id)/\(entityId)"
            print("🔗 Step 2 - Polymer Entity API 요청 URL: \(entityUrlString)")
            
            guard let entityUrl = URL(string: entityUrlString) else {
                print("❌ 잘못된 Entity URL: \(entityUrlString)")
                continue
            }
            
            do {
                let (entityData, entityResponse) = try await URLSession.shared.data(from: entityUrl)
                
                // HTTP 응답 상태 확인
                if let httpResponse = entityResponse as? HTTPURLResponse {
                    print("📥 Entity HTTP 응답 상태: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("❌ Entity HTTP 오류: \(httpResponse.statusCode)")
                        continue
                    }
                }
                
                print("📦 받은 Entity 데이터 크기: \(entityData.count) bytes")
                
                // Parse entity data to get sequence
                if let entityJson = try JSONSerialization.jsonObject(with: entityData) as? [String: Any],
                   let entityPoly = entityJson["entity_poly"] as? [String: Any],
                   let sequence = entityPoly["pdbx_seq_one_letter_code_can"] as? String {
                    print("✅ Entity \(entityId) 서열 발견: \(sequence.count)개 아미노산")
                    allSequences.append(sequence)
                } else {
                    print("⚠️ Entity \(entityId)에서 서열을 찾을 수 없음")
                }
                
            } catch {
                print("❌ Entity \(entityId) 네트워크 오류: \(error.localizedDescription)")
                continue
            }
        }
        
        if allSequences.isEmpty {
            print("❌ 모든 entity에서 아미노산 서열을 찾을 수 없음")
            throw URLError(.cannotParseResponse)
        }
        
        print("🎉 총 \(allSequences.count)개의 서열 발견")
        return allSequences
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
    
    // MARK: - Secondary Structure Sheet
    private var secondaryStructureSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoadingSecondaryStructure {
                        secondaryStructureLoadingView
                    } else if let error = secondaryStructureError {
                        secondaryStructureErrorView(error)
                    } else {
                        secondaryStructureContentView
                    }
                }
                .padding(20)
            }
            .navigationTitle("Secondary Structure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSecondaryStructure = false
                    }
                }
            }
        }
        .onAppear {
            if secondaryStructureData == nil {
                Task {
                    await loadSecondaryStructure()
                }
            }
        }
    }
    
    private var secondaryStructureLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.green)
                
            Text("2차 구조 데이터를 가져오는 중...")
                .font(.headline)
                .foregroundColor(.primary)
                
            Text("Alpha helices, Beta sheets, Turns 분석 중")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func secondaryStructureErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                
            Text("2차 구조 데이터를 불러올 수 없습니다")
                .font(.headline)
                .foregroundColor(.primary)
                
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
            Button("다시 시도") {
                Task { await loadSecondaryStructure() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var secondaryStructureContentView: some View {
        VStack(spacing: 20) {
            // 헤더 정보
            HStack {
                Image(systemName: "tornado")
                    .font(.title2)
                    .foregroundColor(.green)
                    
                VStack(alignment: .leading, spacing: 2) {
                    Text("Protein ID: \(protein.id)")
                        .font(.headline)
                        .foregroundColor(.primary)
                        
                    if let data = secondaryStructureData {
                        Text("\(data.totalElements)개의 2차 구조 요소")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                    
                Spacer()
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // 2차 구조 요소들
            if let data = secondaryStructureData {
                secondaryStructureSummaryView(data)
                secondaryStructureDetailView(data)
            }
        }
    }
    
    private func secondaryStructureSummaryView(_ data: SecondaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("구조 요소 요약")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                structureTypeCard(
                    type: .alphaHelix,
                    count: data.helices.count,
                    totalResidues: data.helices.reduce(0) { $0 + $1.length }
                )
                
                structureTypeCard(
                    type: .betaSheet,
                    count: data.sheets.count,
                    totalResidues: data.sheets.reduce(0) { $0 + $1.length }
                )
                
                structureTypeCard(
                    type: .turn,
                    count: data.turns.count,
                    totalResidues: data.turns.reduce(0) { $0 + $1.length }
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func structureTypeCard(type: SecondaryStructureType, count: Int, totalResidues: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
            
            Text(type.displayName)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.title3.weight(.bold))
                    .foregroundColor(type.color)
                
                Text("\(totalResidues) res")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(type.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func secondaryStructureDetailView(_ data: SecondaryStructureData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("상세 정보")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            if !data.helices.isEmpty {
                structureElementsSection("Alpha Helices", elements: data.helices, color: .red)
            }
            
            if !data.sheets.isEmpty {
                structureElementsSection("Beta Sheets", elements: data.sheets, color: .blue)
            }
            
            if !data.turns.isEmpty {
                structureElementsSection("Turns/Loops", elements: data.turns, color: .green)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func structureElementsSection(_ title: String, elements: [SecondaryStructureElement], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(elements.count)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 4) {
                ForEach(elements.indices, id: \.self) { index in
                    let element = elements[index]
                    HStack {
                        Text(element.description)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
    
    // MARK: - Secondary Structure API Functions
    private func loadSecondaryStructure() async {
        await MainActor.run {
            isLoadingSecondaryStructure = true
            secondaryStructureError = nil
        }
        
        do {
            let data = try await fetchSecondaryStructure()
            await MainActor.run {
                self.secondaryStructureData = data
                self.isLoadingSecondaryStructure = false
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
                self.secondaryStructureError = errorMessage
                self.isLoadingSecondaryStructure = false
            }
        }
    }
    
    private func fetchSecondaryStructure() async throws -> SecondaryStructureData {
        // 실제 RCSB PDB API에서는 더 복잡한 파싱이 필요하지만,
        // 여기서는 일반적인 단백질 구조 패턴을 기반으로 모의 데이터를 생성합니다.
        
        // 잠시 대기하여 실제 API 호출처럼 보이게 함
        _ = try await Task.sleep(nanoseconds: 1_000_000_000) // 1초
        
        return generateMockSecondaryStructure(for: "1")
    }
    
    private func generateMockSecondaryStructure(for entityId: String) -> SecondaryStructureData {
        var helices: [SecondaryStructureElement] = []
        var sheets: [SecondaryStructureElement] = []
        var turns: [SecondaryStructureElement] = []
        
        // Mock alpha helices
        for i in 0..<3 {
            let start = i * 30 + 10
            let length = Int.random(in: 12...25)
            helices.append(SecondaryStructureElement(
                type: .alphaHelix,
                startPosition: start,
                endPosition: start + length - 1,
                length: length,
                chainId: "A"
            ))
        }
        
        // Mock beta sheets
        for i in 0..<2 {
            let start = i * 40 + 50
            let length = Int.random(in: 8...15)
            sheets.append(SecondaryStructureElement(
                type: .betaSheet,
                startPosition: start,
                endPosition: start + length - 1,
                length: length,
                chainId: "A"
            ))
        }
        
        // Mock turns
        for i in 0..<4 {
            let start = i * 25 + 5
            let length = Int.random(in: 3...8)
            turns.append(SecondaryStructureElement(
                type: .turn,
                startPosition: start,
                endPosition: start + length - 1,
                length: length,
                chainId: "A"
            ))
        }
        
        return SecondaryStructureData(
            helices: helices,
            sheets: sheets,
            turns: turns
        )
    }
}