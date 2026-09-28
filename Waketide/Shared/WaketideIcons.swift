import SwiftUI

/// The design canvas's stroke icons, drawn from their original 24×24 SVG geometry so the app
/// matches the design exactly (SF Symbols are heavier and shaped differently).
enum WTIcon {
    case sparkle, alarm, calendar, list, timer, plus, close, check, mic, bell, moon, music, repeatArrows
    case chevronLeft, chevronRight, arrowRight, arrowUp, pencil, trash, pause, play, undo, appearance

    /// Stroke width in 24-unit space, as in the design.
    var defaultStroke: CGFloat {
        switch self {
        case .plus, .arrowRight, .arrowUp: return 2.2
        case .check: return 2.6
        case .bell: return 2
        default: return 1.8
        }
    }

    fileprivate var strokes: [IconElement] {
        switch self {
        case .sparkle:
            return [.path("M12 3l1.9 5.6 5.6 1.9-5.6 1.9L12 18l-1.9-5.6-5.6-1.9 5.6-1.9z"), .path("M19 16v4M17 18h4")]
        case .alarm:
            return [.circle(12, 13, 8), .path("M12 9v4l2.5 2.5"), .path("M5 3.5 2 6.5"), .path("M22 6.5l-3-3")]
        case .calendar:
            return [.rect(3, 4.5, 18, 17, 3.5), .path("M16 2.5v4M8 2.5v4M3 10h18")]
        case .list:
            return [.path("M9 6h12M9 12h12M9 18h12"), .path("M4 6h.01M4 12h.01M4 18h.01")]
        case .timer:
            return [.circle(12, 14, 8), .path("M9.5 2.5h5"), .path("M12 14l3.2-3.2")]
        case .plus:
            return [.path("M12 5v14M5 12h14")]
        case .close:
            return [.path("M6 6l12 12M18 6L6 18")]
        case .check:
            return [.path("M5 12.5l4.5 4.5L19 7")]
        case .mic:
            return [.rect(9, 3, 6, 11, 3), .path("M5.5 11a6.5 6.5 0 0013 0"), .path("M12 18v3")]
        case .bell:
            return [.path("M6 9a6 6 0 0112 0c0 6.5 2.5 8 2.5 8h-17S6 15.5 6 9"), .path("M10 20.5a2 2 0 004 0")]
        case .moon:
            return [.path("M20 14.5A8 8 0 019.5 4a8 8 0 1010.5 10.5z")]
        case .music:
            return [.path("M9 18V6l10-2v12"), .circle(6.5, 18, 2.5), .circle(16.5, 16, 2.5)]
        case .repeatArrows:
            return [.path("M17 3l3 3-3 3"), .path("M4 11V9a3 3 0 013-3h13"), .path("M7 21l-3-3 3-3"), .path("M20 13v2a3 3 0 01-3 3H4")]
        case .chevronLeft:
            return [.path("M15 5l-7 7 7 7")]
        case .chevronRight:
            return [.path("M9 5l7 7-7 7")]
        case .arrowRight:
            return [.path("M5 12h14M13 6l6 6-6 6")]
        case .arrowUp:
            return [.path("M12 19V5M6 11l6-6 6 6")]
        case .pencil:
            return [.path("M4 20l1-4L16.5 4.5a2.1 2.1 0 013 3L8 19z"), .path("M14.5 6.5l3 3")]
        case .trash:
            return [.path("M4 7h16"), .path("M9 7V4.5h6V7"), .path("M6.5 7l.8 12.5h9.4L17.5 7"), .path("M10 11v5M14 11v5")]
        case .undo:
            return [.path("M9 14L4 9l5-5"), .path("M4 9h11a5 5 0 010 10h-3")]
        case .appearance:
            return [.circle(12, 12, 8.5)]
        case .pause, .play:
            return []
        }
    }

