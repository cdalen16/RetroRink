import SpriteKit

// MARK: - Hockey AI Controller (Improved)
class HockeyAI {

    let difficulty: Difficulty
    let rink: RinkNode

    // Throttle timers to avoid recalculating every frame
    private var lastDefenseTime: TimeInterval = 0
    private var lastOffenseTime: TimeInterval = 0
    private let defenseInterval: TimeInterval = 0.3
    private let offenseInterval: TimeInterval = 0.25

    init(difficulty: Difficulty, rink: RinkNode) {
        self.difficulty = difficulty
        self.rink = rink
    }

    // MARK: - Defensive AI
    /// Updates opponent defenders: lane-based coverage with closest non-goalie pressuring carrier.
    func updateDefenders(
        skaters: [SkaterNode],
        puckPosition: CGPoint,
        puckCarrier: SkaterNode?,
        puckVelocity: CGVector,
        currentTime: TimeInterval
    ) {
        guard currentTime - lastDefenseTime > defenseInterval else { return }
        lastDefenseTime = currentTime

        let reaction = difficulty.aiReactionMultiplier

        // Separate goalie from field players
        let fieldSkaters = skaters.filter { !$0.posType.isGoalie }
        let goalies = skaters.filter { $0.posType.isGoalie }

        // Update goalie separately
        for goalie in goalies {
            updateGoalie(goalie, puckPosition: puckPosition, puckVelocity: puckVelocity)
        }

        guard !fieldSkaters.isEmpty else { return }

        if let carrier = puckCarrier {
            // Find closest non-goalie defender to pressure the puck carrier
            let sortedByDistance = fieldSkaters.sorted {
                $0.position.distance(to: carrier.position) < $1.position.distance(to: carrier.position)
            }

            for (index, skater) in sortedByDistance.enumerated() {
                if index == 0 {
                    // Closest defender: pressure the carrier directly
                    let target = predictPosition(of: carrier, leadTime: 0.3 * Double(reaction))
                    skater.moveToward(target, speed: skater.maxSpeed * reaction)
                } else {
                    // Other defenders: cover passing lanes
                    // Position between puck carrier and the nearest open offensive teammate
                    let homePos = defensiveHomePosition(for: skater, puckPosition: puckPosition)
                    let laneTarget = coverPassingLane(
                        defender: skater,
                        carrier: carrier,
                        homePosition: homePos,
                        puckPosition: puckPosition
                    )
                    skater.moveToward(laneTarget, speed: skater.maxSpeed * 0.7 * reaction)
                }
            }
        } else {
            // Puck is loose -- chase or hold
            let sortedByDistance = fieldSkaters.sorted {
                $0.position.distance(to: puckPosition) < $1.position.distance(to: puckPosition)
            }

            for (index, skater) in sortedByDistance.enumerated() {
                if index == 0 && skater.position.distance(to: puckPosition) < 120 {
                    // Closest goes after loose puck
                    skater.moveToward(puckPosition, speed: skater.maxSpeed * reaction)
                } else {
                    let homePos = defensiveHomePosition(for: skater, puckPosition: puckPosition)
                    let blended = CGPoint(
                        x: homePos.x * 0.6 + puckPosition.x * 0.4,
                        y: homePos.y * 0.6 + puckPosition.y * 0.4
                    )
                    skater.moveToward(blended, speed: skater.maxSpeed * 0.5 * reaction)
                }
            }
        }
    }

    /// Covers a passing lane: positions between carrier and a point near its home position
    private func coverPassingLane(
        defender: SkaterNode,
        carrier: SkaterNode,
        homePosition: CGPoint,
        puckPosition: CGPoint
    ) -> CGPoint {
        // Blend between home position and the midpoint between carrier and home
        let midX = (carrier.position.x + homePosition.x) / 2
        let midY = (carrier.position.y + homePosition.y) / 2
        return CGPoint(
            x: midX * 0.5 + homePosition.x * 0.5,
            y: midY * 0.5 + homePosition.y * 0.5
        )
    }

