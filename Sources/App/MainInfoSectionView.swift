import SwiftUI

struct MainInfoSectionView: View {
    let protein: ProteinInfo
    @Binding var showingPDBWebsite: Bool

    var body: some View {
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
                        // TODO: UniProt 링크
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

    // MARK: - Local helpers
    private func diseaseItem(name: String, severity: String, color: Color) -> some View {
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

    private func researchStatusItem(title: String, count: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(count).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}