    fileprivate var fills: [IconElement] {
        switch self {
        case .pause: return [.rect(6.5, 5, 4, 14, 1.2), .rect(13.5, 5, 4, 14, 1.2)]
        case .play: return [.path("M8 5.2v13.6a1 1 0 001.5.86l11-6.8a1 1 0 000-1.72l-11-6.8A1 1 0 008 5.2z")]
        case .appearance: return [.path("M12 3.5a8.5 8.5 0 000 17z")]
        default: return []
        }
    }
}

/// An icon at a given point size, in the current foreground style.
struct IconGlyph: View {
    let icon: WTIcon
    var size: CGFloat = 22
    var stroke: CGFloat? = nil

    var body: some View {
        let width = (stroke ?? icon.defaultStroke) * size / 24
        ZStack {
            IconShape(elements: icon.strokes)
                .stroke(style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            IconShape(elements: icon.fills).fill()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Geometry

fileprivate enum IconElement {
    case path(String)
    case circle(CGFloat, CGFloat, CGFloat)
    case rect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
}

fileprivate struct IconShape: Shape {
    let elements: [IconElement]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for e in elements {
            switch e {
            case .path(let d): p.addPath(SVGPathData.path(d))
            case let .circle(cx, cy, r): p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            case let .rect(x, y, w, h, r): p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r))
            }
        }
        let s = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(scaleX: s, y: s))
            .offsetBy(dx: rect.minX + (rect.width - 24 * s) / 2, dy: rect.minY + (rect.height - 24 * s) / 2)
    }
}

/// A small SVG path-data parser (M L H V C S A Z, absolute and relative), enough for the icons above.
enum SVGPathData {
    private static var cache: [String: Path] = [:]
    private static let lock = NSLock()

    static func path(_ d: String) -> Path {
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[d] { return hit }
        let p = parse(d)
        cache[d] = p
        return p
    }

