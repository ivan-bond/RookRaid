import SwiftUI

// MARK: - Avatar-Grafik (generiert)
//
// Jeder Avatar ist als Vektorgrafik im Einheitsraum 100 × 100 beschrieben (Kreis um 50,50).
// Nicht von Hand bearbeiten – Quelle: avdata.py (Entwurfswerkzeug).

/// Eine Ebene einer Vektorgrafik mit festen Farben.
struct VectorLayer {
    enum Fill {
        case solid(UInt32, Double)
        case linear([(UInt32, CGFloat)], CGPoint, CGPoint)
    }
    let path: Path
    let fill: Fill?
    let stroke: UInt32?
    let width: CGFloat
    let alpha: Double
    let blur: CGFloat

    init(_ path: String, fill: Fill?, stroke: UInt32? = nil, width: CGFloat = 1.6, alpha: Double = 1, blur: CGFloat = 0) {
        self.path = SVGPath.parse(path)
        self.fill = fill
        self.stroke = stroke
        self.width = width
        self.alpha = alpha
        self.blur = blur
    }
}

enum AvatarArt {
    /// Hintergrund (innen, außen) und Ebenen eines gezeichneten Avatars.
    static func make(_ avatar: Avatar) -> (bg0: UInt32, bg1: UInt32, layers: [VectorLayer]) {
        switch avatar {
        case .knight:
            return (0x2B4C8C, 0x162A52, [])
        case .fox:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M27,42 L20,13 L44,31 Z", fill: .linear([(0xF07A2A, 0), (0xC2501A, 1)], CGPoint(x: 0, y: 13), CGPoint(x: 0, y: 42)), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M73,42 L80,13 L56,31 Z", fill: .linear([(0xF07A2A, 0), (0xC2501A, 1)], CGPoint(x: 0, y: 13), CGPoint(x: 0, y: 42)), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M28,37 L24,20 L38,31 Z", fill: .solid(0x3A1E10, 1)))
            a.append(VectorLayer("M72,37 L76,20 L62,31 Z", fill: .solid(0x3A1E10, 1)))
            a.append(VectorLayer("M50,83 C38,83 21,71 17,53 C15,42 23,31 36,29 C42,28 46,30 50,32 C54,30 58,28 64,29 C77,31 85,42 83,53 C79,71 62,83 50,83 Z", fill: .linear([(0xFFA24A, 0), (0xE8641E, 1)], CGPoint(x: 0, y: 29), CGPoint(x: 0, y: 83)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M50,83 C42,83 29,75 24,62 C33,65 42,63 50,56 C58,63 67,65 76,62 C71,75 58,83 50,83 Z", fill: .solid(0xFFF4E4, 1), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M50,34 C47,40 47,48 50,54 C53,48 53,40 50,34 Z", fill: .solid(0xFFFFFF, 0.35)))
            a.append(VectorLayer("M34.7,51 C34.7,48.9 36.18,47.2 38,47.2 C39.82,47.2 41.3,48.9 41.3,51 C41.3,53.1 39.82,54.8 38,54.8 C36.18,54.8 34.7,53.1 34.7,51 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M35.59,49.48 C35.59,48.79 36.15,48.23 36.84,48.23 C37.54,48.23 38.1,48.79 38.1,49.48 C38.1,50.17 37.54,50.74 36.84,50.74 C36.15,50.74 35.59,50.17 35.59,49.48 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M58.7,51 C58.7,48.9 60.18,47.2 62,47.2 C63.82,47.2 65.3,48.9 65.3,51 C65.3,53.1 63.82,54.8 62,54.8 C60.18,54.8 58.7,53.1 58.7,51 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M59.59,49.48 C59.59,48.79 60.15,48.23 60.84,48.23 C61.54,48.23 62.1,48.79 62.1,49.48 C62.1,50.17 61.54,50.74 60.84,50.74 C60.15,50.74 59.59,50.17 59.59,49.48 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M45.5,63.5 Q50,60.5 54.5,63.5 Q53,68 50,68.5 Q47,68 45.5,63.5 Z", fill: .solid(0x2A1608, 1)))
            a.append(VectorLayer("M50,68.5 L50,71.5 M50,71.5 Q46.5,74.5 44,72.5 M50,71.5 Q53.5,74.5 56,72.5", fill: nil, stroke: 0x2A1608, width: 1.2))
            return (0xFFD8A8, 0xF08A3C, a)
        case .owl:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M27,39 L21,15 L41,30 Z", fill: .solid(0x6B4428, 1), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M73,39 L79,15 L59,30 Z", fill: .solid(0x6B4428, 1), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M19,60 C19,42.88 32.88,29 50,29 C67.12,29 81,42.88 81,60 C81,77.12 67.12,91 50,91 C32.88,91 19,77.12 19,60 Z", fill: .linear([(0x9C6B45, 0), (0x5E3B22, 1)], CGPoint(x: 0, y: 29), CGPoint(x: 0, y: 91)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M33,76 C33,69.37 40.61,64 50,64 C59.39,64 67,69.37 67,76 C67,82.63 59.39,88 50,88 C40.61,88 33,82.63 33,76 Z", fill: .solid(0xE8D2A8, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M43,73 L45,76 L47,73 M49,77 L51,80 L53,77 M53,72 L55,75 L57,72", fill: nil, stroke: 0x9C6B45, width: 1.1))
            a.append(VectorLayer("M26,51 C26,44.1 31.6,38.5 38.5,38.5 C45.4,38.5 51,44.1 51,51 C51,57.9 45.4,63.5 38.5,63.5 C31.6,63.5 26,57.9 26,51 Z", fill: .solid(0xF5E6C8, 1), stroke: 0x2A1608, width: 1.3))
            a.append(VectorLayer("M30.3,51 C30.3,46.47 33.97,42.8 38.5,42.8 C43.03,42.8 46.7,46.47 46.7,51 C46.7,55.53 43.03,59.2 38.5,59.2 C33.97,59.2 30.3,55.53 30.3,51 Z", fill: .linear([(0xFFD25A, 0), (0xF29B1E, 1)], CGPoint(x: 0, y: 43), CGPoint(x: 0, y: 59))))
            a.append(VectorLayer("M33.9,51.5 C33.9,48.96 35.96,46.9 38.5,46.9 C41.04,46.9 43.1,48.96 43.1,51.5 C43.1,54.04 41.04,56.1 38.5,56.1 C35.96,56.1 33.9,54.04 33.9,51.5 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M35,49.2 C35,48.26 35.76,47.5 36.7,47.5 C37.64,47.5 38.4,48.26 38.4,49.2 C38.4,50.14 37.64,50.9 36.7,50.9 C35.76,50.9 35,50.14 35,49.2 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M49,51 C49,44.1 54.6,38.5 61.5,38.5 C68.4,38.5 74,44.1 74,51 C74,57.9 68.4,63.5 61.5,63.5 C54.6,63.5 49,57.9 49,51 Z", fill: .solid(0xF5E6C8, 1), stroke: 0x2A1608, width: 1.3))
            a.append(VectorLayer("M53.3,51 C53.3,46.47 56.97,42.8 61.5,42.8 C66.03,42.8 69.7,46.47 69.7,51 C69.7,55.53 66.03,59.2 61.5,59.2 C56.97,59.2 53.3,55.53 53.3,51 Z", fill: .linear([(0xFFD25A, 0), (0xF29B1E, 1)], CGPoint(x: 0, y: 43), CGPoint(x: 0, y: 59))))
            a.append(VectorLayer("M56.9,51.5 C56.9,48.96 58.96,46.9 61.5,46.9 C64.04,46.9 66.1,48.96 66.1,51.5 C66.1,54.04 64.04,56.1 61.5,56.1 C58.96,56.1 56.9,54.04 56.9,51.5 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M58,49.2 C58,48.26 58.76,47.5 59.7,47.5 C60.64,47.5 61.4,48.26 61.4,49.2 C61.4,50.14 60.64,50.9 59.7,50.9 C58.76,50.9 58,50.14 58,49.2 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M45.5,58.5 L54.5,58.5 L50,67 Z", fill: .linear([(0xFFC24A, 0), (0xD9821A, 1)], CGPoint(x: 0, y: 58), CGPoint(x: 0, y: 67)), stroke: 0x2A1608, width: 1))
            return (0xC9E8FF, 0x5A8FC9, a)
        case .bear:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M15.5,33 C15.5,27.2 20.2,22.5 26,22.5 C31.8,22.5 36.5,27.2 36.5,33 C36.5,38.8 31.8,43.5 26,43.5 C20.2,43.5 15.5,38.8 15.5,33 Z", fill: .solid(0x8A5530, 1), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M20.7,33 C20.7,30.07 23.07,27.7 26,27.7 C28.93,27.7 31.3,30.07 31.3,33 C31.3,35.93 28.93,38.3 26,38.3 C23.07,38.3 20.7,35.93 20.7,33 Z", fill: .solid(0xD9A57A, 1)))
            a.append(VectorLayer("M63.5,33 C63.5,27.2 68.2,22.5 74,22.5 C79.8,22.5 84.5,27.2 84.5,33 C84.5,38.8 79.8,43.5 74,43.5 C68.2,43.5 63.5,38.8 63.5,33 Z", fill: .solid(0x8A5530, 1), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M68.7,33 C68.7,30.07 71.07,27.7 74,27.7 C76.93,27.7 79.3,30.07 79.3,33 C79.3,35.93 76.93,38.3 74,38.3 C71.07,38.3 68.7,35.93 68.7,33 Z", fill: .solid(0xD9A57A, 1)))
            a.append(VectorLayer("M20,57 C20,40.43 33.43,27 50,27 C66.57,27 80,40.43 80,57 C80,73.57 66.57,87 50,87 C33.43,87 20,73.57 20,57 Z", fill: .linear([(0xB07848, 0), (0x75451F, 1)], CGPoint(x: 0, y: 27), CGPoint(x: 0, y: 87)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M36,67 C36,60.92 42.27,56 50,56 C57.73,56 64,60.92 64,67 C64,73.08 57.73,78 50,78 C42.27,78 36,73.08 36,67 Z", fill: .solid(0xEBCB9E, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M44.4,61.5 C44.4,59.29 46.91,57.5 50,57.5 C53.09,57.5 55.6,59.29 55.6,61.5 C55.6,63.71 53.09,65.5 50,65.5 C46.91,65.5 44.4,63.71 44.4,61.5 Z", fill: .solid(0x2A1608, 1)))
            a.append(VectorLayer("M50,65.5 L50,69 M50,69 Q46.5,72.5 44,70.5 M50,69 Q53.5,72.5 56,70.5", fill: nil, stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M35.8,50 C35.8,47.97 37.23,46.32 39,46.32 C40.77,46.32 42.2,47.97 42.2,50 C42.2,52.03 40.77,53.68 39,53.68 C37.23,53.68 35.8,52.03 35.8,50 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M36.66,48.53 C36.66,47.86 37.21,47.31 37.88,47.31 C38.55,47.31 39.1,47.86 39.1,48.53 C39.1,49.2 38.55,49.74 37.88,49.74 C37.21,49.74 36.66,49.2 36.66,48.53 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M57.8,50 C57.8,47.97 59.23,46.32 61,46.32 C62.77,46.32 64.2,47.97 64.2,50 C64.2,52.03 62.77,53.68 61,53.68 C59.23,53.68 57.8,52.03 57.8,50 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M58.66,48.53 C58.66,47.86 59.21,47.31 59.88,47.31 C60.55,47.31 61.1,47.86 61.1,48.53 C61.1,49.2 60.55,49.74 59.88,49.74 C59.21,49.74 58.66,49.2 58.66,48.53 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M29,60 C29,58.56 30.79,57.4 33,57.4 C35.21,57.4 37,58.56 37,60 C37,61.44 35.21,62.6 33,62.6 C30.79,62.6 29,61.44 29,60 Z", fill: .solid(0xFF8A8A, 0.45)))
            a.append(VectorLayer("M63,60 C63,58.56 64.79,57.4 67,57.4 C69.21,57.4 71,58.56 71,60 C71,61.44 69.21,62.6 67,62.6 C64.79,62.6 63,61.44 63,60 Z", fill: .solid(0xFF8A8A, 0.45)))
            return (0xD7F2C8, 0x6FB35A, a)
        case .penguin:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M21,61 C21,42.77 33.98,28 50,28 C66.02,28 79,42.77 79,61 C79,79.23 66.02,94 50,94 C33.98,94 21,79.23 21,61 Z", fill: .linear([(0x33486E, 0), (0x141C2C, 1)], CGPoint(x: 0, y: 28), CGPoint(x: 0, y: 94)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M50,41 C43,36 32,40 31,52 C30,66 38,82 50,88 C62,82 70,66 69,52 C68,40 57,36 50,41 Z", fill: .solid(0xFFFFFF, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M38.9,55 C38.9,53.03 40.29,51.44 42,51.44 C43.71,51.44 45.1,53.03 45.1,55 C45.1,56.97 43.71,58.56 42,58.56 C40.29,58.56 38.9,56.97 38.9,55 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M39.74,53.57 C39.74,52.92 40.26,52.4 40.91,52.4 C41.57,52.4 42.09,52.92 42.09,53.57 C42.09,54.22 41.57,54.75 40.91,54.75 C40.26,54.75 39.74,54.22 39.74,53.57 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M54.9,55 C54.9,53.03 56.29,51.44 58,51.44 C59.71,51.44 61.1,53.03 61.1,55 C61.1,56.97 59.71,58.56 58,58.56 C56.29,58.56 54.9,56.97 54.9,55 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M55.74,53.57 C55.74,52.92 56.26,52.4 56.91,52.4 C57.57,52.4 58.09,52.92 58.09,53.57 C58.09,54.22 57.57,54.75 56.91,54.75 C56.26,54.75 55.74,54.22 55.74,53.57 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M44.5,62 Q50,59 55.5,62 L50,69 Z", fill: .linear([(0xFFB13B, 0), (0xE8761E, 1)], CGPoint(x: 0, y: 59), CGPoint(x: 0, y: 69)), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M33.2,63 C33.2,61.67 34.9,60.6 37,60.6 C39.1,60.6 40.8,61.67 40.8,63 C40.8,64.33 39.1,65.4 37,65.4 C34.9,65.4 33.2,64.33 33.2,63 Z", fill: .solid(0xFF8FA8, 0.55)))
            a.append(VectorLayer("M59.2,63 C59.2,61.67 60.9,60.6 63,60.6 C65.1,60.6 66.8,61.67 66.8,63 C66.8,64.33 65.1,65.4 63,65.4 C60.9,65.4 59.2,64.33 59.2,63 Z", fill: .solid(0xFF8FA8, 0.55)))
            return (0xD6F4FF, 0x57B7E8, a)
        case .frog:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M22,40 C22,33.37 27.37,28 34,28 C40.63,28 46,33.37 46,40 C46,46.63 40.63,52 34,52 C27.37,52 22,46.63 22,40 Z", fill: .linear([(0x8EE07A, 0), (0x4FA544, 1)], CGPoint(x: 0, y: 28), CGPoint(x: 0, y: 52)), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M54,40 C54,33.37 59.37,28 66,28 C72.63,28 78,33.37 78,40 C78,46.63 72.63,52 66,52 C59.37,52 54,46.63 54,40 Z", fill: .linear([(0x8EE07A, 0), (0x4FA544, 1)], CGPoint(x: 0, y: 28), CGPoint(x: 0, y: 52)), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M17,62 C17,49.3 31.77,39 50,39 C68.23,39 83,49.3 83,62 C83,74.7 68.23,85 50,85 C31.77,85 17,74.7 17,62 Z", fill: .linear([(0x86D972, 0), (0x3E9038, 1)], CGPoint(x: 0, y: 39), CGPoint(x: 0, y: 85)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M26.6,40 C26.6,35.91 29.91,32.6 34,32.6 C38.09,32.6 41.4,35.91 41.4,40 C41.4,44.09 38.09,47.4 34,47.4 C29.91,47.4 26.6,44.09 26.6,40 Z", fill: .solid(0xFFFFFF, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M30.8,41 C30.8,38.57 32.5,36.6 34.6,36.6 C36.7,36.6 38.4,38.57 38.4,41 C38.4,43.43 36.7,45.4 34.6,45.4 C32.5,45.4 30.8,43.43 30.8,41 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M31.6,39 C31.6,38.23 32.23,37.6 33,37.6 C33.77,37.6 34.4,38.23 34.4,39 C34.4,39.77 33.77,40.4 33,40.4 C32.23,40.4 31.6,39.77 31.6,39 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M58.6,40 C58.6,35.91 61.91,32.6 66,32.6 C70.09,32.6 73.4,35.91 73.4,40 C73.4,44.09 70.09,47.4 66,47.4 C61.91,47.4 58.6,44.09 58.6,40 Z", fill: .solid(0xFFFFFF, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M62.8,41 C62.8,38.57 64.5,36.6 66.6,36.6 C68.7,36.6 70.4,38.57 70.4,41 C70.4,43.43 68.7,45.4 66.6,45.4 C64.5,45.4 62.8,43.43 62.8,41 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M63.6,39 C63.6,38.23 64.23,37.6 65,37.6 C65.77,37.6 66.4,38.23 66.4,39 C66.4,39.77 65.77,40.4 65,40.4 C64.23,40.4 63.6,39.77 63.6,39 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M30,64 Q50,79 70,64", fill: nil, stroke: 0x1F4F1C, width: 2))
            a.append(VectorLayer("M23.8,66 C23.8,64.51 25.68,63.3 28,63.3 C30.32,63.3 32.2,64.51 32.2,66 C32.2,67.49 30.32,68.7 28,68.7 C25.68,68.7 23.8,67.49 23.8,66 Z", fill: .solid(0xFF8FA8, 0.55)))
            a.append(VectorLayer("M67.8,66 C67.8,64.51 69.68,63.3 72,63.3 C74.32,63.3 76.2,64.51 76.2,66 C76.2,67.49 74.32,68.7 72,68.7 C69.68,68.7 67.8,67.49 67.8,66 Z", fill: .solid(0xFF8FA8, 0.55)))
            a.append(VectorLayer("M43.9,55 C43.9,54.39 44.39,53.9 45,53.9 C45.61,53.9 46.1,54.39 46.1,55 C46.1,55.61 45.61,56.1 45,56.1 C44.39,56.1 43.9,55.61 43.9,55 Z", fill: .solid(0x1F4F1C, 1)))
            a.append(VectorLayer("M53.9,55 C53.9,54.39 54.39,53.9 55,53.9 C55.61,53.9 56.1,54.39 56.1,55 C56.1,55.61 55.61,56.1 55,56.1 C54.39,56.1 53.9,55.61 53.9,55 Z", fill: .solid(0x1F4F1C, 1)))
            return (0xF4FFC8, 0xB7D94A, a)
        case .wolf:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M28,40 L22,11 L43,30 Z", fill: .linear([(0xA8B4C4, 0), (0x5D6878, 1)], CGPoint(x: 0, y: 11), CGPoint(x: 0, y: 40)), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M72,40 L78,11 L57,30 Z", fill: .linear([(0xA8B4C4, 0), (0x5D6878, 1)], CGPoint(x: 0, y: 11), CGPoint(x: 0, y: 40)), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M29,35 L26,19 L37,30 Z", fill: .solid(0x2E3440, 1)))
            a.append(VectorLayer("M71,35 L74,19 L63,30 Z", fill: .solid(0x2E3440, 1)))
            a.append(VectorLayer("M50,86 C40,86 26,76 21,58 C18,45 25,32 37,29 C43,28 47,30 50,31 C53,30 57,28 63,29 C75,32 82,45 79,58 C74,76 60,86 50,86 Z", fill: .linear([(0xB4BFCD, 0), (0x67727F, 1)], CGPoint(x: 0, y: 29), CGPoint(x: 0, y: 86)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M50,86 C43,86 33,78 30,66 C37,68 44,65 50,58 C56,65 63,68 70,66 C67,78 57,86 50,86 Z", fill: .solid(0xEEF2F6, 1), stroke: 0x2A1608, width: 1.1))
            a.append(VectorLayer("M37,46 L44,49 M63,46 L56,49", fill: nil, stroke: 0x2E3440, width: 1.6))
            a.append(VectorLayer("M35.9,53 C35.9,51.45 37.51,50.2 39.5,50.2 C41.49,50.2 43.1,51.45 43.1,53 C43.1,54.55 41.49,55.8 39.5,55.8 C37.51,55.8 35.9,54.55 35.9,53 Z", fill: .solid(0xFFD24A, 1), stroke: 0x2A1608, width: 0.8))
            a.append(VectorLayer("M38.4,53 C38.4,51.67 38.89,50.6 39.5,50.6 C40.11,50.6 40.6,51.67 40.6,53 C40.6,54.33 40.11,55.4 39.5,55.4 C38.89,55.4 38.4,54.33 38.4,53 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M56.9,53 C56.9,51.45 58.51,50.2 60.5,50.2 C62.49,50.2 64.1,51.45 64.1,53 C64.1,54.55 62.49,55.8 60.5,55.8 C58.51,55.8 56.9,54.55 56.9,53 Z", fill: .solid(0xFFD24A, 1), stroke: 0x2A1608, width: 0.8))
            a.append(VectorLayer("M59.4,53 C59.4,51.67 59.89,50.6 60.5,50.6 C61.11,50.6 61.6,51.67 61.6,53 C61.6,54.33 61.11,55.4 60.5,55.4 C59.89,55.4 59.4,54.33 59.4,53 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M45.5,66 Q50,63 54.5,66 Q53,70.5 50,71 Q47,70.5 45.5,66 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M50,71 L50,74 M50,74 Q46,77 43.5,75 M50,74 Q54,77 56.5,75", fill: nil, stroke: 0x1B1206, width: 1.2))
            return (0xC9D6FF, 0x4A5CA8, a)
        case .lion:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M68,55 C68,48.92 72.92,44 79,44 C85.08,44 90,48.92 90,55 C90,61.08 85.08,66 79,66 C72.92,66 68,61.08 68,55 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M65.13,67.58 C65.13,61.51 70.05,56.58 76.13,56.58 C82.2,56.58 87.13,61.51 87.13,67.58 C87.13,73.66 82.2,78.58 76.13,78.58 C70.05,78.58 65.13,73.66 65.13,67.58 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M57.08,77.67 C57.08,71.6 62.01,66.67 68.08,66.67 C74.16,66.67 79.08,71.6 79.08,77.67 C79.08,83.75 74.16,88.67 68.08,88.67 C62.01,88.67 57.08,83.75 57.08,77.67 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M45.45,83.27 C45.45,77.2 50.38,72.27 56.45,72.27 C62.53,72.27 67.45,77.2 67.45,83.27 C67.45,89.35 62.53,94.27 56.45,94.27 C50.38,94.27 45.45,89.35 45.45,83.27 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M32.55,83.27 C32.55,77.2 37.47,72.27 43.55,72.27 C49.62,72.27 54.55,77.2 54.55,83.27 C54.55,89.35 49.62,94.27 43.55,94.27 C37.47,94.27 32.55,89.35 32.55,83.27 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M20.92,77.67 C20.92,71.6 25.84,66.67 31.92,66.67 C37.99,66.67 42.92,71.6 42.92,77.67 C42.92,83.75 37.99,88.67 31.92,88.67 C25.84,88.67 20.92,83.75 20.92,77.67 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M12.87,67.58 C12.87,61.51 17.8,56.58 23.87,56.58 C29.95,56.58 34.87,61.51 34.87,67.58 C34.87,73.66 29.95,78.58 23.87,78.58 C17.8,78.58 12.87,73.66 12.87,67.58 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M10,55 C10,48.92 14.92,44 21,44 C27.08,44 32,48.92 32,55 C32,61.08 27.08,66 21,66 C14.92,66 10,61.08 10,55 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M12.87,42.42 C12.87,36.34 17.8,31.42 23.87,31.42 C29.95,31.42 34.87,36.34 34.87,42.42 C34.87,48.49 29.95,53.42 23.87,53.42 C17.8,53.42 12.87,48.49 12.87,42.42 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M20.92,32.33 C20.92,26.25 25.84,21.33 31.92,21.33 C37.99,21.33 42.92,26.25 42.92,32.33 C42.92,38.4 37.99,43.33 31.92,43.33 C25.84,43.33 20.92,38.4 20.92,32.33 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M32.55,26.73 C32.55,20.65 37.47,15.73 43.55,15.73 C49.62,15.73 54.55,20.65 54.55,26.73 C54.55,32.8 49.62,37.73 43.55,37.73 C37.47,37.73 32.55,32.8 32.55,26.73 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M45.45,26.73 C45.45,20.65 50.38,15.73 56.45,15.73 C62.53,15.73 67.45,20.65 67.45,26.73 C67.45,32.8 62.53,37.73 56.45,37.73 C50.38,37.73 45.45,32.8 45.45,26.73 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M57.08,32.33 C57.08,26.25 62.01,21.33 68.08,21.33 C74.16,21.33 79.08,26.25 79.08,32.33 C79.08,38.4 74.16,43.33 68.08,43.33 C62.01,43.33 57.08,38.4 57.08,32.33 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M65.13,42.42 C65.13,36.34 70.05,31.42 76.13,31.42 C82.2,31.42 87.13,36.34 87.13,42.42 C87.13,48.49 82.2,53.42 76.13,53.42 C70.05,53.42 65.13,48.49 65.13,42.42 Z", fill: .solid(0xB8621A, 1), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M19,55 C19,37.88 32.88,24 50,24 C67.12,24 81,37.88 81,55 C81,72.12 67.12,86 50,86 C32.88,86 19,72.12 19,55 Z", fill: .linear([(0xD9802A, 0), (0x9A4C12, 1)], CGPoint(x: 0, y: 24), CGPoint(x: 0, y: 86))))
            a.append(VectorLayer("M26.5,38 C26.5,34.41 29.41,31.5 33,31.5 C36.59,31.5 39.5,34.41 39.5,38 C39.5,41.59 36.59,44.5 33,44.5 C29.41,44.5 26.5,41.59 26.5,38 Z", fill: .solid(0xF2A93C, 1), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M29.8,38 C29.8,36.23 31.23,34.8 33,34.8 C34.77,34.8 36.2,36.23 36.2,38 C36.2,39.77 34.77,41.2 33,41.2 C31.23,41.2 29.8,39.77 29.8,38 Z", fill: .solid(0xC7782A, 1)))
            a.append(VectorLayer("M60.5,38 C60.5,34.41 63.41,31.5 67,31.5 C70.59,31.5 73.5,34.41 73.5,38 C73.5,41.59 70.59,44.5 67,44.5 C63.41,44.5 60.5,41.59 60.5,38 Z", fill: .solid(0xF2A93C, 1), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M63.8,38 C63.8,36.23 65.23,34.8 67,34.8 C68.77,34.8 70.2,36.23 70.2,38 C70.2,39.77 68.77,41.2 67,41.2 C65.23,41.2 63.8,39.77 63.8,38 Z", fill: .solid(0xC7782A, 1)))
            a.append(VectorLayer("M27,56 C27,43.3 37.3,33 50,33 C62.7,33 73,43.3 73,56 C73,68.7 62.7,79 50,79 C37.3,79 27,68.7 27,56 Z", fill: .linear([(0xFFD36A, 0), (0xEAA235, 1)], CGPoint(x: 0, y: 33), CGPoint(x: 0, y: 79)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M38,66 C38,61.03 43.37,57 50,57 C56.63,57 62,61.03 62,66 C62,70.97 56.63,75 50,75 C43.37,75 38,70.97 38,66 Z", fill: .solid(0xFFF0CC, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M45.5,61 L54.5,61 L50,66.5 Z", fill: .solid(0x6B3410, 1), stroke: 0x2A1608, width: 0.8))
            a.append(VectorLayer("M50,66.5 L50,69.5 M50,69.5 Q46.5,72.5 44,70.5 M50,69.5 Q53.5,72.5 56,70.5", fill: nil, stroke: 0x6B3410, width: 1.2))
            a.append(VectorLayer("M37.9,52 C37.9,50.03 39.29,48.44 41,48.44 C42.71,48.44 44.1,50.03 44.1,52 C44.1,53.97 42.71,55.56 41,55.56 C39.29,55.56 37.9,53.97 37.9,52 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M38.74,50.57 C38.74,49.92 39.26,49.4 39.91,49.4 C40.57,49.4 41.09,49.92 41.09,50.57 C41.09,51.22 40.57,51.75 39.91,51.75 C39.26,51.75 38.74,51.22 38.74,50.57 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M55.9,52 C55.9,50.03 57.29,48.44 59,48.44 C60.71,48.44 62.1,50.03 62.1,52 C62.1,53.97 60.71,55.56 59,55.56 C57.29,55.56 55.9,53.97 55.9,52 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M56.74,50.57 C56.74,49.92 57.26,49.4 57.91,49.4 C58.57,49.4 59.09,49.92 59.09,50.57 C59.09,51.22 58.57,51.75 57.91,51.75 C57.26,51.75 56.74,51.22 56.74,50.57 Z", fill: .solid(0xFFFFFF, 1)))
            return (0xFFF0B8, 0xE8A72E, a)
        case .robot:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M50,27 L50,15", fill: nil, stroke: 0x4E545E, width: 2.2))
            a.append(VectorLayer("M45.8,13 C45.8,10.68 47.68,8.8 50,8.8 C52.32,8.8 54.2,10.68 54.2,13 C54.2,15.32 52.32,17.2 50,17.2 C47.68,17.2 45.8,15.32 45.8,13 Z", fill: .linear([(0xFF8A8A, 0), (0xE0243B, 1)], CGPoint(x: 0, y: 9), CGPoint(x: 0, y: 17)), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M20,48 L14,48 Q12,48 12,50 L12,62 Q12,64 14,64 L20,64 Z M80,48 L86,48 Q88,48 88,50 L88,62 Q88,64 86,64 L80,64 Z", fill: .solid(0x7F8DA6, 1), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M30,27 L70,27 Q80,27 80,37 L80,74 Q80,84 70,84 L30,84 Q20,84 20,74 L20,37 Q20,27 30,27 Z", fill: .linear([(0xDCE4EF, 0), (0x8D9BB2, 1)], CGPoint(x: 0, y: 27), CGPoint(x: 0, y: 84)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M28,38 L72,38 Q74,38 74,40 L74,58 Q74,60 72,60 L28,60 Q26,60 26,58 L26,40 Q26,38 28,38 Z", fill: .solid(0x1B2433, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M33,45 L45,45 Q46,45 46,46 L46,52 Q46,53 45,53 L33,53 Q32,53 32,52 L32,46 Q32,45 33,45 Z", fill: .solid(0x6FF3FF, 1), blur: 1.6))
            a.append(VectorLayer("M34,46 L44,46 L44,52 L34,52 Z", fill: .solid(0xBFFBFF, 1)))
            a.append(VectorLayer("M55,45 L67,45 Q68,45 68,46 L68,52 Q68,53 67,53 L55,53 Q54,53 54,52 L54,46 Q54,45 55,45 Z", fill: .solid(0x6FF3FF, 1), blur: 1.6))
            a.append(VectorLayer("M56,46 L66,46 L66,52 L56,52 Z", fill: .solid(0xBFFBFF, 1)))
            a.append(VectorLayer("M38,68 L38,76", fill: nil, stroke: 0x4E5A70, width: 2))
            a.append(VectorLayer("M44,68 L44,76", fill: nil, stroke: 0x4E5A70, width: 2))
            a.append(VectorLayer("M50,68 L50,76", fill: nil, stroke: 0x4E5A70, width: 2))
            a.append(VectorLayer("M56,68 L56,76", fill: nil, stroke: 0x4E5A70, width: 2))
            a.append(VectorLayer("M62,68 L62,76", fill: nil, stroke: 0x4E5A70, width: 2))
            a.append(VectorLayer("M34,66 L66,66 L66,78 L34,78 Z", fill: nil, stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M23.6,32 C23.6,31.23 24.23,30.6 25,30.6 C25.77,30.6 26.4,31.23 26.4,32 C26.4,32.77 25.77,33.4 25,33.4 C24.23,33.4 23.6,32.77 23.6,32 Z", fill: .solid(0x4E5A70, 1)))
            a.append(VectorLayer("M73.6,32 C73.6,31.23 74.23,30.6 75,30.6 C75.77,30.6 76.4,31.23 76.4,32 C76.4,32.77 75.77,33.4 75,33.4 C74.23,33.4 73.6,32.77 73.6,32 Z", fill: .solid(0x4E5A70, 1)))
            a.append(VectorLayer("M23.6,79 C23.6,78.23 24.23,77.6 25,77.6 C25.77,77.6 26.4,78.23 26.4,79 C26.4,79.77 25.77,80.4 25,80.4 C24.23,80.4 23.6,79.77 23.6,79 Z", fill: .solid(0x4E5A70, 1)))
            a.append(VectorLayer("M73.6,79 C73.6,78.23 74.23,77.6 75,77.6 C75.77,77.6 76.4,78.23 76.4,79 C76.4,79.77 75.77,80.4 75,80.4 C74.23,80.4 73.6,79.77 73.6,79 Z", fill: .solid(0x4E5A70, 1)))
            return (0xD8F8FF, 0x3FA9D5, a)
        case .wizard:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M50,91 C42,90 33,80 32,64 C38,70 44,72 50,72 C56,72 62,70 68,64 C67,80 58,90 50,91 Z", fill: .linear([(0xFFFFFF, 0), (0xC9CFE0, 1)], CGPoint(x: 0, y: 64), CGPoint(x: 0, y: 91)), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M34.5,58 C34.5,49.44 41.44,42.5 50,42.5 C58.56,42.5 65.5,49.44 65.5,58 C65.5,66.56 58.56,73.5 50,73.5 C41.44,73.5 34.5,66.56 34.5,58 Z", fill: .linear([(0xFFD8B4, 0), (0xE8A87C, 1)], CGPoint(x: 0, y: 43), CGPoint(x: 0, y: 74)), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M36,63 C40,68 46,66 50,64 C54,66 60,68 64,63 C62,74 56,80 50,80 C44,80 38,74 36,63 Z", fill: .solid(0xF4F6FB, 1), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M42.1,56 C42.1,54.48 43.17,53.24 44.5,53.24 C45.83,53.24 46.9,54.48 46.9,56 C46.9,57.52 45.83,58.76 44.5,58.76 C43.17,58.76 42.1,57.52 42.1,56 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M42.75,54.9 C42.75,54.39 43.16,53.98 43.66,53.98 C44.16,53.98 44.57,54.39 44.57,54.9 C44.57,55.4 44.16,55.81 43.66,55.81 C43.16,55.81 42.75,55.4 42.75,54.9 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M53.1,56 C53.1,54.48 54.17,53.24 55.5,53.24 C56.83,53.24 57.9,54.48 57.9,56 C57.9,57.52 56.83,58.76 55.5,58.76 C54.17,58.76 53.1,57.52 53.1,56 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M53.75,54.9 C53.75,54.39 54.16,53.98 54.66,53.98 C55.16,53.98 55.57,54.39 55.57,54.9 C55.57,55.4 55.16,55.81 54.66,55.81 C54.16,55.81 53.75,55.4 53.75,54.9 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M42,52 L47,51 M58,52 L53,51", fill: nil, stroke: 0xC9CFE0, width: 2.2))
            a.append(VectorLayer("M47.4,61 C47.4,59.78 48.56,58.8 50,58.8 C51.44,58.8 52.6,59.78 52.6,61 C52.6,62.22 51.44,63.2 50,63.2 C48.56,63.2 47.4,62.22 47.4,61 Z", fill: .solid(0xE39472, 1)))
            a.append(VectorLayer("M18,47 C30,40 70,40 82,47 C76,53 24,53 18,47 Z", fill: .linear([(0x8D63FF, 0), (0x4A28B8, 1)], CGPoint(x: 0, y: 40), CGPoint(x: 0, y: 53)), stroke: 0x2A1608, width: 1.6))
            a.append(VectorLayer("M30,46 C35,32 42,18 56,7 C55,18 62,30 70,46 C60,49 40,49 30,46 Z", fill: .linear([(0x9C74FF, 0), (0x4A28B8, 1)], CGPoint(x: 30, y: 7), CGPoint(x: 70, y: 49)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M32,42 C44,45 56,45 68,42 L69,45 C56,48 44,48 31,45 Z", fill: .solid(0xFFD24A, 1), stroke: 0x2A1608, width: 0.8))
            a.append(VectorLayer("M45,27 L45.9,29.1 L48,30 L45.9,30.9 L45,33 L44.1,30.9 L42,30 L44.1,29.1 Z", fill: .solid(0xFFE27A, 1)))
            a.append(VectorLayer("M57,19.8 L57.66,21.34 L59.2,22 L57.66,22.66 L57,24.2 L56.34,22.66 L54.8,22 L56.34,21.34 Z", fill: .solid(0xFFE27A, 1)))
            a.append(VectorLayer("M55,34.6 L55.72,36.28 L57.4,37 L55.72,37.72 L55,39.4 L54.28,37.72 L52.6,37 L54.28,36.28 Z", fill: .solid(0xFFE27A, 1)))
            return (0xE6D8FF, 0x7A4FE0, a)
        case .dragon:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M33,42 L19,15 L41,35 Z", fill: .linear([(0xFFF6D8, 0), (0xD9C49A, 1)], CGPoint(x: 0, y: 15), CGPoint(x: 0, y: 42)), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M67,42 L81,15 L59,35 Z", fill: .linear([(0xFFF6D8, 0), (0xD9C49A, 1)], CGPoint(x: 0, y: 15), CGPoint(x: 0, y: 42)), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M38,35 L42,25 L46,35 Z", fill: .solid(0xE0473C, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M46,35 L50,25 L54,35 Z", fill: .solid(0xE0473C, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M54,35 L58,25 L62,35 Z", fill: .solid(0xE0473C, 1), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M50,87 C33,87 22,75 22,60 C22,45 33,35 50,35 C67,35 78,45 78,60 C78,75 67,87 50,87 Z", fill: .linear([(0x4FD49C, 0), (0x1F7A5A, 1)], CGPoint(x: 0, y: 35), CGPoint(x: 0, y: 87)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M33,72 C33,65.92 40.61,61 50,61 C59.39,61 67,65.92 67,72 C67,78.08 59.39,83 50,83 C40.61,83 33,78.08 33,72 Z", fill: .linear([(0x8EF0C4, 0), (0x3FB085, 1)], CGPoint(x: 0, y: 61), CGPoint(x: 0, y: 83)), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M41.8,70 C41.8,69.12 42.78,68.4 44,68.4 C45.22,68.4 46.2,69.12 46.2,70 C46.2,70.88 45.22,71.6 44,71.6 C42.78,71.6 41.8,70.88 41.8,70 Z", fill: .solid(0x114433, 1)))
            a.append(VectorLayer("M53.8,70 C53.8,69.12 54.78,68.4 56,68.4 C57.22,68.4 58.2,69.12 58.2,70 C58.2,70.88 57.22,71.6 56,71.6 C54.78,71.6 53.8,70.88 53.8,70 Z", fill: .solid(0x114433, 1)))
            a.append(VectorLayer("M32.8,53 C32.8,50.68 35.13,48.8 38,48.8 C40.87,48.8 43.2,50.68 43.2,53 C43.2,55.32 40.87,57.2 38,57.2 C35.13,57.2 32.8,55.32 32.8,53 Z", fill: .linear([(0xFFF07A, 0), (0xFFB62E, 1)], CGPoint(x: 0, y: 49), CGPoint(x: 0, y: 57)), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M36.7,53 C36.7,51.01 37.28,49.4 38,49.4 C38.72,49.4 39.3,51.01 39.3,53 C39.3,54.99 38.72,56.6 38,56.6 C37.28,56.6 36.7,54.99 36.7,53 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M56.8,53 C56.8,50.68 59.13,48.8 62,48.8 C64.87,48.8 67.2,50.68 67.2,53 C67.2,55.32 64.87,57.2 62,57.2 C59.13,57.2 56.8,55.32 56.8,53 Z", fill: .linear([(0xFFF07A, 0), (0xFFB62E, 1)], CGPoint(x: 0, y: 49), CGPoint(x: 0, y: 57)), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M60.7,53 C60.7,51.01 61.28,49.4 62,49.4 C62.72,49.4 63.3,51.01 63.3,53 C63.3,54.99 62.72,56.6 62,56.6 C61.28,56.6 60.7,54.99 60.7,53 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M31,46 L44,49 M69,46 L56,49", fill: nil, stroke: 0x114433, width: 1.8))
            a.append(VectorLayer("M40,79 Q50,83 60,79", fill: nil, stroke: 0x114433, width: 1.4))
            return (0xFFE0C8, 0xE8553C, a)
        case .phoenix:
            var a: [VectorLayer] = []
            a.append(VectorLayer("M38,62 C26,60 14,52 9,38 C18,44 24,44 28,42 C20,36 18,28 19,20 C26,30 32,34 38,36 C34,28 35,22 38,16 C42,30 46,40 46,54 Z", fill: .linear([(0xFFE27A, 0), (0xFF7A2E, 0.55), (0xE0243B, 1)], CGPoint(x: 0, y: 16), CGPoint(x: 0, y: 62)), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M62,62 C74,60 86,52 91,38 C82,44 76,44 72,42 C80,36 82,28 81,20 C74,30 68,34 62,36 C66,28 65,22 62,16 C58,30 54,40 54,54 Z", fill: .linear([(0xFFE27A, 0), (0xFF7A2E, 0.55), (0xE0243B, 1)], CGPoint(x: 0, y: 16), CGPoint(x: 0, y: 62)), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M50,34 C46,26 46,18 50,9 C54,18 54,26 50,34 Z", fill: .linear([(0xFFF4A8, 0), (0xFF8A2E, 1)], CGPoint(x: 0, y: 9), CGPoint(x: 0, y: 35)), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M45,35 C40,29 38,22 40,15 C44,22 47,28 47,34 Z", fill: .linear([(0xFFF4A8, 0), (0xFF8A2E, 1)], CGPoint(x: 0, y: 9), CGPoint(x: 0, y: 35)), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M55,35 C60,29 62,22 60,15 C56,22 53,28 53,34 Z", fill: .linear([(0xFFF4A8, 0), (0xFF8A2E, 1)], CGPoint(x: 0, y: 9), CGPoint(x: 0, y: 35)), stroke: 0x2A1608, width: 1.2))
            a.append(VectorLayer("M50,90 C40,88 36,78 38,68 C40,62 44,60 50,60 C56,60 60,62 62,68 C64,78 60,88 50,90 Z", fill: .linear([(0xFFB23F, 0), (0xE0243B, 1)], CGPoint(x: 0, y: 60), CGPoint(x: 0, y: 90)), stroke: 0x2A1608, width: 1.4))
            a.append(VectorLayer("M35,50 C35,41.72 41.72,35 50,35 C58.28,35 65,41.72 65,50 C65,58.28 58.28,65 50,65 C41.72,65 35,58.28 35,50 Z", fill: .linear([(0xFFC94A, 0), (0xFF6A2B, 1)], CGPoint(x: 0, y: 35), CGPoint(x: 0, y: 65)), stroke: 0x2A1608, width: 1.8))
            a.append(VectorLayer("M45,54 L55,54 L50,63 Z", fill: .linear([(0xFFF0B0, 0), (0xE8A21E, 1)], CGPoint(x: 0, y: 54), CGPoint(x: 0, y: 63)), stroke: 0x2A1608, width: 1))
            a.append(VectorLayer("M42,48 C42,46.41 43.12,45.12 44.5,45.12 C45.88,45.12 47,46.41 47,48 C47,49.59 45.88,50.88 44.5,50.88 C43.12,50.88 42,49.59 42,48 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M42.67,46.85 C42.67,46.33 43.1,45.9 43.62,45.9 C44.15,45.9 44.58,46.33 44.58,46.85 C44.58,47.37 44.15,47.8 43.62,47.8 C43.1,47.8 42.67,47.37 42.67,46.85 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M53,48 C53,46.41 54.12,45.12 55.5,45.12 C56.88,45.12 58,46.41 58,48 C58,49.59 56.88,50.88 55.5,50.88 C54.12,50.88 53,49.59 53,48 Z", fill: .solid(0x1B1206, 1)))
            a.append(VectorLayer("M53.67,46.85 C53.67,46.33 54.1,45.9 54.62,45.9 C55.15,45.9 55.58,46.33 55.58,46.85 C55.58,47.37 55.15,47.8 54.62,47.8 C54.1,47.8 53.67,47.37 53.67,46.85 Z", fill: .solid(0xFFFFFF, 1)))
            a.append(VectorLayer("M40,44 L46,46 M60,44 L54,46", fill: nil, stroke: 0x8A1A10, width: 1.6))
            return (0x9C6BFF, 0x2A1050, a)
        }
    }

    static let cache: [Avatar: (bg0: UInt32, bg1: UInt32, layers: [VectorLayer])] = {
        var m: [Avatar: (bg0: UInt32, bg1: UInt32, layers: [VectorLayer])] = [:]
        for a in Avatar.allCases { m[a] = make(a) }
        return m
    }()
}
