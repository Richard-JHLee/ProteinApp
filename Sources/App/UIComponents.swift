import SwiftUI

struct GlassCard<Content: View>: View {
    var content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
                    Text(title).font(.headline.weight(.semibold))
                    Spacer()
                }
                content()
            }
            .padding(16)
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