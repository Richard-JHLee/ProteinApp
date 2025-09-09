import SwiftUI

struct MenuDetailView: View {
    let item: MenuItemType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                switch item {
                case .about:
                    AboutView()
                case .userGuide:
                    UserGuideView()
                case .features:
                    FeaturesView()
                case .settings:
                    SettingsView()
                case .help:
                    HelpView()
                case .contact:
                    ContactView()
                case .privacy:
                    PrivacyView()
                case .terms:
                    TermsView()
                case .license:
                    LicenseView()
                }
            }
            .navigationTitle(item.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Additional Views for Menu Items

struct SettingsView: View {
    // Performance optimization settings
    @AppStorage("maxAtomsLimit") private var maxAtomsLimit: Int = 5000
    @AppStorage("enableOptimization") private var enableOptimization: Bool = false
    @AppStorage("samplingRatio") private var samplingRatio: Double = 0.25
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Performance Settings Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("성능 최적화")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("대용량 단백질 구조의 렌더링 성능을 조절할 수 있습니다.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Enable Optimization Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("성능 최적화 활성화", isOn: $enableOptimization)
                            .font(.headline)
                        
                        Text("활성화하면 대용량 단백질의 원자 수를 제한하여 성능을 향상시킵니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    if enableOptimization {
                        // Max Atoms Limit Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("최대 원자 수")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(maxAtomsLimit)")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(maxAtomsLimit) },
                                set: { maxAtomsLimit = Int($0) }
                            ), in: 1000...10000, step: 500)
                            
                            HStack {
                                Text("1000")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("빠른 렌더링")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("10000")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("고품질")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("5000개 이하는 최고 품질로 렌더링됩니다. 5000개 초과 시 성능 최적화가 적용됩니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        // Sampling Ratio Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("샘플링 비율")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(String(format: "%.1f", samplingRatio * 100))%")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            Slider(value: $samplingRatio, in: 0.05...0.5, step: 0.01)
                            
                            HStack {
                                Text("5%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("빠른 처리")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("50%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("고품질")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("각 체인에서 샘플링할 원자의 비율을 설정합니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                // Performance Info Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("성능 가이드")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        PerformanceInfoItem(
                            icon: "speedometer",
                            title: "빠른 렌더링",
                            description: "원자 수 500-1000개, 샘플링 5-10%",
                            color: .green
                        )
                        
                        PerformanceInfoItem(
                            icon: "slider.horizontal.3",
                            title: "균형",
                            description: "원자 수 1500-2500개, 샘플링 10-20%",
                            color: .orange
                        )
                        
                        PerformanceInfoItem(
                            icon: "star.fill",
                            title: "고품질",
                            description: "원자 수 3000-5000개, 샘플링 20-50%",
                            color: .blue
                        )
                    }
                }
                
                // Reset Button
                VStack(alignment: .leading, spacing: 16) {
                    Text("설정 초기화")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button(action: {
                        resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("기본값으로 초기화")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemRed).opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }
    
    private func resetToDefaults() {
        maxAtomsLimit = 5000
        enableOptimization = false
        samplingRatio = 0.25
    }
}

struct PerformanceInfoItem: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("도움말 및 FAQ")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    FAQItem(
                        question: "앱이 느리게 실행됩니다",
                        answer: "대용량 단백질 구조의 경우 로딩 시간이 오래 걸릴 수 있습니다. 작은 단백질부터 시작해보세요."
                    )
                    
                    FAQItem(
                        question: "3D 모델이 회전하지 않습니다",
                        answer: "뷰어 모드에서 드래그 제스처를 사용하여 모델을 회전시킬 수 있습니다."
                    )
                    
                    FAQItem(
                        question: "색상이 변경되지 않습니다",
                        answer: "Color Schemes에서 원하는 색상 모드를 선택한 후 잠시 기다려주세요."
                    )
                    
                    FAQItem(
                        question: "단백질을 로드할 수 없습니다",
                        answer: "인터넷 연결을 확인하고 유효한 PDB ID를 입력했는지 확인해주세요."
                    )
                }
            }
            .padding()
        }
    }
}

