import SwiftUI

/// Formula → image. The real formula engine lands in later phases;
/// for now this shows a fixed heart-curve demo so the tab isn't empty.
struct DrawView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            ZStack {
                appModel.renderSettings.backgroundColor.ignoresSafeArea()

                Canvas { context, size in
                    let path = Self.demoHeartPath(in: size)
                    context.stroke(
                        path,
                        with: .color(appModel.renderSettings.strokeColor),
                        lineWidth: appModel.renderSettings.strokeWidth
                    )
                }
                .padding(24)

                VStack {
                    Spacer()
                    HStack {
                        caption("수식 엔진 준비 중 — 데모 곡선")
                        Spacer()
                    }
                }
                .padding(12)
                .allowsHitTesting(false)
            }
            .navigationTitle("그리기")
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }

    /// x(t) = 16 sin³t, y(t) = 13 cos t − 5 cos 2t − 2 cos 3t − cos 4t
    static func demoHeartPath(in size: CGSize) -> Path {
        var path = Path()
        let steps = 300
        let scale = min(size.width, size.height) / 36
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
            let point = CGPoint(x: center.x + x * scale, y: center.y + y * scale)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    DrawView()
        .environment(AppModel())
}
