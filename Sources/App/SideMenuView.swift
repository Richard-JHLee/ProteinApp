import SwiftUI

struct SideMenuView: View {
    @Binding var isPresented: Bool
    @State private var selectedItem: MenuItemType? = nil
    @State private var showingDetailView = false
    @State private var isProcessing = false // 중복 탭 방지
    
    init(isPresented: Binding<Bool> = .constant(false)) {
        self._isPresented = isPresented
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            menuHeader
            
            // 메뉴 아이템 리스트
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(MenuItemType.allCases, id: \.self) { item in
                                                    MenuItemRow(
                                item: item,
                                isSelected: selectedItem == item
                            ) {
                                guard !isProcessing else { return }
                                isProcessing = true
                                selectedItem = item
                                showingDetailView = true
                                // 메뉴 아이템 선택 시 사이드 메뉴 닫기
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isPresented = false
                                }
                                // 애니메이션 완료 후 처리 상태 리셋
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isProcessing = false
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            
            // 하단 라이센스 정보
            licenseFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingDetailView) {
            if let item = selectedItem {
                MenuDetailView(item: item)
            }
        }
    }
    
    // MARK: - Header
    private var menuHeader: some View {
        VStack(spacing: 16) {
            // 앱 로고 및 제목
            HStack(spacing: 16) {
                Image(systemName: "atom")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ProteinApp")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("3D Protein Viewer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 닫기 버튼
                Button(action: { 
                    guard !isProcessing else { return }
                    isProcessing = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                    // 애니메이션 완료 후 처리 상태 리셋
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isProcessing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .disabled(isProcessing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8) // Safe Area 고려하여 조정
            
            // 구분선
            Divider()
                .padding(.horizontal, 20)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Footer
    private var licenseFooter: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                Text("© 2024 ProteinApp")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("All rights reserved")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
    }
}
