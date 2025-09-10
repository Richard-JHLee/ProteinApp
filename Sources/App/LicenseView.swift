import SwiftUI

struct LicenseView: View {
    // 앱 정보를 동적으로 가져오기
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ProteinViewerApp"
    }
    
    private var minimumOSVersion: String {
        if let minimumOSVersion = Bundle.main.infoDictionary?["MinimumOSVersion"] as? String {
            return "iOS \(minimumOSVersion)+"
        }
        return "iOS 15.6+"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MIT 라이센스 헤더
                VStack(alignment: .leading, spacing: 12) {
                    Text(LanguageHelper.localizedText(
                        korean: "MIT 라이센스",
                        english: "MIT License"
                    ))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(LanguageHelper.localizedText(
                        korean: "Copyright (c) 2025 AVAS",
                        english: "Copyright (c) 2025 AVAS"
                    ))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 라이센스 본문
                VStack(alignment: .leading, spacing: 16) {
                    Text(LanguageHelper.localizedText(
                        korean: "이 소프트웨어와 관련 문서 파일들(\"소프트웨어\")의 사본을 얻은 모든 사람에게는 소프트웨어를 제한 없이 취급할 수 있는 권한이 무료로 부여됩니다. 여기에는 사용, 복사, 수정, 병합, 게시, 배포, 서브라이센스 및/또는 소프트웨어의 사본을 판매할 권리와 소프트웨어가 제공된 사람들이 그러할 수 있도록 허가하는 권리가 제한 없이 포함됩니다. 단, 다음 조건에 따릅니다:",
                        english: "Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:"
                    ))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(LanguageHelper.localizedText(
                        korean: "위의 저작권 고지와 이 허가 고지는 소프트웨어의 모든 사본이나 중요한 부분에 포함되어야 합니다.",
                        english: "The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software."
                    ))
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(LanguageHelper.localizedText(
                        korean: "소프트웨어는 \"있는 그대로\" 제공되며, 상품성, 특정 목적에의 적합성 및 비침해에 대한 보증을 포함하되 이에 국한되지 않는 모든 종류의 명시적 또는 묵시적 보증 없이 제공됩니다. 어떤 경우에도 저자나 저작권 보유자는 계약 행위, 불법 행위 또는 기타 행위에서, 소프트웨어와 관련하여, 소프트웨어의 사용 또는 기타 거래에서 발생하는 청구, 손해 또는 기타 책임에 대해 책임지지 않습니다.",
                        english: "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."
                    ))
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Divider()
                
                // 오픈소스 라이브러리
                VStack(alignment: .leading, spacing: 16) {
                    Text(LanguageHelper.localizedText(
                        korean: "오픈소스 라이브러리",
                        english: "Open Source Libraries"
                    ))
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        LibraryItem(
                            name: "SceneKit",
                            description: LanguageHelper.localizedText(
                                korean: "Apple의 3D 그래픽 프레임워크",
                                english: "Apple's 3D graphics framework"
                            ),
                            license: LanguageHelper.localizedText(
                                korean: "Apple 라이센스",
                                english: "Apple License"
                            )
                        )
                        
                        LibraryItem(
                            name: "SwiftUI",
                            description: LanguageHelper.localizedText(
                                korean: "Apple의 선언적 UI 프레임워크",
                                english: "Apple's declarative UI framework"
                            ),
                            license: LanguageHelper.localizedText(
                                korean: "Apple 라이센스",
                                english: "Apple License"
                            )
                        )
                        
                        LibraryItem(
                            name: "PDB Database",
                            description: LanguageHelper.localizedText(
                                korean: "단백질 데이터 뱅크 공개 데이터",
                                english: "Protein Data Bank public data"
                            ),
                            license: LanguageHelper.localizedText(
                                korean: "퍼블릭 도메인",
                                english: "Public Domain"
                            )
                        )
                    }
                }
                
                Divider()
                
                // 앱 정보
                VStack(alignment: .leading, spacing: 8) {
                    Text(LanguageHelper.localizedText(
                        korean: "앱 정보",
                        english: "App Information"
                    ))
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        LicenseInfoRow(
                            title: LanguageHelper.localizedText(
                                korean: "앱 이름",
                                english: "App Name"
                            ),
                            value: appName,
                            description: LanguageHelper.localizedText(
                                korean: "애플리케이션 이름",
                                english: "Application name"
                            )
                        )
                        LicenseInfoRow(
                            title: LanguageHelper.localizedText(
                                korean: "버전",
                                english: "Version"
                            ),
                            value: appVersion,
                            description: LanguageHelper.localizedText(
                                korean: "현재 앱 버전",
                                english: "Current app version"
                            )
                        )
                        LicenseInfoRow(
                            title: LanguageHelper.localizedText(
                                korean: "빌드",
                                english: "Build"
                            ),
                            value: buildNumber,
                            description: LanguageHelper.localizedText(
                                korean: "빌드 번호",
                                english: "Build number"
                            )
                        )
                        LicenseInfoRow(
                            title: LanguageHelper.localizedText(
                                korean: "플랫폼",
                                english: "Platform"
                            ),
                            value: minimumOSVersion,
                            description: LanguageHelper.localizedText(
                                korean: "최소 지원 iOS 버전",
                                english: "Minimum supported iOS version"
                            )
                        )
                        LicenseInfoRow(
                            title: LanguageHelper.localizedText(
                                korean: "마지막 업데이트",
                                english: "Last Updated"
                            ),
                            value: LanguageHelper.localizedText(
                                korean: "2025년 1월",
                                english: "January 2025"
                            ),
                            description: LanguageHelper.localizedText(
                                korean: "마지막 업데이트 날짜",
                                english: "Last update date"
                            )
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct LibraryItem: View {
    let name: String
    let description: String
    let license: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(license)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}


struct LicenseInfoRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
