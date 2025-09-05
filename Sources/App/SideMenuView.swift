import SwiftUI

struct SideMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: MenuItemType? = nil
    @State private var showingDetailView = false
    
    var body: some View {
        NavigationView {
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
                                selectedItem = item
                                showingDetailView = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                
                // 하단 라이센스 정보
                licenseFooter
            }
            .navigationBarHidden(true)
        }
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
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
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
