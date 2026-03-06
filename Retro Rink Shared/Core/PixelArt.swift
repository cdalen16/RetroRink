import SpriteKit

// MARK: - Pixel Art Renderer
final class PixelArt {

    // MARK: - Caches
    private static var textureCache: [String: SKTexture] = [:]
    private static var animationCache: [String: [SKTexture]] = [:]

    static func clearCache() {
        textureCache.removeAll()
        animationCache.removeAll()
    }

    // MARK: - Enums

    enum SpriteDirection {
        case left, right
    }

    enum SkaterAnimState {
        case idle, skating, shooting, celebrating, deking, hit
    }

    enum GoalieAnimState {
        case idle, saveLeft, saveRight, butterfly
    }

    enum BoardSegment {
        case straight, corner
    }

    // MARK: - Core Renderer
    /// Renders a pixel grid into an SKTexture. Each cell in `data` indexes into `palette`.
    /// -1 or out-of-range = transparent.
    static func texture(from data: [[Int]], palette: [UIColor], scale: CGFloat = kPixelSize) -> SKTexture {
        let rows = data.count
        guard rows > 0 else { return SKTexture() }
        let cols = data[0].count
        let size = CGSize(width: CGFloat(cols) * scale, height: CGFloat(rows) * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setAllowsAntialiasing(false)
            gc.interpolationQuality = .none

            for row in 0..<rows {
                for col in 0..<data[row].count {
                    let idx = data[row][col]
                    guard idx >= 0 && idx < palette.count else { continue }
                    gc.setFillColor(palette[idx].cgColor)
                    gc.fill(CGRect(
                        x: CGFloat(col) * scale,
                        y: CGFloat(row) * scale,
                        width: scale,
                        height: scale
                    ))
                }
            }
        }

        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: - Skater Palette

    private static func skaterPalette(teamColors: TeamColors) -> [UIColor] {
        let skin = UIColor(hex: "FFD5B0")
        let dark = UIColor(hex: "2A2A2A")
        return [
            skin,                          // 0 - skin
            teamColors.primaryColor,       // 1 - helmet
            teamColors.primaryColor,       // 2 - jersey primary
            teamColors.secondaryColor,     // 3 - jersey secondary
            UIColor(hex: "333344"),        // 4 - pants
            dark,                          // 5 - skates
            UIColor(hex: "8B6914"),        // 6 - stick
            teamColors.accentColor,        // 7 - accent/stripe
        ]
    }

    // MARK: - Skater Base Template (12x16)

    /// Returns the base idle skater pixel data (facing right).
    /// Palette: 0=skin, 1=helmet, 2=jersey primary, 3=jersey secondary, 4=pants, 5=skates, 6=stick, 7=accent
    private static func skaterBaseData() -> [[Int]] {
        return [
            [-1,-1,-1,-1, 1, 1, 1, 1,-1,-1,-1,-1],  // row 0: helmet top
            [-1,-1,-1, 1, 1, 1, 1, 1, 1,-1,-1,-1],  // row 1: helmet
            [-1,-1,-1, 1, 0, 1, 0, 1, 1,-1,-1,-1],  // row 2: face (visor)
            [-1,-1,-1, 0, 0, 0, 0, 0,-1,-1,-1,-1],  // row 3: chin
            [-1,-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1],  // row 4: shoulders
            [-1,-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1],  // row 5: jersey top
            [-1,-1, 2, 7, 7, 7, 7, 7, 2,-1,-1,-1],  // row 6: jersey stripe
            [-1,-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1],  // row 7: jersey bottom
            [-1,-1, 0, 2, 2, 2, 2, 2, 0, 6,-1,-1],  // row 8: hands + stick
            [-1,-1,-1, 4, 4, 4, 4, 4,-1, 6,-1,-1],  // row 9: pants top
            [-1,-1,-1, 4, 4, 4, 4, 4,-1, 6,-1,-1],  // row 10: pants
            [-1,-1,-1, 4, 4,-1, 4, 4,-1,-1,-1,-1],  // row 11: pants legs
            [-1,-1,-1, 4, 4,-1, 4, 4,-1,-1,-1,-1],  // row 12: socks
            [-1,-1,-1, 5, 5,-1, 5, 5,-1,-1,-1,-1],  // row 13: skates top
            [-1,-1, 5, 5, 5,-1, 5, 5, 5,-1,-1,-1],  // row 14: skate blades
            [-1,-1, 5, 5,-1,-1,-1, 5, 5,-1,-1,-1],  // row 15: blade edges
        ]
    }

    // MARK: - Skater Static Texture

    static func skaterTexture(teamColors: TeamColors, direction: SpriteDirection = .right) -> SKTexture {
        let key = "skater_\(teamColors.primary)_\(teamColors.secondary)_\(direction)"
        if let cached = textureCache[key] { return cached }

        var data = skaterBaseData()
        if direction == .left {
            data = data.map { $0.reversed() }
        }

        let tex = texture(from: data, palette: skaterPalette(teamColors: teamColors))
        textureCache[key] = tex
        return tex
    }

    // MARK: - Skater Animation Frames

    static func skaterFrames(teamColors: TeamColors, state: SkaterAnimState, direction: SpriteDirection = .right) -> [SKTexture] {
        let key = "skaterAnim_\(teamColors.primary)_\(teamColors.secondary)_\(state)_\(direction)"
        if let cached = animationCache[key] { return cached }

        let palette = skaterPalette(teamColors: teamColors)
        var frameDataArrays: [[[Int]]]

        switch state {
        case .idle:
            frameDataArrays = [skaterBaseData()]

        case .skating:
            frameDataArrays = skaterSkatingFrames()

        case .shooting:
            frameDataArrays = skaterShootingFrames()

        case .celebrating:
            frameDataArrays = skaterCelebratingFrames()

        case .deking:
            frameDataArrays = skaterDekingFrames()

        case .hit:
            frameDataArrays = skaterHitFrames()
        }

        // Flip for left direction
        if direction == .left {
            frameDataArrays = frameDataArrays.map { frame in
                frame.map { $0.reversed() }
            }
        }

        let textures = frameDataArrays.map { frameData in
            texture(from: frameData, palette: palette)
        }

        animationCache[key] = textures
        return textures
    }

    // MARK: - Skating Frames (4 frames)

    private static func skaterSkatingFrames() -> [[[Int]]] {
        let base = skaterBaseData()

        // Frame 0: Left leg forward, right leg back
        var frame0 = base
        frame0[11] = [-1,-1, 4, 4,-1,-1,-1, 4, 4,-1,-1,-1]  // left leg forward, right back
        frame0[12] = [-1, 4, 4,-1,-1,-1,-1,-1, 4, 4,-1,-1]  // socks spread
        frame0[13] = [-1, 5, 5,-1,-1,-1,-1,-1, 5, 5,-1,-1]  // skates spread
        frame0[14] = [ 5, 5, 5,-1,-1,-1,-1,-1, 5, 5, 5,-1]  // blades spread
        frame0[15] = [ 5, 5,-1,-1,-1,-1,-1,-1,-1, 5, 5,-1]  // blade edges spread

        // Frame 1: Legs together (glide)
        var frame1 = base
        frame1[11] = [-1,-1,-1, 4, 4, 4, 4,-1,-1,-1,-1,-1]  // legs together
        frame1[12] = [-1,-1,-1, 4, 4, 4, 4,-1,-1,-1,-1,-1]  // socks together
        frame1[13] = [-1,-1,-1, 5, 5, 5, 5,-1,-1,-1,-1,-1]  // skates together
        frame1[14] = [-1,-1, 5, 5, 5, 5, 5, 5,-1,-1,-1,-1]  // blades together
        frame1[15] = [-1,-1, 5, 5,-1,-1, 5, 5,-1,-1,-1,-1]  // edges together

        // Frame 2: Right leg forward, left leg back (mirror of frame 0)
        var frame2 = base
        frame2[11] = [-1,-1,-1, 4, 4,-1,-1, 4, 4,-1,-1,-1]  // right forward, left back
        frame2[12] = [-1,-1, 4, 4,-1,-1,-1,-1, 4,-1,-1,-1]  // socks offset
        frame2[13] = [-1,-1, 5, 5,-1,-1,-1,-1, 5,-1,-1,-1]  // skates offset
        frame2[14] = [-1, 5, 5, 5,-1,-1,-1, 5, 5, 5,-1,-1]  // blades offset
        frame2[15] = [-1, 5, 5,-1,-1,-1,-1, 5, 5,-1,-1,-1]  // edges offset

        // Frame 3: Legs together (glide variant, slight offset)
        var frame3 = base
        frame3[11] = [-1,-1,-1,-1, 4, 4, 4,-1,-1,-1,-1,-1]  // legs together offset
        frame3[12] = [-1,-1,-1,-1, 4, 4, 4,-1,-1,-1,-1,-1]  // socks together offset
        frame3[13] = [-1,-1,-1,-1, 5, 5, 5,-1,-1,-1,-1,-1]  // skates together offset
        frame3[14] = [-1,-1,-1, 5, 5, 5, 5, 5,-1,-1,-1,-1]  // blades together offset
        frame3[15] = [-1,-1,-1, 5, 5,-1, 5, 5,-1,-1,-1,-1]  // edges together offset

        return [frame0, frame1, frame2, frame3]
    }

    // MARK: - Shooting Frames (3 frames)

    private static func skaterShootingFrames() -> [[[Int]]] {
        let base = skaterBaseData()

        // Frame 0: Wind up - stick pulled back, lean back slightly
        var frame0 = base
        frame0[4]  = [-1,-1,-1, 2, 3, 3, 3, 2, 2,-1,-1,-1]  // shoulders shift back
        frame0[5]  = [-1,-1,-1, 2, 3, 3, 3, 2, 2,-1,-1,-1]  // jersey shift back
        frame0[6]  = [-1,-1,-1, 7, 7, 7, 7, 7, 2,-1,-1,-1]  // stripe shift back
        frame0[7]  = [-1,-1,-1, 2, 3, 3, 3, 2, 2,-1,-1,-1]  // jersey bottom shift back
        frame0[8]  = [-1,-1,-1, 0, 2, 2, 2, 2, 0,-1, 6,-1]  // hands back, stick pulled way back
        frame0[9]  = [-1,-1,-1, 4, 4, 4, 4, 4,-1,-1, 6,-1]  // pants + stick behind
        frame0[10] = [-1,-1,-1, 4, 4, 4, 4, 4,-1,-1, 6,-1]  // pants + stick behind

        // Frame 1: Follow through - stick forward, body leaning forward
        var frame1 = base
        frame1[4]  = [-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1,-1]  // shoulders forward
        frame1[5]  = [-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1,-1]  // jersey forward
        frame1[6]  = [-1, 2, 7, 7, 7, 7, 7, 2,-1,-1,-1,-1]  // stripe forward
        frame1[7]  = [-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1,-1]  // jersey bottom forward
        frame1[8]  = [ 6, 0, 2, 2, 2, 2, 2, 0,-1,-1,-1,-1]  // stick way out front
        frame1[9]  = [ 6,-1, 4, 4, 4, 4, 4,-1,-1,-1,-1,-1]  // pants, stick forward
        frame1[10] = [-1,-1, 4, 4, 4, 4, 4,-1,-1,-1,-1,-1]  // pants forward

        // Frame 2: Recovery - return to idle
        let frame2 = base

        return [frame0, frame1, frame2]
    }

    // MARK: - Celebrating Frames (4 frames)

    private static func skaterCelebratingFrames() -> [[[Int]]] {
        let base = skaterBaseData()

        // Frame 0: Arms raised up
        var frame0 = base
        frame0[2]  = [-1,-1, 0, 1, 0, 1, 0, 1, 0,-1,-1,-1]  // arms reaching up alongside head
        frame0[3]  = [-1,-1,-1, 0, 0, 0, 0, 0,-1,-1,-1,-1]  // chin
        frame0[4]  = [-1,-1,-1, 2, 3, 3, 3, 2,-1,-1,-1,-1]  // shoulders (arms gone up)
        frame0[5]  = [-1,-1,-1, 2, 3, 3, 3, 2,-1,-1,-1,-1]  // jersey (narrower, arms up)
        frame0[6]  = [-1,-1,-1, 7, 7, 7, 7, 7,-1,-1,-1,-1]  // stripe
        frame0[7]  = [-1,-1,-1, 2, 3, 3, 3, 2,-1,-1,-1,-1]  // jersey bottom
        frame0[8]  = [-1,-1,-1, 2, 2, 2, 2, 2,-1, 6,-1,-1]  // no hands visible (up), stick on ice

        // Frame 1: Jump (shift body up 1 pixel, gap at bottom)
        var frame1: [[Int]] = [[-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]] // empty top row (shifted up visually)
        frame1.append(contentsOf: frame0.dropLast()) // shift the celebrate pose up, dropping last row
        // Add empty row at bottom for the gap
        frame1[0]  = [-1,-1,-1,-1, 1, 1, 1, 1,-1,-1,-1,-1]  // helmet (was row 0, now shifted up)
        // Actually rebuild properly: body is shifted up by 1, bottom row is empty
        frame1 = Array(frame0.dropFirst()) // Remove first row
        frame1.append([-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]) // Empty row at bottom (airborne gap)

        // Frame 2: Arms up variant (stick raised)
        var frame2 = frame0
        frame2[0]  = [-1,-1,-1,-1, 1, 1, 1, 1,-1, 6,-1,-1]  // stick raised above head
        frame2[1]  = [-1,-1,-1, 1, 1, 1, 1, 1, 1, 6,-1,-1]  // stick alongside helmet
        frame2[8]  = [-1,-1,-1, 2, 2, 2, 2, 2,-1,-1,-1,-1]  // no stick on ice

        // Frame 3: Back on ground with arms up (same as frame 0 base)
        let frame3 = frame0

        return [frame0, frame1, frame2, frame3]
    }

    // MARK: - Deking Frames (2 frames)

    private static func skaterDekingFrames() -> [[[Int]]] {
        let base = skaterBaseData()

        // Frame 0: Lean left (shift body pixels left by 1)
        var frame0 = base
        for r in 0..<frame0.count {
            let row = frame0[r]
            // Shift all non-transparent pixels left by 1
            var shifted = [Int](repeating: -1, count: row.count)
            for c in 0..<row.count {
                if row[c] != -1 {
                    let newC = c - 1
                    if newC >= 0 {
                        shifted[newC] = row[c]
                    }
                }
            }
            frame0[r] = shifted
        }

        // Frame 1: Lean right (shift body pixels right by 1)
        var frame1 = base
        for r in 0..<frame1.count {
            let row = frame1[r]
            var shifted = [Int](repeating: -1, count: row.count)
            for c in stride(from: row.count - 1, through: 0, by: -1) {
                if row[c] != -1 {
                    let newC = c + 1
                    if newC < row.count {
                        shifted[newC] = row[c]
                    }
                }
            }
            frame1[r] = shifted
        }

        return [frame0, frame1]
    }

    // MARK: - Hit Frames (2 frames)

    private static func skaterHitFrames() -> [[[Int]]] {
        let base = skaterBaseData()

        // Frame 0: Recoiling - lean back, arms out
        var frame0 = base
        frame0[4]  = [-1,-1,-1, 2, 3, 3, 3, 2, 2, 0,-1,-1]  // arm flung out right
        frame0[5]  = [-1,-1,-1, 2, 3, 3, 3, 2, 2,-1,-1,-1]  // jersey shifted
        frame0[6]  = [-1,-1,-1, 7, 7, 7, 7, 7, 2,-1,-1,-1]  // stripe
        frame0[7]  = [-1,-1,-1, 2, 3, 3, 3, 2, 2,-1,-1,-1]  // jersey bottom
        frame0[8]  = [-1,-1,-1, 0, 2, 2, 2, 2, 0,-1,-1,-1]  // no stick visible (dropped)

        // Frame 1: Stumbling - off balance
        var frame1 = base
        frame1[4]  = [-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1,-1]  // leaning forward
        frame1[5]  = [-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1,-1]
        frame1[6]  = [-1, 2, 7, 7, 7, 7, 7, 2,-1,-1,-1,-1]
        frame1[7]  = [-1, 2, 2, 3, 3, 3, 2, 2,-1,-1,-1,-1]
        frame1[8]  = [-1, 0, 2, 2, 2, 2, 2, 0,-1,-1,-1,-1]
        frame1[11] = [-1,-1, 4, 4,-1,-1,-1, 4, 4,-1,-1,-1]  // legs spread
        frame1[12] = [-1, 4, 4,-1,-1,-1,-1,-1, 4, 4,-1,-1]  // stumbling
        frame1[13] = [-1, 5, 5,-1,-1,-1,-1,-1, 5, 5,-1,-1]
        frame1[14] = [ 5, 5, 5,-1,-1,-1,-1,-1, 5, 5, 5,-1]
        frame1[15] = [ 5, 5,-1,-1,-1,-1,-1,-1,-1, 5, 5,-1]

        return [frame0, frame1]
    }

    // MARK: - Goalie Palette

    private static func goaliePalette(teamColors: TeamColors) -> [UIColor] {
        let skin = UIColor(hex: "FFD5B0")
        let dark = UIColor(hex: "2A2A2A")
        let pads = UIColor(hex: "EEEEEE")
        return [
            skin,                          // 0
            teamColors.primaryColor,       // 1 - helmet/mask
            teamColors.primaryColor,       // 2 - jersey
            teamColors.secondaryColor,     // 3 - jersey accent
            UIColor(hex: "333344"),        // 4 - pants
            dark,                          // 5 - skates
            pads,                          // 6 - pads
            teamColors.accentColor,        // 7 - stripe
            UIColor(hex: "8B4513"),        // 8 - blocker/glove
        ]
    }

    // MARK: - Goalie Base Template (14x18)

    private static func goalieBaseData() -> [[Int]] {
        return [
            [-1,-1,-1,-1,-1, 1, 1, 1, 1,-1,-1,-1,-1,-1],  // row 0: helmet top
            [-1,-1,-1,-1, 1, 1, 1, 1, 1, 1,-1,-1,-1,-1],  // row 1: helmet
            [-1,-1,-1,-1, 1, 1, 1, 1, 1, 1,-1,-1,-1,-1],  // row 2: mask
            [-1,-1,-1,-1, 1, 0, 1, 1, 0, 1,-1,-1,-1,-1],  // row 3: face
            [-1,-1,-1, 2, 2, 3, 3, 3, 3, 2, 2,-1,-1,-1],  // row 4: shoulders
            [-1,-1, 8, 2, 2, 3, 3, 3, 3, 2, 2, 8,-1,-1],  // row 5: jersey + blocker/glove
            [-1,-1, 8, 2, 7, 7, 7, 7, 7, 7, 2, 8,-1,-1],  // row 6: jersey stripe
            [-1,-1, 8, 2, 2, 3, 3, 3, 3, 2, 2, 8,-1,-1],  // row 7: jersey bottom
            [-1,-1,-1, 2, 2, 2, 2, 2, 2, 2, 2,-1,-1,-1],  // row 8: waist
            [-1,-1,-1, 4, 4, 4, 4, 4, 4, 4, 4,-1,-1,-1],  // row 9: pants
            [-1,-1, 6, 6, 4, 4, 4, 4, 4, 4, 6, 6,-1,-1],  // row 10: pants + pad edges
            [-1,-1, 6, 6, 4, 4,-1,-1, 4, 4, 6, 6,-1,-1],  // row 11: legs with pads
            [-1,-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1,-1],  // row 12: leg pads
            [-1,-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1,-1],  // row 13: leg pads
            [-1,-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1,-1],  // row 14: leg pads lower
            [-1, 5, 5, 6, 6, 5,-1,-1, 5, 6, 6, 5, 5,-1],  // row 15: skate + pad base
            [-1, 5, 5, 5, 5, 5,-1,-1, 5, 5, 5, 5, 5,-1],  // row 16: skate blades
            [-1, 5, 5,-1,-1,-1,-1,-1,-1,-1,-1, 5, 5,-1],  // row 17: blade edges
        ]
    }

    // MARK: - Goalie Static Texture

    static func goalieTexture(teamColors: TeamColors, direction: SpriteDirection = .right) -> SKTexture {
        let key = "goalie_\(teamColors.primary)_\(teamColors.secondary)_\(direction)"
        if let cached = textureCache[key] { return cached }

        var data = goalieBaseData()
        if direction == .left {
            data = data.map { $0.reversed() }
        }

        let tex = texture(from: data, palette: goaliePalette(teamColors: teamColors))
        textureCache[key] = tex
        return tex
    }

    // MARK: - Goalie Animation Frames

    static func goalieFrames(teamColors: TeamColors, state: GoalieAnimState, direction: SpriteDirection = .right) -> [SKTexture] {
        let key = "goalieAnim_\(teamColors.primary)_\(teamColors.secondary)_\(state)_\(direction)"
        if let cached = animationCache[key] { return cached }

        let palette = goaliePalette(teamColors: teamColors)
        var frameDataArrays: [[[Int]]]

        switch state {
        case .idle:
            frameDataArrays = [goalieBaseData()]

        case .saveLeft:
            frameDataArrays = goalieSaveLeftFrames()

        case .saveRight:
            frameDataArrays = goalieSaveRightFrames()

        case .butterfly:
            frameDataArrays = goalieButterflyFrames()
        }

        if direction == .left {
            frameDataArrays = frameDataArrays.map { frame in
                frame.map { $0.reversed() }
            }
        }

        let textures = frameDataArrays.map { frameData in
            texture(from: frameData, palette: palette)
        }

        animationCache[key] = textures
        return textures
    }

    // MARK: - Goalie Save Left Frames (2 frames)

    private static func goalieSaveLeftFrames() -> [[[Int]]] {
        let base = goalieBaseData()

        // Frame 0: Lean left, blocker hand extended
        var frame0 = base
        frame0[3]  = [-1,-1,-1, 1, 0, 1, 1, 0, 1,-1,-1,-1,-1,-1]  // head shifted left
        frame0[4]  = [-1,-1, 2, 2, 3, 3, 3, 3, 2, 2,-1,-1,-1,-1]  // shoulders shifted left
        frame0[5]  = [ 8, 8, 8, 2, 3, 3, 3, 3, 2, 2, 8,-1,-1,-1]  // blocker extended far left
        frame0[6]  = [ 8, 8, 8, 7, 7, 7, 7, 7, 7, 2, 8,-1,-1,-1]  // stripe shifted
        frame0[7]  = [-1,-1, 8, 2, 3, 3, 3, 3, 2, 2, 8,-1,-1,-1]  // jersey bottom
        frame0[10] = [-1, 6, 6, 4, 4, 4, 4, 4, 4, 6, 6,-1,-1,-1]  // pads shifted left
        frame0[11] = [-1, 6, 6, 4, 4,-1,-1, 4, 4, 6, 6,-1,-1,-1]  // legs shifted left

        // Frame 1: Full stretch left
        var frame1 = frame0
        frame1[5]  = [ 8, 8, 8, 8, 2, 3, 3, 3, 2, 2, 8,-1,-1,-1]  // blocker even further
        frame1[12] = [-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1,-1,-1]  // pads shifted
        frame1[13] = [-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1,-1,-1]
        frame1[14] = [-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1,-1,-1]

        return [frame0, frame1]
    }

    // MARK: - Goalie Save Right Frames (2 frames)

    private static func goalieSaveRightFrames() -> [[[Int]]] {
        let base = goalieBaseData()

        // Frame 0: Lean right, glove hand extended
        var frame0 = base
        frame0[3]  = [-1,-1,-1,-1,-1, 1, 0, 1, 1, 0, 1,-1,-1,-1]  // head shifted right
        frame0[4]  = [-1,-1,-1,-1, 2, 2, 3, 3, 3, 3, 2, 2,-1,-1]  // shoulders shifted right
        frame0[5]  = [-1,-1,-1, 8, 2, 2, 3, 3, 3, 3, 2, 8, 8, 8]  // glove extended far right
        frame0[6]  = [-1,-1,-1, 8, 2, 7, 7, 7, 7, 7, 7, 8, 8, 8]  // stripe shifted
        frame0[7]  = [-1,-1,-1, 8, 2, 2, 3, 3, 3, 3, 2, 8,-1,-1]  // jersey bottom
        frame0[10] = [-1,-1,-1, 6, 6, 4, 4, 4, 4, 4, 4, 6, 6,-1]  // pads shifted right
        frame0[11] = [-1,-1,-1, 6, 6, 4, 4,-1,-1, 4, 4, 6, 6,-1]  // legs shifted right

        // Frame 1: Full stretch right
        var frame1 = frame0
        frame1[5]  = [-1,-1,-1, 8, 2, 2, 3, 3, 3, 2, 8, 8, 8, 8]  // glove even further
        frame1[12] = [-1,-1,-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1]
        frame1[13] = [-1,-1,-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1]
        frame1[14] = [-1,-1,-1, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6,-1]

        return [frame0, frame1]
    }

    // MARK: - Goalie Butterfly Frames (2 frames)

    private static func goalieButterflyFrames() -> [[[Int]]] {
        let base = goalieBaseData()

        // Frame 0: Dropping down - knees bending, pads starting to spread
        var frame0 = base
        frame0[8]  = [-1,-1, 8, 2, 2, 2, 2, 2, 2, 2, 2, 8,-1,-1]  // arms out wider
        frame0[9]  = [-1,-1,-1, 4, 4, 4, 4, 4, 4, 4, 4,-1,-1,-1]  // pants
        frame0[10] = [-1, 6, 6, 6, 4, 4, 4, 4, 4, 4, 6, 6, 6,-1]  // pads wider
        frame0[11] = [-1, 6, 6, 6, 6, 4, 4, 4, 4, 6, 6, 6, 6,-1]  // legs spreading
        frame0[12] = [ 6, 6, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6, 6, 6]  // pads wide
        frame0[13] = [ 6, 6, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6, 6, 6]  // pads wide
        frame0[14] = [ 6, 6, 6, 6, 6, 6,-1,-1, 6, 6, 6, 6, 6, 6]  // pads on ice
        frame0[15] = [ 5, 5, 5, 6, 6, 5,-1,-1, 5, 6, 6, 5, 5, 5]  // skates wide
        frame0[16] = [ 5, 5, 5, 5, 5, 5,-1,-1, 5, 5, 5, 5, 5, 5]  // blades wide
        frame0[17] = [ 5, 5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1, 5, 5]  // blade tips far out

        // Frame 1: Full butterfly - completely down, pads flush on ice
        var frame1 = base
        // Upper body stays roughly the same but lower
        frame1[8]  = [-1, 8, 8, 2, 2, 2, 2, 2, 2, 2, 2, 8, 8,-1]  // arms wide with blocker/glove
        frame1[9]  = [-1,-1,-1, 4, 4, 4, 4, 4, 4, 4, 4,-1,-1,-1]  // pants
        frame1[10] = [-1, 6, 6, 6, 4, 4, 4, 4, 4, 4, 6, 6, 6,-1]  // pads start
        frame1[11] = [ 6, 6, 6, 6, 6, 4, 4, 4, 4, 6, 6, 6, 6, 6]  // pads spreading
        frame1[12] = [ 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]  // pads fully flat
        frame1[13] = [ 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]  // pads fully flat
        frame1[14] = [ 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]  // pads on ice
        frame1[15] = [ 5, 5, 5, 6, 6, 5, 5, 5, 5, 6, 6, 5, 5, 5]  // skates under pads
        frame1[16] = [ 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]  // blades flat
        frame1[17] = [ 5, 5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1, 5, 5]  // blade edges

        return [frame0, frame1]
    }

    // MARK: - Puck Texture

    static func puckTexture() -> SKTexture {
        let key = "puck"
        if let cached = textureCache[key] { return cached }

        let black = UIColor(hex: "111111")
        let dark  = UIColor(hex: "222222")
        let palette = [black, dark]

        let data: [[Int]] = [
            [-1, 0, 0, 0,-1],
            [ 0, 0, 1, 0, 0],
            [ 0, 1, 1, 1, 0],
            [ 0, 0, 1, 0, 0],
            [-1, 0, 0, 0,-1],
        ]

        let tex = texture(from: data, palette: palette, scale: kPixelSize * 0.8)
        textureCache[key] = tex
        return tex
    }

    // MARK: - Goal Net Texture

    static func goalNetTexture() -> SKTexture {
        let key = "goalnet_v2"
        if let cached = textureCache[key] { return cached }

        let red = UIColor(hex: "CC0000")
        let redLight = UIColor(hex: "DD2222")
        let white = UIColor(hex: "FFFFFF")
        let netGray = UIColor(hex: "CCCCCC")
        let meshBg = UIColor(hex: "AAAAAA")
        let palette = [red, redLight, white, netGray, meshBg]
        // 0=red post, 1=red light (crossbar highlight), 2=white net cord, 3=gray net cord, 4=mesh background

        // Texture axes must match sprite axes:
        //   cols → x-axis → sprite width = goalDepth (back-to-front)
        //   rows → y-axis → sprite height = goalWidth (top post to bottom post)
        let cols = Int(GameConfig.goalDepth / kPixelSize)   // 10 — depth direction
        let rows = Int(GameConfig.goalWidth / kPixelSize)   // 20 — opening width
        var data = [[Int]](repeating: [Int](repeating: -1, count: cols), count: rows)

        for r in 0..<rows {
            for c in 0..<cols {
                // Red posts on top and bottom edges (sides of the opening)
                if r < 2 || r >= rows - 2 {
                    data[r][c] = (c >= cols - 2) ? 1 : 0  // highlight on crossbar column
                }
                // Crossbar at the mouth (rightmost columns = opening for facingRight)
                else if c >= cols - 2 {
                    data[r][c] = (c == cols - 1) ? 1 : 0
                }
                // Back of net (leftmost columns)
                else if c < 1 {
                    data[r][c] = 3  // gray back edge
                }
                // Interior: netting mesh pattern
                else {
                    let isNetCord = (r % 3 == 0) || (c % 3 == 0)
                    if isNetCord {
                        data[r][c] = ((r + c) % 2 == 0) ? 2 : 3
                    } else {
                        data[r][c] = 4
                    }
                }
            }
        }

        let tex = texture(from: data, palette: palette)
        textureCache[key] = tex
        return tex
    }

    // MARK: - Ice Tile Texture (64x64 repeating tile)

    static func iceTileTexture() -> SKTexture {
        let key = "iceTile"
        if let cached = textureCache[key] { return cached }

        let tileSize: CGFloat = 64
        let size = CGSize(width: tileSize, height: tileSize)
        let renderer = UIGraphicsImageRenderer(size: size)

        // Use a seeded-style approach with deterministic positions for seamless tiling
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setAllowsAntialiasing(false)
            gc.interpolationQuality = .none

            // Base ice color fill
            RetroPalette.ice.setFill()
            gc.fill(CGRect(origin: .zero, size: size))

            // Subtle lighter specks (very faint variation)
            let speckColor = RetroPalette.iceLight.withAlphaComponent(0.4)
            speckColor.setFill()

            // Deterministic speck positions for consistent tiling
            let speckPositions: [(CGFloat, CGFloat)] = [
                (7, 3), (23, 11), (45, 8), (58, 19),
                (12, 29), (34, 37), (51, 44), (5, 53),
                (28, 55), (47, 61), (60, 33), (15, 47),
                (39, 22), (9, 41), (55, 7), (31, 59),
            ]
            for (sx, sy) in speckPositions {
                gc.fill(CGRect(x: sx, y: sy, width: 2, height: 2))
            }

            // Scratch marks: thin dark lines at various angles
            let scratchColor = UIColor(hex: "D0D8EA").withAlphaComponent(0.5)
            gc.setStrokeColor(scratchColor.cgColor)
            gc.setLineWidth(0.5)

            // Scratch 1: diagonal short line
            gc.move(to: CGPoint(x: 8, y: 14))
            gc.addLine(to: CGPoint(x: 14, y: 18))
            gc.strokePath()

            // Scratch 2: nearly horizontal
            gc.move(to: CGPoint(x: 35, y: 30))
            gc.addLine(to: CGPoint(x: 46, y: 32))
            gc.strokePath()

            // Scratch 3: curved scratch
            gc.move(to: CGPoint(x: 50, y: 50))
            gc.addLine(to: CGPoint(x: 56, y: 45))
            gc.strokePath()

            // Scratch 4: small nick
            gc.move(to: CGPoint(x: 20, y: 48))
            gc.addLine(to: CGPoint(x: 24, y: 46))
            gc.strokePath()

            // Scratch 5: longer diagonal
            gc.move(to: CGPoint(x: 3, y: 60))
            gc.addLine(to: CGPoint(x: 12, y: 55))
            gc.strokePath()

            // A few more subtle shade variations (slightly blue tint spots)
            let frostColor = UIColor(hex: "E0E8F8").withAlphaComponent(0.3)
            frostColor.setFill()
            gc.fill(CGRect(x: 18, y: 6, width: 3, height: 3))
            gc.fill(CGRect(x: 42, y: 42, width: 4, height: 2))
            gc.fill(CGRect(x: 56, y: 14, width: 2, height: 4))
        }

        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        textureCache[key] = tex
        return tex
    }

