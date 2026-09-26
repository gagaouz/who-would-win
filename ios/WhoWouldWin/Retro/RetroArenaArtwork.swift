import UIKit

/// Tiny original pixel landscapes, drawn once per arena and reused as textures.
enum RetroArenaArtwork {
    static func image(for environment: BattleEnvironment) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 480, height: 280), format: format).image { renderer in
            let c = renderer.cgContext
            c.setAllowsAntialiasing(false)
            c.interpolationQuality = .none
            let p = palette(environment)
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UInt32) {
                c.setFillColor(rgb(color).cgColor)
                c.fill(CGRect(x: x.rounded(), y: y.rounded(), width: w.rounded(), height: h.rounded()))
            }
            func polygon(_ points: [(CGFloat, CGFloat)], _ color: UInt32) {
                guard let first = points.first else { return }
                c.beginPath(); c.move(to: CGPoint(x: first.0, y: first.1))
                for point in points.dropFirst() { c.addLine(to: CGPoint(x: point.0, y: point.1)) }
                c.closePath(); c.setFillColor(rgb(color).cgColor); c.fillPath()
            }
            func disk(_ x: CGFloat, _ y: CGFloat, _ radius: Int, _ color: UInt32) {
                for row in stride(from: -radius, through: radius, by: 2) {
                    let half = CGFloat(sqrt(max(0, Double(radius * radius - row * row)))).rounded()
                    rect(x - half, y + CGFloat(row), half * 2, 2, color)
                }
            }
            rect(0, 0, 480, 280, p.sky)
            rect(0, 75, 480, 90, p.haze)
            if environment == .night {
                disk(354, 49, 25, 0xece3b1); disk(363, 42, 23, p.sky)
                for i in 0..<42 {
                    rect(CGFloat((i * 107 + 23) % 474), CGFloat((i * 43 + 17) % 132), 2, 2, i % 3 == 0 ? 0xd8e9c5 : 0x819cb1)
                }
            } else if environment != .ocean && environment != .storm {
                disk(264, 59, 31, p.sun); disk(264, 57, 24, 0xffedb3)
            }
            if environment == .ocean {
                for i in 0..<5 {
                    polygon([(CGFloat(i * 100), 0), (CGFloat(i * 100 + 22), 0), (CGFloat(i * 100 + 106), 188), (CGFloat(i * 100 + 79), 188)], 0x438e9b)
                }
                for i in 0..<16 {
                    let x = CGFloat((i * 79 + 11) % 480), y = CGFloat(36 + (i * 23) % 125)
                    rect(x, y, 3, 1, 0x91c8ba); rect(x - 1, y + 1, 1, 3, 0x91c8ba)
                }
            } else {
                let cloud: UInt32 = environment == .storm ? 0x737d88 : 0xf5e8c7
                rect(37, 43, 68, 5, cloud); rect(49, 39, 34, 4, cloud)
                rect(353, 65, 81, 5, cloud); rect(374, 61, 38, 4, cloud)
            }
            polygon([(0, 167), (0, 137), (39, 132), (80, 112), (109, 117), (158, 135), (206, 127), (258, 112), (294, 119), (341, 130), (391, 108), (431, 118), (480, 133), (480, 185)], p.far)
            polygon([(0, 194), (0, 163), (45, 157), (89, 166), (146, 147), (191, 158), (231, 164), (277, 146), (321, 151), (365, 164), (422, 149), (480, 154), (480, 216)], p.near)
            if environment == .volcano {
                polygon([(150, 173), (224, 82), (244, 83), (318, 177)], 0x64505b)
                polygon([(212, 99), (224, 82), (244, 83), (257, 103), (244, 100), (235, 92), (225, 102)], 0xee9560)
                polygon([(231, 96), (237, 96), (246, 155), (241, 165), (238, 128)], 0xf2ab67)
            }
            if environment == .arctic {
                polygon([(34, 137), (80, 112), (109, 117), (135, 128), (111, 125), (99, 132), (78, 122), (59, 134)], 0xe4eee0)
                polygon([(358, 125), (391, 108), (415, 115), (429, 127), (400, 121), (390, 116), (375, 125)], 0xe4eee0)
            }
            if environment == .grassland || environment == .jungle || environment == .night {
                for (x, y, scale) in [(CGFloat(51), CGFloat(170), CGFloat(1)), (421, 174, 0.8)] {
                    rect(x - 2, y - 32 * scale, 4, 33 * scale, p.near)
                    rect(x - 15 * scale, y - 35 * scale, 31 * scale, 5, p.near)
                    rect(x - 29 * scale, y - 40 * scale, 56 * scale, 7, p.near)
                    rect(x - 21 * scale, y - 44 * scale, 37 * scale, 5, p.near)
                    if environment == .jungle {
                        rect(x - 11, y - 30, 2, 26, p.far)
                        rect(x + 14, y - 34, 2, 37, p.far)
                    }
                }
            }
            if environment == .desert {
                for x in [CGFloat(46), CGFloat(432)] {
                    rect(x, 152, 5, 36, 0x657e65); rect(x - 9, 167, 10, 5, 0x657e65)
                    rect(x - 9, 157, 4, 12, 0x657e65); rect(x + 5, 161, 9, 4, 0x657e65)
                    rect(x + 10, 151, 4, 14, 0x657e65)
                }
            }
            rect(0, 197, 480, 31, p.grass)
            rect(0, 225, 480, 55, p.ground)
            rect(0, 225, 480, 4, p.trim)
            for i in 0..<83 {
                let x = CGFloat((i * 127 + 41) % 480)
                let y = CGFloat(204 + (i * 23) % 23)
                rect(x, y, 2 + CGFloat(i % 3), 2 + CGFloat(i % 4), i % 3 == 0 ? p.trim : p.near)
            }
            for i in 0..<40 {
                rect(CGFloat((i * 71 + 18) % 480), CGFloat(236 + (i * 17) % 39), CGFloat(2 + i % 4), 1, p.trim)
            }
            if environment == .sky {
                // Soft cloud shelves support every selected creature without
                // assigning a flight capability or changing arena rules.
                for x in [CGFloat(72), CGFloat(330)] {
                    rect(x, 222, 83, 9, 0xe4ebcd); rect(x + 13, 218, 55, 4, 0xf7edce)
                }
            }
            if environment == .ocean {
                for x in [CGFloat(19), CGFloat(452)] {
                    rect(x, 206, 4, 33, 0x5d8c78); rect(x - 5, 218, 8, 5, 0x5d8c78)
                    rect(x + 4, 212, 7, 4, 0x5d8c78)
                }
            }
            polygon([(0, 253), (22, 252), (37, 261), (58, 258), (80, 271), (112, 280), (0, 280)], p.foreground)
            polygon([(480, 248), (458, 253), (442, 250), (417, 263), (392, 266), (360, 280), (480, 280)], p.foreground)
        }
    }

    static func rgb(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    private struct Palette {
        let sky, haze, sun, far, near, grass, ground, trim, foreground: UInt32
    }

    private static func palette(_ e: BattleEnvironment) -> Palette {
        switch e {
        case .grassland: return Palette(sky: 0xf0e3b8, haze: 0xf3dda0, sun: 0xf8d785, far: 0xb0b77f, near: 0x728c62, grass: 0x829650, ground: 0xb49361, trim: 0xc4ac71, foreground: 0x3e6546)
        case .ocean: return Palette(sky: 0x37788d, haze: 0x3b8191, sun: 0xadd9cd, far: 0x367888, near: 0x346e74, grass: 0x678c78, ground: 0xa5a779, trim: 0xbbbc87, foreground: 0x355b61)
        case .sky: return Palette(sky: 0x91b6c5, haze: 0xbbd2c7, sun: 0xf8dc9a, far: 0xa3b9b1, near: 0xb0c8be, grass: 0xccd9c4, ground: 0xbacfc4, trim: 0xe2e7cc, foreground: 0x8faea8)
        case .arctic: return Palette(sky: 0xb5cdd1, haze: 0xd5e0d3, sun: 0xe9dfa8, far: 0x96b3bc, near: 0x7597a4, grass: 0xc0d2cb, ground: 0xd9dfcf, trim: 0xf0ead7, foreground: 0x6e929b)
        case .desert: return Palette(sky: 0xefcfac, haze: 0xf2d5a2, sun: 0xf2b768, far: 0xd7b487, near: 0xbb9570, grass: 0xc4a074, ground: 0xd2ab78, trim: 0xe4c38d, foreground: 0x8c7957)
        case .jungle: return Palette(sky: 0xc8d2a6, haze: 0xd6d7a4, sun: 0xece0a4, far: 0x91ad7a, near: 0x577f60, grass: 0x63894c, ground: 0x8b8051, trim: 0xa7a361, foreground: 0x335e45)
        case .volcano: return Palette(sky: 0xbdacaa, haze: 0xd0aaa0, sun: 0xefbe85, far: 0x927c80, near: 0x76616c, grass: 0x786958, ground: 0x8e715e, trim: 0xba956e, foreground: 0x504f51)
        case .night: return Palette(sky: 0x253746, haze: 0x354e58, sun: 0xe5d99e, far: 0x486469, near: 0x365c57, grass: 0x426b54, ground: 0x6a775b, trim: 0x91a36c, foreground: 0x234a43)
        case .storm: return Palette(sky: 0x8c989f, haze: 0xabb1ad, sun: 0xe5d7a4, far: 0x83989a, near: 0x617d7b, grass: 0x6b8563, ground: 0x918d6d, trim: 0xb0ad7d, foreground: 0x405f55)
        }
    }
}