struct ContactView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("문의하기")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                ContactInfoItem(
                    icon: "envelope",
                    title: "이메일",
                    value: "support@proteinapp.com",
                    action: "이메일 보내기"
                )
                
                ContactInfoItem(
                    icon: "globe",
                    title: "웹사이트",
                    value: "https://proteinapp.com",
                    action: "웹사이트 방문"
                )
                
                ContactInfoItem(
                    icon: "envelope",
                    title: "이메일",
                    value: "support@proteinapp.com",
                    action: "이메일 보내기"
                )
                
                ContactInfoItem(
                    icon: "github",
                    title: "GitHub",
                    value: "https://github.com/proteinapp",
                    action: "GitHub 방문"
                )
            }
        }
        .padding()
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("개인정보 처리방침")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    PrivacySection(
                        title: "1. 수집하는 정보",
                        content: "ProteinApp은 사용자의 개인정보를 수집하지 않습니다.\n\n• PDB ID: 단백질 구조 데이터를 다운로드하기 위한 공개 식별자로, 개인정보가 아닙니다.\n• 앱 사용 데이터: 앱 내에서 생성되는 모든 데이터는 기기에만 저장됩니다.\n• 네트워크 요청: 단백질 구조 데이터 다운로드를 위한 API 호출만 수행합니다."
                    )
                    
                    PrivacySection(
                        title: "2. 정보 사용 목적",
                        content: "• 단백질 구조 시각화 및 3D 렌더링\n• 교육 및 연구 목적의 데이터 제공\n• 앱 기능 향상을 위한 로컬 데이터 처리\n• 사용자 경험 개선을 위한 앱 내 기능 제공"
                    )
                    
                    PrivacySection(
                        title: "3. 정보 보호 및 보안",
                        content: "• 모든 데이터는 사용자 기기에만 저장됩니다.\n• 외부 서버로 개인정보가 전송되지 않습니다.\n• PDB API 호출 시에는 공개 데이터만 요청합니다.\n• 앱 삭제 시 모든 로컬 데이터가 함께 삭제됩니다."
                    )
                    
                    PrivacySection(
                        title: "4. 제3자 서비스",
                        content: "• RCSB PDB (data.rcsb.org): 단백질 구조 데이터 제공\n• PDBe (www.ebi.ac.uk): 추가 단백질 정보 제공\n• UniProt (rest.uniprot.org): 단백질 기능 정보 제공\n\n이들 서비스는 모두 공개 API이며 개인정보를 요구하지 않습니다."
                    )
                    
                    PrivacySection(
                        title: "5. 사용자 권리",
                        content: "• 데이터 삭제: 앱 삭제를 통해 모든 데이터를 삭제할 수 있습니다.\n• 데이터 수정: 앱 내에서 입력한 정보는 언제든 수정 가능합니다.\n• 문의: 개인정보 관련 문의는 앱 내 Contact 메뉴를 이용해주세요."
                    )
                    
                    PrivacySection(
                        title: "6. 정책 변경",
                        content: "개인정보 처리방침은 필요에 따라 변경될 수 있으며, 변경 시 앱 내에서 공지합니다. 마지막 업데이트: 2024년 9월 8일"
                    )
                }
            }
            .padding()
        }
    }
}

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("이용약관")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    TermsSection(
                        title: "서비스 이용",
                        content: "ProteinApp은 유료 앱입니다. 앱 다운로드 및 사용을 위해서는 App Store에서 결제가 필요합니다."
                    )
                    
                    TermsSection(
                        title: "결제 및 구독",
                        content: "• 앱 구매는 App Store를 통해 처리됩니다.\n• 일회성 결제로 앱의 모든 기능을 이용할 수 있습니다.\n• 앱 구매 후 추가 결제는 없습니다.\n• 환불은 App Store 정책에 따라 제한적입니다."
                    )
                    
                    TermsSection(
                        title: "서비스 범위",
                        content: "• 3D 단백질 구조 시각화\n• 고급 렌더링 옵션\n• 단백질 분석 도구\n• 오프라인 데이터 저장\n• 고객 지원 서비스\n• 모든 기능이 앱 구매 시 포함됩니다."
                    )
                    
                    TermsSection(
                        title: "환불 정책",
                        content: "• App Store 정책에 따라 앱 구매 환불은 제한적입니다.\n• 기술적 문제로 인한 앱 사용 불가 시에만 환불을 고려합니다.\n• 환불 요청은 App Store 또는 앱 내 고객 지원을 통해 접수해주세요.\n• 앱 구매 후 14일 이내에만 환불이 가능합니다."
                    )
                    
                    TermsSection(
                        title: "앱 업데이트 및 지원",
                        content: "• 앱 업데이트는 무료로 제공됩니다.\n• 새로운 기능 추가 시 별도 결제 없이 이용 가능합니다.\n• 앱 지원 중단 시 30일 전 사전 공지합니다.\n• 지원 중단으로 인한 데이터 손실에 대해 책임지지 않습니다."
                    )
                    
                    TermsSection(
                        title: "책임 제한",
                        content: "앱 사용으로 인한 손해에 대해 개발자는 책임지지 않습니다. 유료 앱 이용 시에도 동일하게 적용됩니다."
                    )
                    
                    TermsSection(
                        title: "앱 변경",
                        content: "앱의 기능은 사전 통지 없이 변경될 수 있습니다. 주요 기능 변경 시에는 앱 업데이트를 통해 공지합니다."
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Helper Views

struct FAQItem: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(answer)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ContactInfoItem: View {
    let icon: String
    let title: String
    let value: String
    let action: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {}) {
                Text(action)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PrivacySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct TermsSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}
