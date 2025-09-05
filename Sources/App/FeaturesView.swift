import SwiftUI

struct FeaturesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 3D 시각화 기능
                FeatureCard(
                    title: "3D 단백질 시각화",
                    icon: "cube",
                    color: .blue,
                    features: [
                        "SceneKit 기반 고품질 3D 렌더링",
                        "실시간 인터랙티브 조작",
                        "다양한 렌더링 스타일 지원",
                        "LOD(Level of Detail) 최적화"
                    ]
                )
                
                // 렌더링 스타일
                FeatureCard(
                    title: "렌더링 스타일",
                    icon: "paintbrush",
                    color: .green,
                    features: [
                        "Spheres: 원자 구체 표현",
                        "Sticks: 결합선 표현",
                        "Cartoon: 만화 스타일 표현",
                        "Surface: 표면 표현"
                    ]
                )
                
                // 색상 모드
                FeatureCard(
                    title: "색상 모드",
                    icon: "palette",
                    color: .purple,
                    features: [
                        "Element: 원소별 색상",
                        "Chain: 체인별 색상",
                        "Secondary Structure: 2차 구조별 색상",
                        "Uniform: 단일 색상"
                    ]
                )
                
                // 인터랙션 기능
                FeatureCard(
                    title: "인터랙션 기능",
                    icon: "hand.tap",
                    color: .orange,
                    features: [
                        "회전: 드래그로 3D 모델 회전",
                        "확대/축소: 핀치 제스처",
                        "슬라이스: 특정 부분만 표시",
                        "자동 회전: 더블 탭으로 토글"
                    ]
                )
                
                // 하이라이트 기능
                FeatureCard(
                    title: "하이라이트 기능",
                    icon: "star",
                    color: .red,
                    features: [
                        "Chain 하이라이트: 특정 체인 강조",
                        "Ligand 하이라이트: 리간드 강조",
                        "Pocket 하이라이트: 포켓 강조",
                        "전체 체인 하이라이트: 모든 체인 강조"
                    ]
                )
                
                // 정보 제공
                FeatureCard(
                    title: "정보 제공",
                    icon: "info.circle",
                    color: .teal,
                    features: [
                        "PDB 데이터베이스 연동",
                        "단백질 구조 정보",
                        "원자 정보 표시",
                        "구조 단계별 정보"
                    ]
                )
                
                // 성능 최적화
                FeatureCard(
                    title: "성능 최적화",
                    icon: "speedometer",
                    color: .indigo,
                    features: [
                        "지오메트리 캐싱",
                        "LOD 시스템",
                        "메모리 최적화",
                        "배터리 효율성"
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
