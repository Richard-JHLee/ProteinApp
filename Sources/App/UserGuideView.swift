import SwiftUI

struct UserGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 기본 사용법
                GuideSection(
                    title: "기본 사용법",
                    icon: "play.circle",
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            GuideStep(
                                step: "1",
                                title: "단백질 선택",
                                description: "홈 화면에서 단백질 라이브러리를 선택하거나 PDB ID를 입력하여 단백질을 로드합니다."
                            )
                            
                            GuideStep(
                                step: "2",
                                title: "3D 뷰어 탐색",
                                description: "단백질이 로드되면 3D 뷰어에서 구조를 탐색할 수 있습니다."
                            )
                            
                            GuideStep(
                                step: "3",
                                title: "렌더링 스타일 변경",
                                description: "하단 컨트롤 바에서 Spheres, Sticks, Cartoon, Surface 스타일을 선택할 수 있습니다."
                            )
                        }
                    }
                )
                
                // 뷰어 모드 사용법
                GuideSection(
                    title: "뷰어 모드 사용법",
                    icon: "eye",
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            GuideStep(
                                step: "1",
                                title: "뷰어 모드 전환",
                                description: "상단의 'Viewer' 버튼을 탭하여 뷰어 모드로 전환합니다."
                            )
                            
                            GuideStep(
                                step: "2",
                                title: "렌더링 스타일 선택",
                                description: "하단 Primary Bar에서 원하는 렌더링 스타일을 선택합니다."
                            )
                            
                            GuideStep(
                                step: "3",
                                title: "색상 모드 선택",
                                description: "Color Schemes에서 Element, Chain, Secondary Structure 색상 모드를 선택합니다."
                            )
                            
                            GuideStep(
                                step: "4",
                                title: "옵션 조정",
                                description: "Options에서 회전, 확대/축소, 투명도, 원자 크기를 조정할 수 있습니다."
                            )
                        }
                    }
                )
                
                // 인터랙션 가이드
                GuideSection(
                    title: "인터랙션 가이드",
                    icon: "hand.tap",
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            InteractionGuide(
                                gesture: "드래그",
                                description: "3D 모델 회전",
                                icon: "arrow.triangle.2.circlepath"
                            )
                            
                            InteractionGuide(
                                gesture: "핀치",
                                description: "확대/축소",
                                icon: "magnifyingglass"
                            )
                            
                            InteractionGuide(
                                gesture: "더블 탭",
                                description: "자동 회전 토글",
                                icon: "arrow.clockwise"
                            )
                            
                            InteractionGuide(
                                gesture: "롱 프레스",
                                description: "원자 정보 표시",
                                icon: "info.circle"
                            )
                        }
                    }
                )
                
                // 팁과 요령
                GuideSection(
                    title: "팁과 요령",
                    icon: "lightbulb",
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            TipItem(
                                icon: "star",
                                title: "하이라이트 기능",
                                description: "Chain, Ligand, Pocket을 선택하여 특정 부분을 하이라이트할 수 있습니다."
                            )
                            
                            TipItem(
                                icon: "slider.horizontal.3",
                                title: "슬라이스 기능",
                                description: "복잡한 구조에서 특정 부분만 보기 위해 슬라이스 기능을 사용하세요."
                            )
                            
                            TipItem(
                                icon: "paintbrush",
                                title: "색상 모드 활용",
                                description: "Secondary Structure 모드에서 α-helix와 β-sheet를 쉽게 구분할 수 있습니다."
                            )
                        }
                    }
                )
            }
            .padding()
        }
    }
}

struct GuideSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GuideStep: View {
    let step: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct InteractionGuide: View {
    let gesture: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(gesture)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct TipItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
