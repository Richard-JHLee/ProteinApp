import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
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
                    
                    Text("ProteinApp은 생물학 교육을 위한 3D 단백질 구조 시각화 앱입니다. RCSB PDB 데이터베이스와 연동하여 실제 단백질 구조를 다운로드하고, 인터랙티브한 3D 환경에서 탐색할 수 있습니다.")
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // 주요 기능
                VStack(alignment: .leading, spacing: 12) {
                    Text("주요 기능")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "cube", title: "3D 단백질 시각화", description: "SceneKit 기반 고품질 3D 렌더링으로 실제 단백질 구조를 정확하게 표시")
                        FeatureRow(icon: "paintbrush", title: "다양한 렌더링 스타일", description: "Spheres, Sticks, Cartoon, Surface 등 4가지 시각화 모드")
                        FeatureRow(icon: "circle.lefthalf.filled", title: "색상 모드", description: "원소별, 체인별, 2차 구조별 색상으로 단백질 구조 이해")
                        FeatureRow(icon: "hand.tap", title: "인터랙티브 조작", description: "회전, 확대/축소, 투명도 조절로 다양한 각도에서 관찰")
                        FeatureRow(icon: "book", title: "단백질 정보", description: "RCSB PDB, UniProt 데이터베이스 연동으로 상세 정보 제공")
                        FeatureRow(icon: "magnifyingglass", title: "검색 기능", description: "PDB ID로 직접 검색하거나 카테고리별 단백질 탐색")
                        FeatureRow(icon: "slider.horizontal.3", title: "성능 최적화", description: "대용량 단백질 구조도 원활하게 렌더링하는 최적화된 엔진")
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
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("© 2024 ProteinApp. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
        }
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
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}