    // MARK: - Offensive AI (Teammates)
    /// AI for player's teammates: skate to open ice, give-and-go patterns, signal for passes.
    func updateOffensiveAI(
        skaters: [SkaterNode],
        puckCarrier: SkaterNode?,
        attackingRight: Bool,
        opponents: [SkaterNode],
        currentTime: TimeInterval
    ) {
        guard currentTime - lastOffenseTime > offenseInterval else { return }
        lastOffenseTime = currentTime

        for skater in skaters {
            // Skip the carrier and goalies
            guard skater.playerID != puckCarrier?.playerID else { continue }
            if skater.posType.isGoalie { continue }

            let basePos = offensiveHomePosition(for: skater, attackingRight: attackingRight)

            // Find open ice: move away from nearest defender
            let nearestDefender = opponents.filter { !$0.posType.isGoalie }
                .min { $0.position.distance(to: basePos) < $1.position.distance(to: basePos) }

            var target = basePos

            if let defender = nearestDefender {
                let defDist = defender.position.distance(to: basePos)
                if defDist < 80 {
                    // Too close to defender: shift away
                    let away = CGPoint(
                        x: basePos.x - defender.position.x,
                        y: basePos.y - defender.position.y
                    ).normalized()
                    target = CGPoint(
                        x: basePos.x + away.x * 40,
                        y: basePos.y + away.y * 40
                    )
                }
            }

            // Give-and-go: if carrier is nearby, cut toward the goal
            if let carrier = puckCarrier {
                let distToCarrier = skater.position.distance(to: carrier.position)
                if distToCarrier < 100 && skater.posType.isForward {
                    // Cut toward goal for give-and-go
                    let goalX: CGFloat = attackingRight
                        ? rink.rinkWidth / 2 - 100
                        : -rink.rinkWidth / 2 + 100
                    target = CGPoint(
                        x: goalX,
                        y: skater.position.y + CGFloat.random(in: -30...30)
                    )
                }
            }

            // Clamp target inside rink
            let hw = rink.rinkWidth / 2 - 20
            let hh = rink.rinkHeight / 2 - 20
            target.x = max(-hw, min(hw, target.x))
            target.y = max(-hh, min(hh, target.y))

            // Add slight jitter for realistic movement
            let jitter = CGPoint(
                x: CGFloat.random(in: -10...10),
                y: CGFloat.random(in: -10...10)
            )
            target = target + jitter

            skater.moveToward(target, speed: skater.maxSpeed * 0.6)
        }
    }

    // MARK: - Goalie AI
    private func updateGoalie(_ goalie: SkaterNode, puckPosition: CGPoint, puckVelocity: CGVector) {
        let reaction = difficulty.aiReactionMultiplier

        // Determine which goal this goalie defends
        let goalCenter: CGPoint
        let maxGoalieRange: CGFloat = 35

        if goalie.teamIndex == 1 {
            goalCenter = rink.rightGoalMouth
        } else {
            goalCenter = rink.leftGoalMouth
        }

        let dx = puckPosition.x - goalCenter.x
        let dy = puckPosition.y - goalCenter.y
        let distToPuck = hypot(dx, dy)

        // Square up to puck angle
        var targetY = goalCenter.y
        if distToPuck > 0 {
            targetY = goalCenter.y + (dy / distToPuck) * min(maxGoalieRange, abs(dy) * 0.6)
        }

        // Cut angles: move out from crease when puck is far away
        var targetX = goalCenter.x
        let puckFar = distToPuck > 250
        if puckFar {
            // Step out slightly to cut down angle
            let challengeDistance: CGFloat = 15 * reaction
            targetX += goalie.teamIndex == 1 ? -challengeDistance : challengeDistance
        } else {
            // Stay closer to goal line
            targetX += goalie.teamIndex == 1 ? -5 : 5
        }

        // Butterfly: detect if puck velocity is heading fast toward the goal
        let puckSpeed = hypot(puckVelocity.dx, puckVelocity.dy)
        let headingToward: Bool
        if goalie.teamIndex == 1 {
            headingToward = puckVelocity.dx > 100 && puckPosition.x < goalCenter.x + 200
        } else {
            headingToward = puckVelocity.dx < -100 && puckPosition.x > goalCenter.x - 200
        }

        if puckSpeed > 300 && headingToward {
            // Butterfly: drop and spread - widen Y tracking
            targetY = goalCenter.y + (dy / max(1, distToPuck)) * min(maxGoalieRange * 1.3, abs(dy) * 0.8)
        }

        let target = CGPoint(x: targetX, y: targetY)
        let goalieSpeed = CGFloat(goalie.playerStats.reflexes) * 2.0 + 80
        goalie.moveToward(target, speed: goalieSpeed * reaction)
    }

