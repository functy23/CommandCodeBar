import AppKit

/// 菜单栏状态图标（template 黑色 + alpha，系统自动适配深浅色菜单栏）。
/// 图标与文字混排时 SwiftUI 在 MenuBarExtra 中没有布局控制、无法对齐，
/// 因此"图标 + 百分比"统一预合成为一张图，文字基线按字体度量精确对齐图标中心。
enum StatusItemIcon {
    /// 三根升序圆角柱（无百分比时使用）
    static var bars: NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            drawBarsShape()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 进度环：粗环为剩余比例，从 12 点方向顺时针。
    /// 外径约 13.5pt，贴近菜单栏文字高度
    static func ring(remaining: Double) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            drawRingShape(remaining: remaining)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 环 + 百分比文字，合成一张图
    static func ringWithText(remaining: Double, text: String) -> NSImage {
        combinedIcon(text: text) {
            drawRingShape(remaining: remaining)
        }
    }

    /// 柱状图标 + 额度文字，合成一张图
    static func barsWithText(text: String) -> NSImage {
        combinedIcon(text: text) {
            drawBarsShape()
        }
    }

    // MARK: - 合成

    /// 在 18pt 高的画布里先画图标，再在其右侧绘制文字；
    /// 文字基线 = 画布中线 - capHeight/2，使数字的视觉中心与图标中心严格重合
    private static func combinedIcon(text: String, drawIconIn18: @escaping () -> Void) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: NSColor.black]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let textWidth = ceil(CTLineGetTypographicBounds(line, nil, nil, nil))
        let capHeight = font.capHeight

        let height: CGFloat = 18
        let iconArea: CGFloat = 18
        let gap: CGFloat = 3
        let width = ceil(iconArea + gap + textWidth) + 2
        let centerY = height / 2

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let context = NSGraphicsContext.current!.cgContext
            context.saveGState()
            context.translateBy(x: 0, y: centerY - 9)
            drawIconIn18()
            context.restoreGState()

            context.textPosition = CGPoint(x: iconArea + gap, y: centerY - capHeight / 2)
            CTLineDraw(line, context)
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - 图形绘制（在 18×18 逻辑区域内，中心 (9, 9)）

    private static func drawRingShape(remaining: Double) {
        let lineWidth: CGFloat = 2
        let inset: CGFloat = 3.25
        let trackRect = NSRect(x: 0, y: 0, width: 18, height: 18).insetBy(dx: inset, dy: inset)

        let track = NSBezierPath(ovalIn: trackRect)
        track.lineWidth = lineWidth
        NSColor.black.withAlphaComponent(0.3).setStroke()
        track.stroke()

        let fraction = min(max(remaining, 0.02), 1)
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: NSPoint(x: trackRect.midX, y: trackRect.midY),
            radius: trackRect.width / 2,
            startAngle: 90,
            endAngle: 90 - 360 * fraction,
            clockwise: true
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        NSColor.black.setStroke()
        arc.stroke()
    }

    private static func drawBarsShape() {
        NSColor.black.setFill()
        let barWidth: CGFloat = 3
        let gap: CGFloat = 1.5
        let startX = (18 - (barWidth * 3 + gap * 2)) / 2
        let heights: [CGFloat] = [7, 10, 13]
        for (index, height) in heights.enumerated() {
            let x = startX + CGFloat(index) * (barWidth + gap)
            let bar = NSBezierPath(
                roundedRect: NSRect(x: x, y: 2.5, width: barWidth, height: height),
                xRadius: 1.5,
                yRadius: 1.5
            )
            bar.fill()
        }
    }
}