    // MARK: - Board Texture

    static func boardTexture(segment: BoardSegment) -> SKTexture {
        let key = "board_\(segment)"
        if let cached = textureCache[key] { return cached }

        let tex: SKTexture

        switch segment {
        case .straight:
            tex = boardStraightTexture()
        case .corner:
            tex = boardCornerTexture()
        }

        textureCache[key] = tex
        return tex
    }

    /// Straight board segment: 3 horizontal layers
    /// Top (outer): white dasher boards
    /// Middle: yellow kickplate
    /// Bottom (inner/ice-side): dark rail/cap
    private static func boardStraightTexture() -> SKTexture {
        let width: CGFloat = 64
        let height: CGFloat = 12
        let size = CGSize(width: width, height: height)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setAllowsAntialiasing(false)
            gc.interpolationQuality = .none

            let dasherHeight: CGFloat = 5
            let kickplateHeight: CGFloat = 4
            let railHeight: CGFloat = 3

            // Layer 1: White dasher boards (outer)
            UIColor.white.setFill()
            gc.fill(CGRect(x: 0, y: 0, width: width, height: dasherHeight))

            // Subtle shadow line at top of dasher
            UIColor(hex: "DDDDDD").setFill()
            gc.fill(CGRect(x: 0, y: 0, width: width, height: 1))

            // Layer 2: Yellow kickplate (middle)
            UIColor(hex: "DDAA22").setFill()
            gc.fill(CGRect(x: 0, y: dasherHeight, width: width, height: kickplateHeight))

            // Darker yellow line for depth
            UIColor(hex: "BB8811").setFill()
            gc.fill(CGRect(x: 0, y: dasherHeight, width: width, height: 1))

            // Layer 3: Dark rail (inner, ice-side)
            UIColor(hex: "333333").setFill()
            gc.fill(CGRect(x: 0, y: dasherHeight + kickplateHeight, width: width, height: railHeight))

            // Highlight on rail
            UIColor(hex: "555555").setFill()
            gc.fill(CGRect(x: 0, y: dasherHeight + kickplateHeight, width: width, height: 1))
        }

        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    /// Corner board segment: curved piece with the same 3 layers
    private static func boardCornerTexture() -> SKTexture {
        let tileSize: CGFloat = 48
        let size = CGSize(width: tileSize, height: tileSize)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setAllowsAntialiasing(false)
            gc.interpolationQuality = .none

            // Draw concentric quarter-circle arcs from outer to inner
            let center = CGPoint(x: tileSize, y: 0)  // bottom-right corner as center

            // Outer dasher (white) - outermost arc band
            let dasherOuter: CGFloat = tileSize
            let dasherInner: CGFloat = tileSize - 5
            UIColor.white.setFill()
            fillArcBand(in: gc, center: center, outerR: dasherOuter, innerR: dasherInner, startAngle: .pi, endAngle: .pi * 1.5)

            // Shadow line on outer edge
            gc.setStrokeColor(UIColor(hex: "DDDDDD").cgColor)
            gc.setLineWidth(1)
            let shadowPath = UIBezierPath(arcCenter: center, radius: dasherOuter - 0.5, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
            gc.addPath(shadowPath.cgPath)
            gc.strokePath()

            // Kickplate (yellow) - middle arc band
            let kickOuter = dasherInner
            let kickInner = dasherInner - 4
            UIColor(hex: "DDAA22").setFill()
            fillArcBand(in: gc, center: center, outerR: kickOuter, innerR: kickInner, startAngle: .pi, endAngle: .pi * 1.5)

            // Rail (dark) - innermost arc band
            let railOuter = kickInner
            let railInner = kickInner - 3
            UIColor(hex: "333333").setFill()
            fillArcBand(in: gc, center: center, outerR: railOuter, innerR: railInner, startAngle: .pi, endAngle: .pi * 1.5)

            // Highlight on rail
            gc.setStrokeColor(UIColor(hex: "555555").cgColor)
            gc.setLineWidth(1)
            let highlightPath = UIBezierPath(arcCenter: center, radius: railOuter - 0.5, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
            gc.addPath(highlightPath.cgPath)
            gc.strokePath()
        }

        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    /// Helper: fill an arc-shaped band between two radii
    private static func fillArcBand(in gc: CGContext, center: CGPoint, outerR: CGFloat, innerR: CGFloat, startAngle: CGFloat, endAngle: CGFloat) {
        let path = UIBezierPath()
        path.addArc(withCenter: center, radius: outerR, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.addArc(withCenter: center, radius: innerR, startAngle: endAngle, endAngle: startAngle, clockwise: false)
        path.close()
        gc.addPath(path.cgPath)
        gc.fillPath()
    }

    // MARK: - Legacy Ice Texture (full-size, kept for backward compatibility)

    static func iceTexture(width: CGFloat, height: CGFloat) -> SKTexture {
        let key = "ice_\(Int(width))x\(Int(height))"
        if let cached = textureCache[key] { return cached }

        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext

            // Base ice color
            RetroPalette.ice.setFill()
            gc.fill(CGRect(origin: .zero, size: size))

            // Add subtle pixel noise for ice texture
            let step = kPixelSize * 2
            for x in stride(from: CGFloat(0), to: width, by: step) {
                for y in stride(from: CGFloat(0), to: height, by: step) {
                    if Int.random(in: 0...10) == 0 {
                        RetroPalette.iceLight.withAlphaComponent(0.5).setFill()
                        gc.fill(CGRect(x: x, y: y, width: step, height: step))
                    }
                }
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        textureCache[key] = tex
        return tex
    }

    // MARK: - Team Logo (Simple geometric, 16x16)

    static func teamLogo(colors: TeamColors, index: Int) -> SKTexture {
        let key = "logo_\(index)"
        if let cached = textureCache[key] { return cached }

        let p = colors.primaryColor
        let s = colors.secondaryColor
        let a = colors.accentColor
        let palette = [p, s, a, UIColor.white]

        // Different simple geometric patterns per team index
        let patterns: [[[Int]]] = [
            // 0: Diamond
            [
                [-1,-1,-1,-1,-1,-1,-1, 0,-1,-1,-1,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1,-1, 0, 1, 0,-1,-1,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 1, 1, 0,-1,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1, 0, 1, 1, 2, 1, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1, 0, 1, 1, 2, 2, 2, 1, 1, 0,-1,-1,-1,-1],
                [-1,-1, 0, 1, 1, 2, 2, 3, 2, 2, 1, 1, 0,-1,-1,-1],
                [-1, 0, 1, 1, 2, 2, 3, 3, 3, 2, 2, 1, 1, 0,-1,-1],
                [ 0, 1, 1, 2, 2, 3, 3, 3, 3, 3, 2, 2, 1, 1, 0,-1],
                [-1, 0, 1, 1, 2, 2, 3, 3, 3, 2, 2, 1, 1, 0,-1,-1],
                [-1,-1, 0, 1, 1, 2, 2, 3, 2, 2, 1, 1, 0,-1,-1,-1],
                [-1,-1,-1, 0, 1, 1, 2, 2, 2, 1, 1, 0,-1,-1,-1,-1],
                [-1,-1,-1,-1, 0, 1, 1, 2, 1, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 1, 1, 0,-1,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1,-1, 0, 1, 0,-1,-1,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1,-1,-1, 0,-1,-1,-1,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1],
            ],
            // 1: Cross/Plus
            [
                [-1,-1,-1,-1,-1, 0, 0, 0, 0, 0, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 1, 1, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 2, 2, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 2, 2, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 2, 2, 1, 0,-1,-1,-1,-1,-1],
                [ 0, 0, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0],
                [ 0, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 0],
                [ 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0],
                [ 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0],
                [ 0, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 0],
                [ 0, 0, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0],
                [-1,-1,-1,-1,-1, 0, 1, 2, 2, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 2, 2, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 2, 2, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 1, 1, 1, 1, 0,-1,-1,-1,-1,-1],
                [-1,-1,-1,-1,-1, 0, 0, 0, 0, 0, 0,-1,-1,-1,-1,-1],
            ],
        ]

        let patternIndex = index % patterns.count
        let tex = texture(from: patterns[patternIndex], palette: palette, scale: kPixelSize)
        textureCache[key] = tex
        return tex
    }

    // MARK: - Arrow Indicator

    static func arrowTexture(color: UIColor) -> SKTexture {
        let key = "arrow_\(color.hexString)"
        if let cached = textureCache[key] { return cached }

        let palette = [color]
        let data: [[Int]] = [
            [-1,-1,-1, 0,-1,-1,-1],
            [-1,-1, 0, 0, 0,-1,-1],
            [-1, 0, 0, 0, 0, 0,-1],
            [ 0, 0, 0, 0, 0, 0, 0],
        ]
        let tex = texture(from: data, palette: palette, scale: 2)
        textureCache[key] = tex
        return tex
    }

    // MARK: - Solid Rectangle Texture

    static func solidTexture(color: UIColor, width: Int, height: Int) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: - Rounded Rect Button Texture

    static func buttonTexture(width: CGFloat, height: CGFloat, color: UIColor, borderColor: UIColor? = nil) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setAllowsAntialiasing(false)
            gc.interpolationQuality = .none

            let p = kPixelSize
            let rect = CGRect(origin: .zero, size: size)

            // Border
            if let bc = borderColor {
                bc.setFill()
                gc.fill(rect)
            }

            // Inner fill (inset by pixel border)
            let borderWidth = borderColor != nil ? p : 0
            let inner = rect.insetBy(dx: borderWidth, dy: borderWidth)
            color.setFill()
            gc.fill(inner)

            // Pixel-art highlight (top edge)
            UIColor.white.withAlphaComponent(0.2).setFill()
            gc.fill(CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: p))

            // Pixel-art shadow (bottom edge)
            UIColor.black.withAlphaComponent(0.3).setFill()
            gc.fill(CGRect(x: inner.minX, y: inner.maxY - p, width: inner.width, height: p))
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: - Panel/Window Texture

    static func panelTexture(width: CGFloat, height: CGFloat) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setAllowsAntialiasing(false)

            let p = kPixelSize
            let rect = CGRect(origin: .zero, size: size)

            // Outer border
            UIColor(hex: "444466").setFill()
            gc.fill(rect)

            // Inner background
            RetroPalette.darkPanel.setFill()
            gc.fill(rect.insetBy(dx: p, dy: p))

            // Top highlight
            UIColor.white.withAlphaComponent(0.1).setFill()
            gc.fill(CGRect(x: p, y: p, width: rect.width - 2 * p, height: p))
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: - Star Rating (for player cards)

    static func starTexture(filled: Bool) -> SKTexture {
        let key = "star_\(filled)"
        if let cached = textureCache[key] { return cached }

        let color = filled ? UIColor(hex: "F5C518") : UIColor(hex: "444444")
        let palette = [color]

        let data: [[Int]] = [
            [-1,-1,-1,-1, 0,-1,-1,-1,-1],
            [-1,-1,-1, 0, 0, 0,-1,-1,-1],
            [ 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [-1, 0, 0, 0, 0, 0, 0, 0,-1],
            [-1,-1, 0, 0, 0, 0, 0,-1,-1],
            [-1, 0, 0, 0,-1, 0, 0, 0,-1],
            [ 0, 0, 0,-1,-1,-1, 0, 0, 0],
        ]

        let tex = texture(from: data, palette: palette, scale: 2)
        textureCache[key] = tex
        return tex
    }

    // MARK: - Trophy

    static func trophyTexture() -> SKTexture {
        let key = "trophy"
        if let cached = textureCache[key] { return cached }

        let gold = UIColor(hex: "F5C518")
        let darkGold = UIColor(hex: "B8960F")
        let brown = UIColor(hex: "8B6914")
        let palette = [gold, darkGold, brown]

        let data: [[Int]] = [
            [-1, 0, 0, 0, 0, 0, 0, 0, 0,-1],
            [ 0, 0, 0, 1, 1, 1, 1, 0, 0, 0],
            [ 0, 0, 0, 1, 1, 1, 1, 0, 0, 0],
            [-1, 0, 0, 1, 1, 1, 1, 0, 0,-1],
            [-1,-1, 0, 0, 1, 1, 0, 0,-1,-1],
            [-1,-1,-1, 0, 0, 0, 0,-1,-1,-1],
            [-1,-1,-1,-1, 1, 1,-1,-1,-1,-1],
            [-1,-1,-1,-1, 1, 1,-1,-1,-1,-1],
            [-1,-1,-1, 2, 2, 2, 2,-1,-1,-1],
            [-1,-1, 2, 2, 2, 2, 2, 2,-1,-1],
        ]

        let tex = texture(from: data, palette: palette, scale: kPixelSize)
        textureCache[key] = tex
        return tex
    }
}