    // MARK: - Body Check / Puck Steal
    /// Returns true if the defender successfully knocks the puck loose from the carrier.
    /// Called at throttled intervals (not every frame), so chances are per-check, not per-frame.
    func checkBodyCheck(defender: SkaterNode, puckCarrier: SkaterNode) -> Bool {
        let dist = defender.position.distance(to: puckCarrier.position)
        guard dist < GameConfig.skaterRadius * 2.0 else { return false }

        let checkRating = Double(defender.playerStats.checking)
        let handleRating = Double(puckCarrier.playerStats.puckHandling)
        let difficultyBonus = Double(difficulty.aiReactionMultiplier)

        // Factor in carrier speed: harder to hit if moving fast
        let carrierSpeed = hypot(
            puckCarrier.physicsBody?.velocity.dx ?? 0,
            puckCarrier.physicsBody?.velocity.dy ?? 0
        )
        let speedPenalty = min(Double(carrierSpeed) / 400.0, 0.35)

        // Deke state bonus: much harder to check during deke
        let dekePenalty: Double = puckCarrier.animState == .deking ? 0.4 : 0.0

        // Base chance is much lower — this is called every ~0.5s, not every frame
        var stealChance = (checkRating / (checkRating + handleRating)) * difficultyBonus * 0.12
        stealChance -= speedPenalty
        stealChance -= dekePenalty
        stealChance = max(0.005, stealChance)

        if Double.random(in: 0...1) < stealChance {
            defender.playHitAnimation()
            puckCarrier.playHitAnimation()
            return true
        }
        return false
    }

    // MARK: - Save Attempt
    /// Returns true if the goalie saves the shot.
    func attemptSave(
        goalie: SkaterNode,
        shotPower: CGFloat,
        shotAccuracy: CGFloat,
        shooterStats: Player
    ) -> Bool {
        let reflexRating = Double(goalie.playerStats.reflexes) / 99.0
        let positionRating = Double(goalie.playerStats.positioning) / 99.0

        let shotQuality = Double(shotAccuracy) * (Double(shooterStats.shooting) / 99.0)
        let powerFactor = min(Double(shotPower) / Double(GameConfig.shotSpeedMax), 1.0)

        // Base save chance: NHL goalies save ~90% of shots, so start high
        var saveChance = 0.55 + reflexRating * 0.25 + positionRating * 0.15

        // Reduce by shot quality and power (smaller penalty)
        saveChance -= shotQuality * 0.15
        saveChance -= powerFactor * 0.08

        // Difficulty modifier
        saveChance += difficulty.saveChanceBonus

        // Clamp: even the worst scenario saves ~40%, best ~92%
        saveChance = max(0.40, min(0.92, saveChance))

        return Double.random(in: 0...1) < saveChance
    }

    // MARK: - Positioning Helpers

    /// Defensive home position for a skater based on their role and puck location.
    private func defensiveHomePosition(for skater: SkaterNode, puckPosition: CGPoint) -> CGPoint {
        let hw = rink.rinkWidth / 2
        let hh = rink.rinkHeight / 2

        // Defenders of team 1 defend right side, team 0 defends left side
        let goalX: CGFloat = skater.teamIndex == 1 ? hw - 80 : -hw + 80
        let sign: CGFloat = skater.teamIndex == 1 ? -1 : 1

        switch skater.posType {
        case .leftDefense:
            return CGPoint(x: goalX + sign * 30, y: hh * 0.35)
        case .rightDefense:
            return CGPoint(x: goalX + sign * 30, y: -hh * 0.35)
        case .center:
            return CGPoint(x: goalX + sign * 80, y: 0)
        case .leftWing:
            return CGPoint(x: goalX + sign * 60, y: hh * 0.5)
        case .rightWing:
            return CGPoint(x: goalX + sign * 60, y: -hh * 0.5)
        case .goalie:
            return CGPoint(x: goalX - sign * 30, y: 0)
        }
    }

    /// Offensive home position for a teammate when attacking.
    private func offensiveHomePosition(for skater: SkaterNode, attackingRight: Bool) -> CGPoint {
        let hw = rink.rinkWidth / 2
        let hh = rink.rinkHeight / 2
        let zoneX: CGFloat = attackingRight ? hw * 0.45 : -hw * 0.45
        let fwd: CGFloat = attackingRight ? 1 : -1

        switch skater.posType {
        case .leftWing:
            return CGPoint(x: zoneX + fwd * 40, y: hh * 0.45)
        case .rightWing:
            return CGPoint(x: zoneX + fwd * 40, y: -hh * 0.45)
        case .center:
            return CGPoint(x: zoneX, y: CGFloat.random(in: -hh * 0.2...hh * 0.2))
        case .leftDefense:
            return CGPoint(x: zoneX - fwd * 80, y: hh * 0.3)
        case .rightDefense:
            return CGPoint(x: zoneX - fwd * 80, y: -hh * 0.3)
        case .goalie:
            return attackingRight ? rink.leftGoalMouth : rink.rightGoalMouth
        }
    }

    /// Predict where a node will be after `leadTime` seconds based on current velocity.
    private func predictPosition(of node: SKNode, leadTime: Double) -> CGPoint {
        guard let vel = node.physicsBody?.velocity else { return node.position }
        return CGPoint(
            x: node.position.x + vel.dx * CGFloat(leadTime),
            y: node.position.y + vel.dy * CGFloat(leadTime)
        )
    }
}
