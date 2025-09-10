import SwiftUI

struct FeaturesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 3D 시각화 기능
                FeatureCard(
                    title: LanguageHelper.localizedText(
                        korean: "3D 단백질 시각화",
                        english: "3D Protein Visualization"
                    ),
                    icon: "cube",
                    color: .blue,
                    features: [
                        LanguageHelper.localizedText(
                            korean: "SceneKit 기반 고품질 3D 렌더링",
                            english: "High-quality 3D rendering based on SceneKit"
                        ),
                        LanguageHelper.localizedText(
                            korean: "실시간 인터랙티브 조작",
                            english: "Real-time interactive manipulation"
                        ),
                        LanguageHelper.localizedText(
                            korean: "다양한 렌더링 스타일 지원",
                            english: "Support for various rendering styles"
                        ),
                        LanguageHelper.localizedText(
                            korean: "LOD(Level of Detail) 최적화",
                            english: "LOD (Level of Detail) optimization"
                        )
                    ]
                )
                
                // 렌더링 스타일
                FeatureCard(
                    title: LanguageHelper.localizedText(
                        korean: "렌더링 스타일",
                        english: "Rendering Styles"
                    ),
                    icon: "paintbrush",
                    color: .green,
                    features: [
                        LanguageHelper.localizedText(
                            korean: "Spheres: 원자 구체 표현",
                            english: "Spheres: Atomic sphere representation"
                        ),
                        LanguageHelper.localizedText(
                            korean: "Sticks: 결합선 표현",
                            english: "Sticks: Bond line representation"
                        ),
                        LanguageHelper.localizedText(
                            korean: "Cartoon: 만화 스타일 표현",
                            english: "Cartoon: Cartoon style representation"
                        ),
                        LanguageHelper.localizedText(
                            korean: "Surface: 표면 표현",
                            english: "Surface: Surface representation"
                        )
                    ]
                )
                
                // 색상 모드
                FeatureCard(
                    title: LanguageHelper.localizedText(
                        korean: "색상 모드",
                        english: "Color Modes"
                    ),
                    icon: "circle.lefthalf.filled",
                    color: .purple,
                    features: [
                        LanguageHelper.localizedText(
                            korean: "Element: 원소별 색상",
                            english: "Element: Element-based coloring"
                        ),
                        LanguageHelper.localizedText(
                            korean: "Chain: 체인별 색상",
                            english: "Chain: Chain-based coloring"
                        ),
                        LanguageHelper.localizedText(
                            korean: "Secondary Structure: 2차 구조별 색상",
                            english: "Secondary Structure: Secondary structure-based coloring"
                        ),
                        LanguageHelper.localizedText(
                            korean: "Uniform: 단일 색상",
                            english: "Uniform: Single color"
                        )
                    ]
                )
                
                // 인터랙션 기능
                FeatureCard(
                    title: LanguageHelper.localizedText(
                        korean: "인터랙션 기능",
                        english: "Interaction Features"
                    ),
                    icon: "hand.tap",
                    color: .orange,
                    features: [
                        LanguageHelper.localizedText(
                            korean: "회전: 드래그로 3D 모델 회전",
                            english: "Rotation: Drag to rotate 3D model"
                        ),
                        LanguageHelper.localizedText(
                            korean: "확대/축소: 핀치 제스처",
                            english: "Zoom: Pinch gesture"
                        ),
                        LanguageHelper.localizedText(
                            korean: "슬라이스: 특정 부분만 표시",
                            english: "Slice: Display specific parts only"
                        ),
                        LanguageHelper.localizedText(
                            korean: "자동 회전: 더블 탭으로 토글",
                            english: "Auto rotation: Toggle with double tap"
                        )
                    ]
                )
                
                // 하이라이트 기능
                FeatureCard(
                    title: LanguageHelper.localizedText(
                        korean: "하이라이트 기능",
                        english: "Highlight Features"
                    ),
                    icon: "star",
                    color: .red,
                    features: [
                        LanguageHelper.localizedText(
                            korean: "Chain 하이라이트: 특정 체인 강조",
                            english: "Chain Highlight: Emphasize specific chains"
                        ),
                        LanguageHelper.localizedText(
                            korean: "Ligand 하이라이트: 리간드 강조",
                            english: "Ligand Highlight: Emphasize ligands"
                        ),
                        LanguageHelper.localizedText(
                            korean: "Pocket 하이라이트: 포켓 강조",
                            english: "Pocket Highlight: Emphasize pockets"
                        ),
                        LanguageHelper.localizedText(
                            korean: "전체 체인 하이라이트: 모든 체인 강조",
                            english: "All Chain Highlight: Emphasize all chains"
                        )
                    ]
                )
                
                // 정보 제공
                FeatureCard(
                    title: LanguageHelper.localizedText(
                        korean: "정보 제공",
                        english: "Information Display"
                    ),
                    icon: "info.circle",
                    color: .teal,
                    features: [
                        LanguageHelper.localizedText(
                            korean: "PDB 데이터베이스 연동",
                            english: "PDB database integration"
                        ),
                        LanguageHelper.localizedText(
                            korean: "단백질 구조 정보",
                            english: "Protein structure information"
                        ),
                        LanguageHelper.localizedText(
                            korean: "원자 정보 표시",
                            english: "Atomic information display"
                        ),
                        LanguageHelper.localizedText(
                            korean: "구조 단계별 정보",
                            english: "Structure level information"
                        )
                    ]
                )
                
                // 성능 최적화
                FeatureCard(
                    title: LanguageHelper.localizedText(
                        korean: "성능 최적화",
                        english: "Performance Optimization"
                    ),
                    icon: "speedometer",
                    color: .indigo,
                    features: [
                        LanguageHelper.localizedText(
                            korean: "지오메트리 캐싱",
                            english: "Geometry caching"
                        ),
                        LanguageHelper.localizedText(
                            korean: "LOD 시스템",
                            english: "LOD system"
                        ),
                        LanguageHelper.localizedText(
                            korean: "메모리 최적화",
                            english: "Memory optimization"
                        ),
                        LanguageHelper.localizedText(
                            korean: "배터리 효율성",
                            english: "Battery efficiency"
                        )
                    ]
                )
            }
            .padding()
        }
    }
}

struct FeatureCard: View {
    let title: String
    let icon: String
    let color: Color
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // 기능 목록
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(color)
                            .frame(width: 16, height: 16)
                        
                        Text(feature)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}