    private static func parse(_ d: String) -> Path {
        var path = Path()
        let c = Array(d.utf8)
        var i = 0
        var cmd: UInt8 = 0
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var lastCtrl: CGPoint?

        func skip() { while i < c.count, c[i] == 32 || c[i] == 44 || c[i] == 10 || c[i] == 9 || c[i] == 13 { i += 1 } }
        func isLetter(_ x: UInt8) -> Bool { (x >= 65 && x <= 90 && x != 69) || (x >= 97 && x <= 122 && x != 101) }
        func num() -> CGFloat? {
            skip()
            guard i < c.count else { return nil }
            let s = i
            if c[i] == 43 || c[i] == 45 { i += 1 }
            var dot = false, digit = false
            while i < c.count {
                let x = c[i]
                if x >= 48 && x <= 57 { digit = true; i += 1 }
                else if x == 46 && !dot { dot = true; i += 1 }
                else if (x == 101 || x == 69) && digit {
                    i += 1
                    if i < c.count, c[i] == 43 || c[i] == 45 { i += 1 }
                    while i < c.count, c[i] >= 48 && c[i] <= 57 { i += 1 }
                    break
                } else { break }
            }
            guard digit, let v = Double(String(decoding: c[s..<i], as: UTF8.self)) else { i = s; return nil }
            return CGFloat(v)
        }
        func flag() -> Bool? {
            skip()
            guard i < c.count, c[i] == 48 || c[i] == 49 else { return nil }
            defer { i += 1 }
            return c[i] == 49
        }

        while true {
            skip()
            guard i < c.count else { break }
            if isLetter(c[i]) { cmd = c[i]; i += 1 } else if cmd == 0 { break }
            let rel = cmd >= 97
            let o = rel ? cur : .zero
            var ctrl: CGPoint?
            switch cmd | 0x20 {
            case UInt8(ascii: "m"):
                guard let x = num(), let y = num() else { return path }
                cur = CGPoint(x: o.x + x, y: o.y + y); start = cur
                path.move(to: cur)
                cmd = rel ? UInt8(ascii: "l") : UInt8(ascii: "L")
            case UInt8(ascii: "l"):
                guard let x = num(), let y = num() else { return path }
                cur = CGPoint(x: o.x + x, y: o.y + y); path.addLine(to: cur)
            case UInt8(ascii: "h"):
                guard let x = num() else { return path }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y); path.addLine(to: cur)
            case UInt8(ascii: "v"):
                guard let y = num() else { return path }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y); path.addLine(to: cur)
            case UInt8(ascii: "c"):
                guard let x1 = num(), let y1 = num(), let x2 = num(), let y2 = num(), let x = num(), let y = num() else { return path }
                let c2 = CGPoint(x: o.x + x2, y: o.y + y2)
                cur = CGPoint(x: o.x + x, y: o.y + y)
                path.addCurve(to: cur, control1: CGPoint(x: o.x + x1, y: o.y + y1), control2: c2)
                ctrl = c2
            case UInt8(ascii: "s"):
                guard let x2 = num(), let y2 = num(), let x = num(), let y = num() else { return path }
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: o.x + x2, y: o.y + y2)
                cur = CGPoint(x: o.x + x, y: o.y + y)
                path.addCurve(to: cur, control1: c1, control2: c2)
                ctrl = c2
            case UInt8(ascii: "a"):
                guard let rx = num(), let ry = num(), let rot = num(), let large = flag(), let sweep = flag(),
                      let x = num(), let y = num() else { return path }
                let end = CGPoint(x: o.x + x, y: o.y + y)
                addArc(&path, from: cur, rx: rx, ry: ry, degrees: rot, large: large, sweep: sweep, to: end)
                cur = end
            case UInt8(ascii: "z"):
                path.closeSubpath(); cur = start; cmd = 0
            default:
                return path
            }
            lastCtrl = ctrl
        }
        return path
    }

    /// SVG elliptical arc, converted to cubic Béziers (SVG 1.1 appendix F.6.5).
    private static func addArc(_ path: inout Path, from p0: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat,
                               degrees: CGFloat, large: Bool, sweep: Bool, to p1: CGPoint) {
        guard p0 != p1 else { return }
        var rx = abs(rxIn), ry = abs(ryIn)
        guard rx > 0, ry > 0 else { path.addLine(to: p1); return }
        let phi = degrees * .pi / 180, cp = cos(phi), sp = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy
        let lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lam > 1 { rx *= sqrt(lam); ry *= sqrt(lam) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var k = den == 0 ? 0 : sqrt(max(0, num / den))
        if large == sweep { k = -k }
        let cxp = k * rx * y1 / ry, cyp = -k * ry * x1 / rx
        let cx = cp * cxp - sp * cyp + (p0.x + p1.x) / 2
        let cy = sp * cxp + cp * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat { atan2(ux * vy - uy * vx, ux * vx + uy * vy) }
        let t1 = angle(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var dt = angle((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let n = max(1, Int(ceil(abs(dt) / (.pi / 2))))
        let step = dt / CGFloat(n)
        let a = 4.0 / 3.0 * tan(step / 4)
        func point(_ t: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cos(t) * cp - ry * sin(t) * sp, y: cy + rx * cos(t) * sp + ry * sin(t) * cp)
        }
        func deriv(_ t: CGFloat) -> CGPoint {
            CGPoint(x: -rx * sin(t) * cp - ry * cos(t) * sp, y: -rx * sin(t) * sp + ry * cos(t) * cp)
        }
        var t = t1
        for _ in 0..<n {
            let t2 = t + step
            let s = point(t), e = point(t2), d1 = deriv(t), d2 = deriv(t2)
            path.addCurve(to: e,
                          control1: CGPoint(x: s.x + a * d1.x, y: s.y + a * d1.y),
                          control2: CGPoint(x: e.x - a * d2.x, y: e.y - a * d2.y))
            t = t2
        }
    }
}
