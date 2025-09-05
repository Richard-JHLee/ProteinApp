import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 앱 아이콘 및 이름
            HStack(spacing: 16) {
                Image(systemName: "atom")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ProteinApp")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // 앱 설명
            VStack(alignment: .leading, spacing: 12) {
                Text("About ProteinApp")
                    .font(.headline)
                
                Text("ProteinApp은 단백질 구조를 3D로 시각화하고 학습할 수 있는 교육용 앱입니다. PDB 데이터베이스에서 단백질 구조를 다운로드하고, 다양한 렌더링 스타일로 3D 모델을 탐색할 수 있습니다.")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // 주요 기능
            VStack(alignment: .leading, spacing: 12) {
                Text("주요 기능")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "cube", title: "3D 단백질 시각화", description: "SceneKit을 사용한 고품질 3D 렌더링")
                    FeatureRow(icon: "paintbrush", title: "다양한 렌더링 스타일", description: "Spheres, Sticks, Cartoon, Surface 스타일")
                    FeatureRow(icon: "palette", title: "색상 모드", description: "Element, Chain, Secondary Structure 색상")
                    FeatureRow(icon: "hand.tap", title: "인터랙티브 조작", description: "회전, 확대/축소, 슬라이스 기능")
                    FeatureRow(icon: "book", title: "단백질 정보", description: "PDB 데이터베이스 연동 정보 제공")
                }
            }
            
            Divider()
            
            // 개발자 정보
            VStack(alignment: .leading, spacing: 8) {
                Text("Developer")
                    .font(.headline)
                
                Text("Avas Team")
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text("© 2024 ProteinApp. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
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
