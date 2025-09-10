import SwiftUI
import Foundation

// MARK: - Language Helper
struct LanguageHelper {
    static var isKorean: Bool {
        // 첫 번째 선호 언어만 확인 (Primary Language)
        let preferredLanguages = Locale.preferredLanguages
        
        // 선호 언어가 있는 경우 첫 번째 언어만 확인
        if let firstLanguage = preferredLanguages.first {
            let languageCode = firstLanguage.lowercased()
            // 첫 번째 언어가 한국어인 경우에만 한국어로 표시
            return languageCode.hasPrefix("ko")
        }
        
        // 선호 언어가 없는 경우 Locale의 languageCode 확인
        if let languageCode = Locale.current.languageCode?.lowercased() {
            return languageCode == "ko"
        }
        
        // 기본값은 영어
        return false
    }
    
    static func localizedText(korean: String, english: String) -> String {
        return isKorean ? korean : english
    }
}

struct AboutView: View {
    // 앱 정보를 동적으로 가져오기
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
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
                        
                        Text("Version \(appVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // 앱 설명
                VStack(alignment: .leading, spacing: 12) {
                    Text(LanguageHelper.localizedText(
                        korean: "ProteinApp 소개",
                        english: "About ProteinApp"
                    ))
                        .font(.headline)
                    
                    Text(LanguageHelper.localizedText(
                        korean: "ProteinApp은 생물학 교육을 위한 3D 단백질 구조 시각화 앱입니다. RCSB PDB 데이터베이스와 연동하여 실제 단백질 구조를 다운로드하고, 인터랙티브한 3D 환경에서 탐색할 수 있습니다.",
                        english: "ProteinApp is a 3D protein structure visualization app for biology education. It integrates with the RCSB PDB database to download real protein structures and explore them in an interactive 3D environment."
                    ))
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // 주요 기능
                VStack(alignment: .leading, spacing: 12) {
                    Text(LanguageHelper.localizedText(
                        korean: "주요 기능",
                        english: "Key Features"
                    ))
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(
                            icon: "cube", 
                            title: LanguageHelper.localizedText(korean: "3D 단백질 시각화", english: "3D Protein Visualization"),
                            description: LanguageHelper.localizedText(korean: "SceneKit 기반 고품질 3D 렌더링으로 실제 단백질 구조를 정확하게 표시", english: "High-quality 3D rendering based on SceneKit for accurate display of real protein structures")
                        )
                        FeatureRow(
                            icon: "paintbrush", 
                            title: LanguageHelper.localizedText(korean: "다양한 렌더링 스타일", english: "Various Rendering Styles"),
                            description: LanguageHelper.localizedText(korean: "Spheres, Sticks, Cartoon, Surface 등 4가지 시각화 모드", english: "4 visualization modes: Spheres, Sticks, Cartoon, Surface")
                        )
                        FeatureRow(
                            icon: "circle.lefthalf.filled", 
                            title: LanguageHelper.localizedText(korean: "색상 모드", english: "Color Modes"),
                            description: LanguageHelper.localizedText(korean: "원소별, 체인별, 2차 구조별 색상으로 단백질 구조 이해", english: "Element, chain, and secondary structure color modes for better understanding")
                        )
                        FeatureRow(
                            icon: "hand.tap", 
                            title: LanguageHelper.localizedText(korean: "인터랙티브 조작", english: "Interactive Controls"),
                            description: LanguageHelper.localizedText(korean: "회전, 확대/축소, 투명도 조절로 다양한 각도에서 관찰", english: "Rotate, zoom, and adjust transparency to observe from various angles")
                        )
                        FeatureRow(
                            icon: "book", 
                            title: LanguageHelper.localizedText(korean: "단백질 정보", english: "Protein Information"),
                            description: LanguageHelper.localizedText(korean: "RCSB PDB, UniProt 데이터베이스 연동으로 상세 정보 제공", english: "Detailed information through RCSB PDB and UniProt database integration")
                        )
                        FeatureRow(
                            icon: "magnifyingglass", 
                            title: LanguageHelper.localizedText(korean: "검색 기능", english: "Search Function"),
                            description: LanguageHelper.localizedText(korean: "PDB ID로 직접 검색하거나 카테고리별 단백질 탐색", english: "Direct search by PDB ID or browse proteins by category")
                        )
                        FeatureRow(
                            icon: "slider.horizontal.3", 
                            title: LanguageHelper.localizedText(korean: "성능 최적화", english: "Performance Optimization"),
                            description: LanguageHelper.localizedText(korean: "대용량 단백질 구조도 원활하게 렌더링하는 최적화된 엔진", english: "Optimized engine for smooth rendering of large protein structures")
                        )
                    }
                }
                
                Divider()
                
                // 개발자 정보
                VStack(alignment: .leading, spacing: 8) {
                    Text(LanguageHelper.localizedText(
                        korean: "개발자",
                        english: "Developer"
                    ))
                        .font(.headline)
                    
                    Text("AVAS")
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(LanguageHelper.localizedText(
                        korean: "© 2025 AVAS. 모든 권리 보유.",
                        english: "© 2025 AVAS. All rights reserved."
                    ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
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