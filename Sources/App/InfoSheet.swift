import SwiftUI

struct InfoSheet: View {
    let protein: ProteinInfo
    let onProteinSelected: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingProteinView = false
    @State private var showingPDBWebsite = false
    
    init(protein: ProteinInfo, onProteinSelected: ((String) -> Void)? = nil) {
        self.protein = protein
        self.onProteinSelected = onProteinSelected
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1) 헤더(미니 히어로 카드)
                    headerSection
                    
                    // 2) 주요 정보 카드들(요약/링크/질병/연구)
                    mainInfoSection
                    
                    // --- 아래는 기존 섹션 유지/교체 선택 ---
                    detailedInfoSection
                    additionalInfoSection
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Protein Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingProteinView) {
            ProteinViewSheet(proteinId: protein.id)
        }
        .sheet(isPresented: $showingPDBWebsite) {
            PDBWebsiteSheet(proteinId: protein.id)
        }
    }
}

// MARK: - Header Section (NavigationView 유지)
private extension InfoSheet {
    var headerSection: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 16) {
                GradientIcon(systemName: protein.category.icon,
                             base: protein.category.color)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text(protein.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        CapsuleTag(text: "PDB \(protein.id)",
                                   foreground: protein.category.color,
                                   background: protein.category.color.opacity(0.12),
                                   icon: "barcode.viewfinder")
                        CapsuleTag(text: protein.category.rawValue,
                                   foreground: .white,
                                   background: protein.category.color.opacity(0.9),
                                   icon: "tag.fill")
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 8)
            }
        }
        .padding(.top, 6)
    }
    
    var mainInfoSection: some View {
        VStack(spacing: 14) {
            // 기능 요약
            InfoCard(icon: "function",
                     title: "Function Summary",
                     tint: protein.category.color) {
                Text(protein.description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 핵심 포인트
            HStack(spacing: 10) {
                MetricPill(title: "Structure", value: "1→4 단계", icon: "square.grid.2x2")
                MetricPill(title: "Coloring",  value: "Element/Chain/SS", icon: "paintbrush")
                MetricPill(title: "Interact",  value: "Rotate/Zoom/Slice", icon: "hand.tap")
            }

            // 외부 리소스
            InfoCard(icon: "link",
                     title: "External Resources",
                     tint: .blue) {
                VStack(spacing: 10) {
                    LinkRow(
                        title: "View on PDB Website",
                        subtitle: "rcsb.org/structure/\(protein.id)",
                        systemImage: "globe",
                        tint: .blue
                    ) { showingPDBWebsite = true }

                    LinkRow(
                        title: "View on UniProt",
                        subtitle: "Protein sequence & function",
                        systemImage: "database",
                        tint: .green
                    ) {
                        // TODO: UniProt 링크 구현
                    }
                }
            }

            // 질병 연관성
            InfoCard(icon: "cross.case",
                     title: "Disease Association",
                     tint: .orange) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This protein is associated with several diseases:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 6) {
                        diseaseItem(name: "Inflammatory diseases", severity: "Moderate", color: .orange)
                        diseaseItem(name: "Autoimmune disorders",  severity: "High",    color: .red)
                        diseaseItem(name: "Metabolic syndrome",     severity: "Low",     color: .blue)
                    }
                }
            }

            // 연구 상태
            InfoCard(icon: "flask.fill",
                     title: "Research Status",
                     tint: .purple) {
                HStack(spacing: 12) {
                    researchStatusItem(title: "Active Studies",  count: "12", color: .green)
                    researchStatusItem(title: "Clinical Trials", count: "3",  color: .blue)
                    researchStatusItem(title: "Publications",    count: "47", color: .purple)
                }
            }
        }
    }
}

// MARK: - 기존 helper(필요 최소 포함) + 재사용 컴포넌트
private extension InfoSheet {
    func diseaseItem(name: String, severity: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(.caption).foregroundStyle(.primary)
            Spacer()
            Text(severity)
                .font(.caption2)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
    
    func researchStatusItem(title: String, count: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(count).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Pretty UI Components
struct GlassCard<Content: View>: View {
    var content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content().padding(16)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

struct GradientIcon: View {
    let systemName: String
    let base: Color
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [base.opacity(0.28), base.opacity(0.12)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(base.opacity(0.25), lineWidth: 1))
                .shadow(color: base.opacity(0.25), radius: 8, x: 0, y: 4)
            Image(systemName: systemName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(base)
        }
    }
}

struct CapsuleTag: View {
    let text: String
    let foreground: Color
    let background: Color
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.caption) }
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(foreground)
        .background(background, in: Capsule(style: .continuous))
    }
}

struct InfoCard<Content: View>: View {
    let icon: String
    let title: String
    let tint: Color
    var content: () -> Content
    init(icon: String, title: String, tint: Color, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon; self.title = title; self.tint = tint; self.content = content
    }
    var body: some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
                Text(title).font(.headline.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, 8)
            content()
        }
    }
}

struct LinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.medium)).foregroundStyle(tint)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square").foregroundStyle(tint)
            }
            .padding(14)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Text(value).font(.callout.weight(.semibold)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}