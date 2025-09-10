import SwiftUI

struct UserGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 기본 사용법
                GuideSection(
                    title: LanguageHelper.localizedText(
                        korean: "기본 사용법",
                        english: "Basic Usage"
                    ),
                    icon: "play.circle",
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            GuideStep(
                                step: "1",
                                title: LanguageHelper.localizedText(
                                    korean: "단백질 선택",
                                    english: "Select Protein"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "홈 화면에서 단백질 라이브러리를 선택하거나 PDB ID를 입력하여 단백질을 로드합니다.",
                                    english: "Select a protein from the library on the home screen or enter a PDB ID to load a protein."
                                )
                            )
                            
                            GuideStep(
                                step: "2",
                                title: LanguageHelper.localizedText(
                                    korean: "3D 뷰어 탐색",
                                    english: "3D Viewer Navigation"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "단백질이 로드되면 3D 뷰어에서 구조를 탐색할 수 있습니다.",
                                    english: "Once the protein is loaded, you can explore the structure in the 3D viewer."
                                )
                            )
                            
                            GuideStep(
                                step: "3",
                                title: LanguageHelper.localizedText(
                                    korean: "렌더링 스타일 변경",
                                    english: "Change Rendering Style"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "하단 컨트롤 바에서 Spheres, Sticks, Cartoon, Surface 스타일을 선택할 수 있습니다.",
                                    english: "You can select Spheres, Sticks, Cartoon, or Surface styles from the bottom control bar."
                                )
                            )
                        }
                    }
                )
                
                // 뷰어 모드 사용법
                GuideSection(
                    title: LanguageHelper.localizedText(
                        korean: "뷰어 모드 사용법",
                        english: "Viewer Mode Usage"
                    ),
                    icon: "eye",
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            GuideStep(
                                step: "1",
                                title: LanguageHelper.localizedText(
                                    korean: "뷰어 모드 전환",
                                    english: "Switch to Viewer Mode"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "상단의 'Viewer' 버튼을 탭하여 뷰어 모드로 전환합니다.",
                                    english: "Tap the 'Viewer' button at the top to switch to viewer mode."
                                )
                            )
                            
                            GuideStep(
                                step: "2",
                                title: LanguageHelper.localizedText(
                                    korean: "렌더링 스타일 선택",
                                    english: "Select Rendering Style"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "하단 Primary Bar에서 원하는 렌더링 스타일을 선택합니다.",
                                    english: "Select your desired rendering style from the bottom Primary Bar."
                                )
                            )
                            
                            GuideStep(
                                step: "3",
                                title: LanguageHelper.localizedText(
                                    korean: "색상 모드 선택",
                                    english: "Select Color Mode"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "Color Schemes에서 Element, Chain, Secondary Structure 색상 모드를 선택합니다.",
                                    english: "Choose Element, Chain, or Secondary Structure color modes from Color Schemes."
                                )
                            )
                            
                            GuideStep(
                                step: "4",
                                title: LanguageHelper.localizedText(
                                    korean: "옵션 조정",
                                    english: "Adjust Options"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "Options에서 회전, 확대/축소, 투명도, 원자 크기를 조정할 수 있습니다.",
                                    english: "You can adjust rotation, zoom, transparency, and atom size in Options."
                                )
                            )
                        }
                    }
                )
                
                // 인터랙션 가이드
                GuideSection(
                    title: LanguageHelper.localizedText(
                        korean: "인터랙션 가이드",
                        english: "Interaction Guide"
                    ),
                    icon: "hand.tap",
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            InteractionGuide(
                                gesture: LanguageHelper.localizedText(
                                    korean: "드래그",
                                    english: "Drag"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "3D 모델 회전",
                                    english: "Rotate 3D model"
                                ),
                                icon: "arrow.triangle.2.circlepath"
                            )
                            
                            InteractionGuide(
                                gesture: LanguageHelper.localizedText(
                                    korean: "핀치",
                                    english: "Pinch"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "확대/축소",
                                    english: "Zoom in/out"
                                ),
                                icon: "magnifyingglass"
                            )
                            
                            InteractionGuide(
                                gesture: LanguageHelper.localizedText(
                                    korean: "더블 탭",
                                    english: "Double Tap"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "자동 회전 토글",
                                    english: "Toggle auto rotation"
                                ),
                                icon: "arrow.clockwise"
                            )
                            
                            InteractionGuide(
                                gesture: LanguageHelper.localizedText(
                                    korean: "롱 프레스",
                                    english: "Long Press"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "원자 정보 표시",
                                    english: "Show atom information"
                                ),
                                icon: "info.circle"
                            )
                        }
                    }
                )
                
                // 팁과 요령
                GuideSection(
                    title: LanguageHelper.localizedText(
                        korean: "팁과 요령",
                        english: "Tips & Tricks"
                    ),
                    icon: "lightbulb",
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            TipItem(
                                icon: "star",
                                title: LanguageHelper.localizedText(
                                    korean: "하이라이트 기능",
                                    english: "Highlight Feature"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "Chain, Ligand, Pocket을 선택하여 특정 부분을 하이라이트할 수 있습니다.",
                                    english: "Select Chain, Ligand, or Pocket to highlight specific parts of the structure."
                                )
                            )
                            
                            TipItem(
                                icon: "slider.horizontal.3",
                                title: LanguageHelper.localizedText(
                                    korean: "슬라이스 기능",
                                    english: "Slice Feature"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "복잡한 구조에서 특정 부분만 보기 위해 슬라이스 기능을 사용하세요.",
                                    english: "Use the slice feature to view only specific parts of complex structures."
                                )
                            )
                            
                            TipItem(
                                icon: "paintbrush",
                                title: LanguageHelper.localizedText(
                                    korean: "색상 모드 활용",
                                    english: "Color Mode Usage"
                                ),
                                description: LanguageHelper.localizedText(
                                    korean: "Secondary Structure 모드에서 α-helix와 β-sheet를 쉽게 구분할 수 있습니다.",
                                    english: "In Secondary Structure mode, you can easily distinguish between α-helix and β-sheet."
                                )
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
