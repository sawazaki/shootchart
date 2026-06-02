import SwiftUI

// SVG viewBox: 942×540. Court boundary: x=40–906, y=39–504.
private enum Court {
    static let svgAspect: CGFloat = 942.0 / 540.0
    static let left:   CGFloat = 40.0  / 942.0
    static let right:  CGFloat = 906.0 / 942.0
    static let top:    CGFloat = 39.0  / 540.0
    static let bottom: CGFloat = 504.0 / 540.0
}

struct CourtView: View {
    let shots: [Shot]
    let selectedShotId: UUID?
    let filterQuarter: Int?
    let filterPlayerId: UUID?

    var onTap: (CGPoint) -> Void
    var onShotTap: (Shot) -> Void

    var body: some View {
        GeometryReader { geo in
            let imgRect   = imageRect(in: geo.size)
            let courtRect = courtRect(in: geo.size)
            ZStack {
                Color(white: 0.92)
                Image("basketball-court")
                    .resizable()
                    .frame(width: imgRect.width, height: imgRect.height)
                    .position(x: imgRect.midX, y: imgRect.midY)
                ForEach(visibleShots, id: \.id) { shot in
                    shotMarker(shot: shot, courtRect: courtRect)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let loc = value.location
                        if let hit = hitShot(at: loc, courtRect: courtRect) {
                            onShotTap(hit)
                        } else if courtRect.contains(loc) {
                            onTap(normalize(point: loc, in: courtRect))
                        }
                    }
            )
        }
    }

    private var visibleShots: [Shot] {
        shots.filter { shot in
            guard filterQuarter == nil || shot.quarter == filterQuarter else { return false }
            guard let pid = filterPlayerId else { return true }
            if pid == Shot.ownTeamFilterId { return !shot.isOpponent }
            return shot.playerId == pid
        }
    }

    // SVG 画像全体の表示 rect（アスペクト比 942:540 を維持）
    private func imageRect(in size: CGSize) -> CGRect {
        let w = min(size.width, size.height * Court.svgAspect)
        let h = w / Court.svgAspect
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    // SVG 内のコート境界（ショットマーカー・タップ判定に使用）
    private func courtRect(in size: CGSize) -> CGRect {
        let img = imageRect(in: size)
        return CGRect(
            x: img.minX + Court.left  * img.width,
            y: img.minY + Court.top   * img.height,
            width:  (Court.right  - Court.left)  * img.width,
            height: (Court.bottom - Court.top)   * img.height
        )
    }

    private func normalize(point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: (point.x - rect.minX) / rect.width,
                y: (point.y - rect.minY) / rect.height)
    }

    private func toScreen(norm: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + norm.x * rect.width,
                y: rect.minY + norm.y * rect.height)
    }

    private func hitShot(at point: CGPoint, courtRect: CGRect) -> Shot? {
        visibleShots.first { shot in
            let sp = toScreen(norm: CGPoint(x: shot.x, y: shot.y), in: courtRect)
            return hypot(sp.x - point.x, sp.y - point.y) < 22
        }
    }

    private func markerColor(for shot: Shot, isSelected: Bool) -> Color {
        if isSelected { return .yellow }
        if shot.shotType == ShotType.traveling.rawValue || shot.shotType == ShotType.turnOver.rawValue {
            return .orange
        }
        if shot.isOpponent {
            if shot.shotType == ShotType.freeThrow.rawValue {
                return shot.isMade ? .teal : .brown
            }
            return shot.isMade ? .purple : .gray
        }
        if shot.shotType == ShotType.freeThrow.rawValue {
            return shot.isMade ? .blue : .orange
        }
        return shot.isMade ? .green : .red
    }

    @ViewBuilder
    private func shotMarker(shot: Shot, courtRect: CGRect) -> some View {
        let pos = toScreen(norm: CGPoint(x: shot.x, y: shot.y), in: courtRect)
        let isSelected = shot.id == selectedShotId
        let size: CGFloat = isSelected ? 40 : 32
        let lineWidth: CGFloat = isSelected ? 5 : 4
        let fontSize: CGFloat = isSelected ? 12 : 10
        let color = markerColor(for: shot, isSelected: isSelected)

        ZStack {
            if shot.isMade {
                Circle()
                    .stroke(color, lineWidth: lineWidth)
                    .frame(width: size, height: size)
                if isSelected {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: size, height: size)
                }
            } else {
                XShape(gapRadius: fontSize * 0.9)
                    .stroke(color, lineWidth: lineWidth)
                    .frame(width: size, height: size)
            }
            Text(shot.playerNumber)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(color)
        }
        .position(pos)
    }
}

// MARK: - Shapes

private struct XShape: Shape {
    var gapRadius: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.15
        let cx = rect.midX
        let cy = rect.midY
        let d = gapRadius / sqrt(2)

        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        p.addLine(to: CGPoint(x: cx - d, y: cy - d))
        p.move(to: CGPoint(x: cx + d, y: cy + d))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))

        p.move(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        p.addLine(to: CGPoint(x: cx + d, y: cy - d))
        p.move(to: CGPoint(x: cx - d, y: cy + d))
        p.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))

        return p
    }
}
