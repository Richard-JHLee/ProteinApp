import SwiftUI

struct HeaderSectionView: View {
    let protein: ProteinInfo
    let onScrollToSection: (String) -> Void
    let onStructureLevelTap: (Int) -> Void // 1,2,3,4 단계 탭 핸들러 추가

    var body: some View {
        VStack(spacing: 16) {
            // 네비게이션 바
            navigationBar
            
            // 기존 헤더 카드
            GlassCard {
                VStack(spacing: 12) {
                    // 상단: 아이콘과 단백질 이름
                    HStack(alignment: .center, spacing: 16) {
                        GradientIcon(systemName: protein.dynamicIcon,
                                     base: protein.category.color)
                            .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(protein.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(protein.name.count > 50 ? 1 : 2)  // 동적 길이 조정
                                .truncationMode(.tail)                       // "..." 표시
                                .minimumScaleFactor(0.8)                     // 필요시 텍스트 크기 축소
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 8)
                    }
                    
                    // 하단: PDB ID와 카테고리 태그 (전체 너비 사용)
                    HStack(spacing: 8) {
                        CapsuleTag(text: "PDB \(protein.id)",
                                   foreground: protein.category.color,
                                   background: protein.category.color.opacity(0.12),
                                   icon: "barcode.viewfinder")
                        
                        CapsuleTag(text: protein.category.rawValue,
                                   foreground: .white,
                                   background: protein.category.color.opacity(0.9),
                                   icon: "tag.fill")
                        
                        Spacer() // 남은 공간 차지
                    }
                }
                .padding(16)
            }
            
            // 1,2,3,4 단계 구조 정보 추가
            structureLevelsView
        }
        .padding(.top, 6)
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack(spacing: 12) {
            navigationButton(title: "Overview", section: "overview", icon: "info.circle")
            navigationButton(title: "Function", section: "function", icon: "function")
            navigationButton(title: "Structure", section: "structure", icon: "cube.box")
            navigationButton(title: "Related", section: "related", icon: "link")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func navigationButton(title: String, section: String, icon: String) -> some View {
        Button(action: {
            scrollToSection(section)
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(protein.category.color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(protein.category.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private func scrollToSection(_ section: String) {
        onScrollToSection(section)
    }
    
    // MARK: - Structure Levels View
    private var structureLevelsView: some View {
        InfoCard(icon: "cube.box", title: "Protein Structure Levels", tint: .cyan) {
            VStack(spacing: 16) {
                structureLevel(number: "1", title: "Primary Structure", 
                              description: "Amino acid sequence", 
                              color: .blue)
                
                structureLevel(number: "2", title: "Secondary Structure", 
                              description: "Alpha helix, beta sheet, turns", 
                              color: .green)
                
                structureLevel(number: "3", title: "Tertiary Structure", 
                              description: "3D folding and domains", 
                              color: .orange)
                
                structureLevel(number: "4", title: "Quaternary Structure", 
                              description: "Subunit assembly", 
                              color: .purple)
            }
        }
    }
    
    // 구조 단계 카드 생성 함수
    private func structureLevel(number: String, title: String, description: String, color: Color) -> some View {
        Button(action: {
            onStructureLevelTap(Int(number) ?? 0)
        }) {
            HStack(spacing: 12) {
                // 단계 번호
                Text(number)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(color, in: Circle())
                
                // 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 화살표
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}