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
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title)
                .fontWeight(.bold)
            
            Text("앱 설정 기능은 추후 업데이트에서 제공될 예정입니다.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
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
                        title: "수집하는 정보",
                        content: "ProteinApp은 개인정보를 수집하지 않습니다. 앱 내에서 입력하는 PDB ID는 단백질 구조를 다운로드하는 목적으로만 사용됩니다."
                    )
                    
                    PrivacySection(
                        title: "정보 사용",
                        content: "수집된 정보는 단백질 구조 시각화 및 교육 목적으로만 사용됩니다."
                    )
                    
                    PrivacySection(
                        title: "정보 보호",
                        content: "모든 데이터는 로컬에 저장되며 외부로 전송되지 않습니다."
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
                        content: "ProteinApp은 유료 서비스입니다. 서비스 이용을 위해서는 구독 또는 일회성 결제가 필요합니다."
                    )
                    
                    TermsSection(
                        title: "결제 및 구독",
                        content: "• 구독 결제는 App Store를 통해 처리됩니다.\n• 구독은 자동 갱신되며, 갱신 24시간 전에 취소할 수 있습니다.\n• 일회성 결제는 환불이 불가능합니다.\n• 구독 취소는 App Store 설정에서 가능합니다."
                    )
                    
                    TermsSection(
                        title: "서비스 범위",
                        content: "• 기본 단백질 구조 보기: 무료\n• 고급 3D 렌더링: 유료\n• 고급 분석 도구: 유료\n• 클라우드 저장: 유료\n• 우선 고객 지원: 유료"
                    )
                    
                    TermsSection(
                        title: "환불 정책",
                        content: "• App Store 정책에 따라 구독 환불은 제한적입니다.\n• 기술적 문제로 인한 서비스 장애 시에만 환불을 고려합니다.\n• 환불 요청은 앱 내 고객 지원을 통해 접수해주세요."
                    )
                    
                    TermsSection(
                        title: "서비스 중단",
                        content: "• 서비스 중단 시 30일 전 사전 공지합니다.\n• 중단 시 미사용 구독료는 환불됩니다.\n• 서비스 중단으로 인한 데이터 손실에 대해 책임지지 않습니다."
                    )
                    
                    TermsSection(
                        title: "책임 제한",
                        content: "앱 사용으로 인한 손해에 대해 개발자는 책임지지 않습니다. 유료 서비스 이용 시에도 동일하게 적용됩니다."
                    )
                    
                    TermsSection(
                        title: "서비스 변경",
                        content: "서비스는 사전 통지 없이 변경될 수 있습니다. 유료 기능의 변경 시에는 7일 전 공지합니다."
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
