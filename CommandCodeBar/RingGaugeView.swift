import SwiftUI

/// 面板中的进度环：显示剩余比例，颜色随余量变化（充足→绿、偏低→橙、告急→红）
struct RingGaugeView: View {
    var remaining: Double
    var lineWidth: CGFloat = 9

    private var color: Color {
        if remaining > 0.5 { return .green }
        if remaining > 0.2 { return .orange }
        return .red
    }

    var body: some View {
        let fraction = min(max(remaining, 0.015), 1)
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeInOut(duration: 0.4), value: fraction)
    }
}
