import SpriteKit

// MARK: - Gameplay Scene - THE MAIN GAME
class GameplayScene: BaseScene, SKPhysicsContactDelegate {

    // MARK: - Team Data
    var homeTeam: Team!
    var awayTeam: Team!
    var scheduleIndex: Int = 0
    var isPlayerHome: Bool = true

    // MARK: - Nodes
    private var rink: RinkNode!
    private var puck: PuckNode!
    private var ai: HockeyAI!
    private var cameraNode: SKCameraNode!

    private var homeSkaters: [SkaterNode] = []
    private var awaySkaters: [SkaterNode] = []
    private var allSkaters: [SkaterNode] { homeSkaters + awaySkaters }
    private var playerSkaters: [SkaterNode] { isPlayerHome ? homeSkaters : awaySkaters }
    private var opponentSkaters: [SkaterNode] { isPlayerHome ? awaySkaters : homeSkaters }
    private var attackingRight: Bool { isPlayerHome }

    // MARK: - State
    private var gameState: GameplayState = .pregame
    private var period: Int = 1
    private var homeScore: Int = 0
    private var awayScore: Int = 0
    private var possessionCount: Int = 0
    private var maxPossessions: Int { GameConfig.possessionsPerPeriod }
    private var goalEvents: [GoalEvent] = []

    // MARK: - Touch State (Two-Hand: Joystick + Action)
    private var joystickTouch: UITouch?          // left thumb: movement
    private var joystickDisplacement: CGPoint = .zero  // normalized direction + magnitude

    enum ActionTouchState {
        case none
        case holding(start: CGPoint, time: TimeInterval)
    }
    private var actionTouchState: ActionTouchState = .none
    private var actionTouch: UITouch?            // right hand: pass/shoot
    private var selectedSkater: SkaterNode?

    // MARK: - HUD (children of cameraNode)
    private var scoreLabel: SKLabelNode!
    private var periodLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!
    private var possessionDots: [SKShapeNode] = []
    private var goalFlash: SKSpriteNode!
    private var hudNode: SKNode!
    private var controlHintBar: SKNode!
    private var shootIndicator: SKNode!
    private var tutorialOverlay: SKNode?
    private var tutorialShown: Bool = false
    private var possessionsPlayed: Int = 0

    // MARK: - Joystick HUD Nodes
    private var joystickBase: SKShapeNode!
    private var joystickThumb: SKShapeNode!
    private var joystickCenter: CGPoint = .zero  // default position in HUD coords
    private var joystickOrigin: CGPoint = .zero   // dynamic origin where touch began

    // MARK: - Camera
    private var cameraShakeTimer: TimeInterval = 0
    private var cameraShakeDuration: TimeInterval = 0
    private var cameraShakeIntensity: CGFloat = 0
    private var celebrationZoom: Bool = false

    // MARK: - Timing
    private var lastUpdateTime: TimeInterval = 0
    private var shotClock: TimeInterval = GameConfig.shotClockDuration

    // MARK: - Body Check Throttle & Puck Protection
    private var lastBodyCheckTime: TimeInterval = 0
    private let bodyCheckInterval: TimeInterval = 0.5  // only check every 0.5s, not every frame
    private var puckProtectionTimer: TimeInterval = 0   // when >0, immune to body checks

    // MARK: - Loose Puck Recovery
    private var loosePuckTimer: TimeInterval = 0
    private var loosePuckPosition: CGPoint = .zero
    private var isLoosePuck: Bool = false
    private let loosePuckRecoveryWindow: TimeInterval = 1.5

    // MARK: - Setup
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: "111122")
        super.didMove(to: view)

        // Zoom in by reducing scene size — shows less of the world
        // Camera stays at scale 1.0 so HUD children render at normal size
        let zoomFactor = CameraConfig.scale
        self.size = CGSize(width: size.width * zoomFactor, height: size.height * zoomFactor)

        view.isMultipleTouchEnabled = true
        isUserInteractionEnabled = true

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupCamera()
        setupRink()
        setupPuck()
        setupSkaters()
        setupHUD()
        setupAI()

        startPregame()
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        cameraNode = SKCameraNode()
        // Don't scale the camera — scale is handled via scene size vs rink size
        // Camera stays at scale 1.0 so HUD children render at normal size
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: - Rink Setup
    private func setupRink() {
        rink = RinkNode()
        addChild(rink)
    }

    // MARK: - Puck Setup
    private func setupPuck() {
        puck = PuckNode()
        puck.position = .zero
        rink.addChild(puck)
    }

    // MARK: - Skaters Setup
    private func setupSkaters() {
        let homeColors = homeTeam.colors
        let awayColors = awayTeam.colors

        // Home team: 1st forward line + 1st defense pair + starting goalie
        let homeFwdLine = homeTeam.forwardLine(0)
        let homeDefPair = homeTeam.defensePair(0)
        let homeGoalie = homeTeam.startingGoaliePlayer

        for player in homeFwdLine {
            let node = SkaterNode(player: player, teamColors: homeColors, teamIndex: 0)
            rink.addChild(node)
            homeSkaters.append(node)
        }
        for player in homeDefPair {
            let node = SkaterNode(player: player, teamColors: homeColors, teamIndex: 0)
            rink.addChild(node)
            homeSkaters.append(node)
        }
        if let goalie = homeGoalie {
            let node = SkaterNode(player: goalie, teamColors: homeColors, teamIndex: 0)
            rink.addChild(node)
            homeSkaters.append(node)
        }

        // Away team
        let awayFwdLine = awayTeam.forwardLine(0)
        let awayDefPair = awayTeam.defensePair(0)
        let awayGoalie = awayTeam.startingGoaliePlayer

        for player in awayFwdLine {
            let node = SkaterNode(player: player, teamColors: awayColors, teamIndex: 1)
            rink.addChild(node)
            awaySkaters.append(node)
        }
        for player in awayDefPair {
            let node = SkaterNode(player: player, teamColors: awayColors, teamIndex: 1)
            rink.addChild(node)
            awaySkaters.append(node)
        }
        if let goalie = awayGoalie {
            let node = SkaterNode(player: goalie, teamColors: awayColors, teamIndex: 1)
            rink.addChild(node)
            awaySkaters.append(node)
        }
    }

    // MARK: - HUD Setup (child of cameraNode, so it stays fixed on screen)
    private func setupHUD() {
        hudNode = SKNode()
        hudNode.zPosition = ZPos.hud
        cameraNode.addChild(hudNode)

        // Camera is at scale 1.0, so HUD coords = screen coords = scene size
        let visW = size.width
        let visH = size.height
        let topY = visH / 2

        // Score box background
        let scoreBg = SKSpriteNode(
            texture: PixelArt.buttonTexture(
                width: 160,
                height: 30,
                color: UIColor(hex: "111111").withAlphaComponent(0.85),
                borderColor: UIColor(hex: "333333")
            ),
            size: CGSize(width: 160, height: 30)
        )
        scoreBg.position = CGPoint(x: 0, y: topY - 18)
        hudNode.addChild(scoreBg)

        // Home abbreviation
        let homeAbbr = RetroFont.label(
            homeTeam.abbreviation,
            size: RetroFont.smallSize,
            color: homeTeam.colors.primaryColor
        )
        homeAbbr.position = CGPoint(x: -55, y: topY - 18)
        homeAbbr.horizontalAlignmentMode = .left
        hudNode.addChild(homeAbbr)

        // Score
        scoreLabel = RetroFont.label("0 - 0", size: RetroFont.bodySize, color: .white)
        scoreLabel.position = CGPoint(x: 0, y: topY - 18)
        hudNode.addChild(scoreLabel)

        // Away abbreviation
        let awayAbbr = RetroFont.label(
            awayTeam.abbreviation,
            size: RetroFont.smallSize,
            color: awayTeam.colors.primaryColor
        )
        awayAbbr.position = CGPoint(x: 55, y: topY - 18)
        awayAbbr.horizontalAlignmentMode = .right
        hudNode.addChild(awayAbbr)

        // Period label
        periodLabel = RetroFont.label("1ST PERIOD", size: RetroFont.tinySize, color: RetroPalette.textGray)
        periodLabel.position = CGPoint(x: 0, y: topY - 34)
        hudNode.addChild(periodLabel)

        // Possession dots
        let dotStartX: CGFloat = -CGFloat(maxPossessions - 1) * 6
        for i in 0..<maxPossessions {
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = UIColor(hex: "333333")
            dot.strokeColor = UIColor(hex: "666666")
            dot.lineWidth = 0.5
            dot.position = CGPoint(x: dotStartX + CGFloat(i) * 12, y: topY - 46)
            dot.zPosition = ZPos.hud
            dot.isAntialiased = false
            hudNode.addChild(dot)
            possessionDots.append(dot)
        }

        // Message label (center of visible area)
        messageLabel = RetroFont.label("", size: RetroFont.headerSize, color: .white)
        messageLabel.position = CGPoint(x: 0, y: 20)
        messageLabel.zPosition = ZPos.overlay
        messageLabel.alpha = 0
        hudNode.addChild(messageLabel)

        // Goal flash overlay (full-screen red)
        goalFlash = SKSpriteNode(color: RetroPalette.goalRed, size: CGSize(width: visW + 40, height: visH + 40))
        goalFlash.position = .zero
        goalFlash.zPosition = ZPos.overlay - 1
        goalFlash.alpha = 0
        hudNode.addChild(goalFlash)

        // --- Persistent Control Hint Bar (bottom-right of screen) ---
        controlHintBar = SKNode()
        controlHintBar.zPosition = ZPos.hud + 1
        let bottomY = -visH / 2 + 14

        let hintBg = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.5),
                                   size: CGSize(width: visW * 0.45, height: 22))
        hintBg.position = CGPoint(x: visW / 4 + 10, y: bottomY)
        controlHintBar.addChild(hintBg)

        let tapHint = RetroFont.label("TAP: Pass", size: RetroFont.tinySize, color: RetroPalette.textGreen)
        tapHint.position = CGPoint(x: visW / 5, y: bottomY)
        controlHintBar.addChild(tapHint)

        let swipeHint = RetroFont.label("SWIPE: Shoot", size: RetroFont.tinySize, color: RetroPalette.gold)
        swipeHint.position = CGPoint(x: visW / 5 + 80, y: bottomY)
        controlHintBar.addChild(swipeHint)

        controlHintBar.alpha = 0
        hudNode.addChild(controlHintBar)

        // --- Virtual Joystick (bottom-left of screen) ---
        let joyR = JoystickConfig.baseRadius
        joystickCenter = CGPoint(x: -visW / 2 + joyR + 20, y: -visH / 2 + joyR + 20)

        joystickBase = SKShapeNode(circleOfRadius: joyR)
        joystickBase.position = joystickCenter
        joystickBase.fillColor = UIColor.white.withAlphaComponent(0.08)
        joystickBase.strokeColor = UIColor.white.withAlphaComponent(0.3)
        joystickBase.lineWidth = 2
        joystickBase.zPosition = ZPos.hud + 2
        joystickBase.isAntialiased = false
        joystickBase.alpha = 0  // shown during playerOffense
        hudNode.addChild(joystickBase)

        joystickThumb = SKShapeNode(circleOfRadius: JoystickConfig.thumbRadius)
        joystickThumb.position = joystickCenter
        joystickThumb.fillColor = UIColor.white.withAlphaComponent(0.4)
        joystickThumb.strokeColor = UIColor.white.withAlphaComponent(0.7)
        joystickThumb.lineWidth = 1.5
        joystickThumb.zPosition = ZPos.hud + 3
        joystickThumb.isAntialiased = false
        joystickThumb.alpha = 0
        hudNode.addChild(joystickThumb)

        // "MOVE" label under joystick
        let moveLabel = RetroFont.label("MOVE", size: RetroFont.tinySize, color: RetroPalette.textGray)
        moveLabel.position = CGPoint(x: joystickCenter.x, y: joystickCenter.y - joyR - 10)
        moveLabel.name = "joystickMoveLabel"
        joystickBase.addChild(moveLabel)

        // --- Shoot Indicator (on rink, near puck carrier) ---
        shootIndicator = SKNode()
        shootIndicator.zPosition = ZPos.effects + 1
        shootIndicator.alpha = 0
        rink.addChild(shootIndicator)

        let shootLabel = RetroFont.label("SWIPE TO SHOOT!", size: RetroFont.smallSize, color: RetroPalette.gold)
        shootLabel.name = "shootLabel"
        shootIndicator.addChild(shootLabel)

        let shootPulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.4),
            SKAction.fadeAlpha(to: 1.0, duration: 0.4),
        ]))
        shootLabel.run(shootPulse)
    }

    // MARK: - AI Setup
    private func setupAI() {
        let diff = GameManager.shared.league?.difficulty ?? .pro
        ai = HockeyAI(difficulty: diff, rink: rink)
    }

    // =========================================================================
    // MARK: - STATE MACHINE
    // =========================================================================

    private func startPregame() {
        gameState = .pregame
        showMessage("PERIOD \(period)") { [weak self] in
            self?.startFaceoff()
        }
    }

    private func startFaceoff() {
        gameState = .faceoff
        possessionCount += 1

        // Fill possession dot
        if possessionCount <= possessionDots.count {
            possessionDots[possessionCount - 1].fillColor = RetroPalette.accent
        }

        positionForFaceoff()

        showMessage("FACE OFF", duration: 0.8) { [weak self] in
            self?.startPlayerOffense()
        }
    }

    private func startPlayerOffense() {
        gameState = .playerOffense
        shotClock = GameConfig.shotClockDuration
        puckProtectionTimer = 1.5  // 1.5s protection after faceoff
        isLoosePuck = false
        loosePuckTimer = 0
        possessionsPlayed += 1

        // Give puck to player's center
        if let center = playerSkaters.first(where: { $0.posType == .center }) {
            puck.attachTo(center)
            center.isSelected = true
            selectedSkater = center
        }

        // Show pass targets on teammates
        for skater in playerSkaters where !skater.posType.isGoalie && !skater.hasPuck {
            skater.showPassTarget()
        }

        // Show controls
        controlHintBar.run(SKAction.fadeIn(withDuration: 0.3))
        joystickBase.run(SKAction.fadeAlpha(to: 0.6, duration: 0.3))
        joystickThumb.run(SKAction.fadeAlpha(to: 0.6, duration: 0.3))
        joystickDisplacement = .zero
        joystickThumb.position = joystickCenter

        // Show tutorial overlay on first 2 possessions
        if possessionsPlayed <= 2 && !tutorialShown {
            showTutorialOverlay()
        }
    }

    private func startSimulation() {
        gameState = .simulating

        // Hide pass targets and controls
        for skater in playerSkaters { skater.hidePassTarget() }
        selectedSkater?.isSelected = false
        selectedSkater = nil
        puck.detach()
        puck.resetToCenter()
        resetAllTouches()
        controlHintBar.run(SKAction.fadeOut(withDuration: 0.2))
        joystickBase.run(SKAction.fadeOut(withDuration: 0.2))
        joystickThumb.run(SKAction.fadeOut(withDuration: 0.2))
        shootIndicator.alpha = 0

        // Stop all skater movement
        for skater in allSkaters { skater.stopMoving() }

        // Simulate opponent's offensive possession
        let opponentTeam = isPlayerHome ? awayTeam! : homeTeam!
        let playerGoalie = playerSkaters.first { $0.posType.isGoalie }

        let scoringChance = calculateOpponentScoringChance(team: opponentTeam, goalie: playerGoalie)
        let scored = Double.random(in: 0...1) < scoringChance

        if scored {
            // Opponent scores
            if isPlayerHome {
                awayScore += 1
            } else {
                homeScore += 1
            }

            let scorer = opponentTeam.forwards.randomElement() ?? opponentTeam.roster.first!
            let assist = opponentTeam.roster.filter { $0.id != scorer.id }.randomElement()

            goalEvents.append(GoalEvent(
                period: period,
                scorerID: scorer.id,
                assist1ID: assist?.id,
                assist2ID: nil,
                teamIndex: isPlayerHome ? 1 : 0,
                isPowerPlay: false
            ))

            updateScoreDisplay()
            showMessage("THEY SCORE!\n\(scorer.shortName)", duration: 2.0) { [weak self] in
                self?.afterPossession()
            }
        } else {
            let messages = [
                "Shot saved!",
                "Wide of the net!",
                "Blocked shot!",
                "Great save!",
                "Cleared by defense!",
            ]
            showMessage(messages.randomElement()!, duration: 1.2) { [weak self] in
                self?.afterPossession()
            }
        }
    }

    private func afterPossession() {
        if possessionCount >= maxPossessions {
            endPeriod()
        } else {
            startFaceoff()
        }
    }

    private func endPeriod() {
        gameState = .periodBreak

        if period < GameConfig.periodsPerGame {
            showMessage("END OF PERIOD \(period)", duration: 2.0) { [weak self] in
                guard let self = self else { return }
                self.period += 1
                self.possessionCount = 0
                // Reset possession dots
                for dot in self.possessionDots {
                    dot.fillColor = UIColor(hex: "333333")
                }
                self.periodLabel.text = "\(self.periodString()) PERIOD"
                self.startPregame()
            }
        } else if homeScore == awayScore {
            // Overtime
            showMessage("OVERTIME!", duration: 2.0) { [weak self] in
                guard let self = self else { return }
                self.period = 4
                self.possessionCount = 0
                self.periodLabel.text = "OVERTIME"
                self.gameState = .overtime
                // Reset dots for OT
                for dot in self.possessionDots {
                    dot.fillColor = UIColor(hex: "333333")
                }
                self.startFaceoff()
            }
        } else {
            endGame()
        }
    }

    private func endGame() {
        gameState = .gameOver
        showMessage("FINAL\n\(homeTeam.abbreviation) \(homeScore) - \(awayScore) \(awayTeam.abbreviation)", duration: 3.0) { [weak self] in
            self?.transitionToPostGame()
        }
    }

    private func handleGoalScored(byPlayerTeam: Bool) {
        gameState = .goalScored

        if byPlayerTeam {
            if isPlayerHome {
                homeScore += 1
            } else {
                awayScore += 1
            }
        }

        // Record goal event
        if let scorer = selectedSkater ?? playerSkaters.first(where: { $0.hasPuck }) {
            let assist = playerSkaters.first(where: {
                $0.playerID != scorer.playerID && !$0.posType.isGoalie
            })
            goalEvents.append(GoalEvent(
                period: period,
                scorerID: scorer.playerID,
                assist1ID: assist?.playerID,
                assist2ID: nil,
                teamIndex: isPlayerHome ? 0 : 1,
                isPowerPlay: false
            ))
        }

        // Hide pass targets and controls
        for skater in playerSkaters { skater.hidePassTarget() }
        selectedSkater?.isSelected = false
        selectedSkater = nil
        resetAllTouches()
        controlHintBar.run(SKAction.fadeOut(withDuration: 0.2))
        joystickBase.run(SKAction.fadeOut(withDuration: 0.2))
        joystickThumb.run(SKAction.fadeOut(withDuration: 0.2))
        shootIndicator.alpha = 0

        updateScoreDisplay()

        // Goal celebration effects
        puck.goalEffect()
        goalLightFlash()
        startCameraShake(intensity: 4, duration: 0.5)
        startCelebrationZoom()

        for skater in playerSkaters where !skater.posType.isGoalie {
            skater.playCelebration()
        }

        let team = isPlayerHome ? homeTeam! : awayTeam!
        showMessage("GOAL!\n\(team.name.uppercased())!", duration: 2.5) { [weak self] in
            guard let self = self else { return }
            self.puck.resetToCenter()
            self.afterPossession()
        }
    }

    // =========================================================================
    // MARK: - GAME LOOP (update)
    // =========================================================================

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Camera update (always)
        updateCamera(dt: dt)

        // Puck frame update (trail, timeSinceShot)
        puck.update(dt: dt)

        guard gameState == .playerOffense || gameState == .faceoff else { return }

        // Update puck carrier position
        puck.updatePosition()

        if gameState == .playerOffense {

            // ------- AI updates -------

            let puckVel = puck.physicsBody?.velocity ?? .zero

            // Opponent defense AI
            ai.updateDefenders(
                skaters: opponentSkaters,
                puckPosition: puck.position,
                puckCarrier: puck.carriedBy,
                puckVelocity: puckVel,
                currentTime: currentTime
            )

            // Teammate AI (offensive positioning)
            ai.updateOffensiveAI(
                skaters: playerSkaters,
                puckCarrier: puck.carriedBy,
                attackingRight: attackingRight,
                opponents: opponentSkaters,
                currentTime: currentTime
            )

            // ------- Puck protection timer -------
            if puckProtectionTimer > 0 {
                puckProtectionTimer -= dt
            }

            // ------- Pass arrival detection -------
            if puck.isPass {
                let allSkaters = playerSkaters + opponentSkaters
                if let receiver = puck.checkPassArrival(skaters: allSkaters) {
                    // Pass arrived — attach puck to receiver
                    puck.attachTo(receiver)
                    receiver.isSelected = true
                    selectedSkater = receiver
                    puckProtectionTimer = 0.8

                    // Refresh pass targets
                    for skater in playerSkaters { skater.hidePassTarget() }
                    for skater in playerSkaters where !skater.posType.isGoalie && !skater.hasPuck {
                        skater.showPassTarget()
                    }
                } else if !puck.isPass {
                    // Pass timed out — treat as loose puck
                    isLoosePuck = true
                    loosePuckTimer = loosePuckRecoveryWindow
                    for s in playerSkaters { s.hidePassTarget() }
                    showMessage("BAD PASS!", duration: 0.6)
                }
            }

            // ------- Loose puck recovery -------
            if isLoosePuck {
                loosePuckTimer -= dt

                // Check if any player skater reaches the loose puck
                for skater in playerSkaters where !skater.posType.isGoalie {
                    let dist = skater.position.distance(to: puck.position)
                    if dist < GameConfig.skaterRadius * 2.5 {
                        // Recovered the puck!
                        isLoosePuck = false
                        loosePuckTimer = 0
                        puck.attachTo(skater)
                        skater.isSelected = true
                        selectedSkater = skater
                        puckProtectionTimer = 1.0  // brief protection after recovery

                        // Refresh pass targets
                        for s in playerSkaters { s.hidePassTarget() }
                        for s in playerSkaters where !s.posType.isGoalie && !s.hasPuck {
                            s.showPassTarget()
                        }

                        showMessage("RECOVERED!", duration: 0.5)
                        break
                    }
                }

                if isLoosePuck && loosePuckTimer <= 0 {
                    // Failed to recover — full turnover
                    isLoosePuck = false
                    completeTurnover()
                    return
                }

                // During loose puck, joystick moves nearest skater toward puck
                if joystickDisplacement != .zero {
                    let nearest = playerSkaters.filter { !$0.posType.isGoalie }
                        .min { $0.position.distance(to: puck.position) < $1.position.distance(to: puck.position) }
                    if let skater = nearest {
                        let targetPos = CGPoint(
                            x: skater.position.x + joystickDisplacement.x * 80,
                            y: skater.position.y + joystickDisplacement.y * 80
                        )
                        skater.moveToward(targetPos)
                    }
                }

                return  // Skip normal offense logic while puck is loose
            }

            // ------- Shot clock -------
            shotClock -= dt
            if shotClock <= 0 {
                completeTurnover()
                return
            }

            // ------- Shot resolution (physics-based, NO DispatchQueue) -------
            if puck.hasBeenShot {
                resolveShotInUpdate()
            }

            // ------- Body check / puck steal (THROTTLED) -------
            if puckProtectionTimer <= 0,
               let carrier = puck.carriedBy,
               carrier.teamIndex == (isPlayerHome ? 0 : 1),
               currentTime - lastBodyCheckTime > bodyCheckInterval {
                lastBodyCheckTime = currentTime

                for defender in opponentSkaters where !defender.posType.isGoalie {
                    if ai.checkBodyCheck(defender: defender, puckCarrier: carrier) {
                        // Puck goes loose — player has a chance to recover
                        startLoosePuck(from: carrier)
                        return
                    }
                }
            }

            // ------- Shoot indicator update -------
            updateShootIndicator()

            // ------- Joystick movement -------
            if joystickDisplacement != .zero,
               let carrier = puck.carriedBy,
               carrier.teamIndex == (isPlayerHome ? 0 : 1) {
                let moveTarget = CGPoint(
                    x: carrier.position.x + joystickDisplacement.x * 80,
                    y: carrier.position.y + joystickDisplacement.y * 80
                )
                carrier.moveToward(moveTarget)
            } else if joystickDisplacement == .zero,
                      let carrier = puck.carriedBy,
                      carrier.teamIndex == (isPlayerHome ? 0 : 1),
                      joystickTouch == nil {
                // Joystick released — stop carrier
                carrier.stopMoving()
            }

            // ------- Puck out of bounds -------
            let hw = rink.rinkWidth / 2 + 20
            let hh = rink.rinkHeight / 2 + 20
            if abs(puck.position.x) > hw || abs(puck.position.y) > hh {
                puck.resetToCenter()
                startSimulation()
            }
        }
    }

    // MARK: - Shot Resolution (physics-based: goals/saves handled by contact delegate)
    private func resolveShotInUpdate() {
        // Shot timed out (went wide, slowed down, or missed everything)
        if puck.timeSinceShot > 2.5 {
            puck.hasBeenShot = false
            let missMsgs = ["Wide!", "Shot missed!", "Off the post!", "High and wide!"]
            showMessage(missMsgs.randomElement()!, duration: 0.8) { [weak self] in
                self?.puck.resetToCenter()
                self?.startSimulation()
            }
        }
    }

    // =========================================================================
    // MARK: - CAMERA SYSTEM
    // =========================================================================

    private func updateCamera(dt: TimeInterval) {
        guard dt > 0 else { return }

        // Target: follow puck carrier (or puck if loose), with lead in movement direction
        var targetPos: CGPoint

        if let carrier = puck.carriedBy {
            targetPos = carrier.position
            // Lead in movement direction
            if let vel = carrier.physicsBody?.velocity {
                let speed = hypot(vel.dx, vel.dy)
                if speed > 20 {
                    let normX = vel.dx / speed
                    let normY = vel.dy / speed
                    targetPos.x += normX * CameraConfig.leadAmount
                    targetPos.y += normY * CameraConfig.leadAmount
                }
            }
        } else {
            targetPos = puck.position
        }

        // Convert rink-local position to scene coordinates
        targetPos = rink.convert(targetPos, to: self)

        // Smooth lerp follow
        let lerpFactor = CameraConfig.followSpeed
        var camPos = cameraNode.position
        camPos.x += (targetPos.x - camPos.x) * lerpFactor
        camPos.y += (targetPos.y - camPos.y) * lerpFactor

        // Clamp camera to rink bounds so edges don't go past screen edges
        // Camera at scale 1.0 — visible area = scene size
        let visW = size.width / 2
        let visH = size.height / 2
        let rinkHW = rink.rinkWidth / 2
        let rinkHH = rink.rinkHeight / 2
        let pad = CameraConfig.boundsPadding

        let minX = -rinkHW + visW - pad
        let maxX = rinkHW - visW + pad
        let minY = -rinkHH + visH - pad
        let maxY = rinkHH - visH + pad

        if minX < maxX {
            camPos.x = max(minX, min(maxX, camPos.x))
        } else {
            camPos.x = 0  // rink fits in view, center it
        }
        if minY < maxY {
            camPos.y = max(minY, min(maxY, camPos.y))
        } else {
            camPos.y = 0
        }

        // Apply camera shake (normalized decay: strongest at start, fades to zero)
        if cameraShakeTimer > 0 {
            cameraShakeTimer -= dt
            let fraction = cameraShakeDuration > 0 ? max(0, CGFloat(cameraShakeTimer / cameraShakeDuration)) : 0
            let magnitude = cameraShakeIntensity * fraction
            if magnitude > 0 {
                let shakeX = CGFloat.random(in: -magnitude...magnitude)
                let shakeY = CGFloat.random(in: -magnitude...magnitude)
                camPos.x += shakeX
                camPos.y += shakeY
            }
        }

        cameraNode.position = camPos

        // Celebration zoom
        if celebrationZoom {
            // Already handled by SKAction on cameraNode
        }
    }

    private func startCameraShake(intensity: CGFloat, duration: TimeInterval) {
        cameraShakeIntensity = intensity
        cameraShakeDuration = duration
        cameraShakeTimer = duration
    }

    private func startCelebrationZoom() {
        celebrationZoom = true
        let zoomOut = SKAction.scale(to: 1.3, duration: 0.5)
        let zoomBack = SKAction.scale(to: 1.0, duration: 0.8)
        zoomOut.timingMode = .easeOut
        zoomBack.timingMode = .easeInEaseOut
        cameraNode.run(SKAction.sequence([zoomOut, zoomBack])) { [weak self] in
            self?.celebrationZoom = false
        }
    }

    // =========================================================================
    // MARK: - TOUCH CONTROLS (Two-Hand: Joystick + Action)
    // =========================================================================

    /// Determine if a touch is in the joystick zone (left half of screen)
    private func isJoystickTouch(_ touch: UITouch) -> Bool {
        let loc = touch.location(in: self)
        let hudLoc = hudNode.convert(loc, from: self)
        return hudLoc.x < 0  // left half of screen
    }

    /// Reset all touch tracking
    private func resetAllTouches() {
        joystickTouch = nil
        joystickDisplacement = .zero
        joystickBase.position = joystickCenter
        joystickThumb.position = joystickCenter
        actionTouch = nil
        actionTouchState = .none
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // Dismiss tutorial overlay on any tap
            if tutorialOverlay != nil {
                dismissTutorial()
                return
            }

            guard gameState == .playerOffense else { return }

            // --- Joystick touch (any left-side touch) ---
            if joystickTouch == nil && isJoystickTouch(touch) {
                joystickTouch = touch
                let loc = touch.location(in: self)
                let hudLoc = hudNode.convert(loc, from: self)
                joystickOrigin = hudLoc
                // Move joystick visual to where the user touched
                joystickBase.position = hudLoc
                joystickThumb.position = hudLoc
                continue
            }

            // --- Action touch (right hand) ---
            if actionTouch == nil {
                actionTouch = touch
                let sceneLocation = touch.location(in: self)
                let rinkLocation = convert(sceneLocation, to: rink)

                // Check if tapping on a teammate → immediate PASS
                for skater in playerSkaters where !skater.posType.isGoalie && !skater.hasPuck {
                    let dist = rinkLocation.distance(to: skater.position)
                    if dist < TouchConfig.tapRadius {
                        performPass(to: skater)
                        actionTouch = nil
                        actionTouchState = .none
                        return
                    }
                }

                // Otherwise, start tracking for swipe (shoot/deke)
                actionTouchState = .holding(start: sceneLocation, time: touch.timestamp)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // --- Joystick moved ---
            if touch === joystickTouch {
                let loc = touch.location(in: self)
                let hudLoc = hudNode.convert(loc, from: self)
                let dx = hudLoc.x - joystickOrigin.x
                let dy = hudLoc.y - joystickOrigin.y
                let dist = hypot(dx, dy)

                let maxR = JoystickConfig.baseRadius

                if dist < JoystickConfig.deadzone {
                    joystickDisplacement = .zero
                    joystickThumb.position = joystickOrigin
                } else {
                    // Clamp thumb to base radius
                    let clampedDist = min(dist, maxR)
                    let nx = dx / dist
                    let ny = dy / dist
                    joystickThumb.position = CGPoint(
                        x: joystickOrigin.x + nx * clampedDist,
                        y: joystickOrigin.y + ny * clampedDist
                    )
                    // Normalized displacement (0..1 magnitude)
                    let magnitude = clampedDist / maxR
                    joystickDisplacement = CGPoint(x: nx * magnitude, y: ny * magnitude)
                }
                continue
            }

            // Action touches don't need move tracking (swipe is start→end)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // --- Joystick released ---
            if touch === joystickTouch {
                joystickTouch = nil
                joystickDisplacement = .zero
                // Return joystick visual to default position
                joystickBase.position = joystickCenter
                joystickThumb.position = joystickCenter
                continue
            }

            // --- Action touch released ---
            if touch === actionTouch {
                guard gameState == .playerOffense else {
                    actionTouch = nil
                    actionTouchState = .none
                    continue
                }

                let sceneLocation = touch.location(in: self)

                switch actionTouchState {
                case .holding(let start, let startTime):
                    let dist = sceneLocation.distance(to: start)
                    let duration = touch.timestamp - startTime

                    if dist > TouchConfig.swipeMinDistance && duration < TouchConfig.swipeMaxDuration {
                        // Swipe detected — determine SHOT or DEKE
                        let swipeVector = sceneLocation - start
                        let swipeAngle = atan2(swipeVector.y, swipeVector.x)

                        let goalDir: CGFloat = attackingRight ? 0 : .pi
                        var angleDiff = abs(swipeAngle - goalDir)
                        if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }

                        if angleDiff < TouchConfig.dekeAngleThreshold {
                            // Swipe toward goal → SHOOT
                            let power = min(dist * 5, GameConfig.shotSpeedMax)
                            let goalMouth = attackingRight ? rink.rightGoalMouth : rink.leftGoalMouth
                            let rinkTarget = convert(sceneLocation, to: rink)
                            let aimX = goalMouth.x * 0.7 + rinkTarget.x * 0.3
                            let aimY = rinkTarget.y * 0.6 + goalMouth.y * 0.4
                            performShot(toward: CGPoint(x: aimX, y: aimY), power: power)
                        } else {
                            // Swipe perpendicular → DEKE
                            if let carrier = puck.carriedBy {
                                carrier.deke(direction: swipeAngle)
                            }
                        }
                    }
                    // Small tap with no distance = ignored (pass already handled in touchesBegan)

                case .none:
                    break
                }

                actionTouch = nil
                actionTouchState = .none
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch === joystickTouch {
                joystickTouch = nil
                joystickDisplacement = .zero
                joystickBase.position = joystickCenter
                joystickThumb.position = joystickCenter
            }
            if touch === actionTouch {
                actionTouch = nil
                actionTouchState = .none
            }
        }
    }

    // =========================================================================
    // MARK: - ACTIONS
    // =========================================================================

    private func performPass(to target: SkaterNode) {
        guard let carrier = puck.carriedBy,
              carrier.teamIndex == (isPlayerHome ? 0 : 1) else { return }

        carrier.isSelected = false

        // Pass accuracy based on stats
        let passAccuracy = Double(carrier.playerStats.passing) / 99.0
        let passChance = 0.6 + passAccuracy * 0.35

        // Check if pass is intercepted by any defender near the passing lane
        let midpoint = CGPoint(
            x: (carrier.position.x + target.position.x) / 2,
            y: (carrier.position.y + target.position.y) / 2
        )
        for defender in opponentSkaters where !defender.posType.isGoalie {
            let defDist = defender.position.distance(to: midpoint)
            if defDist < 25 && Double.random(in: 0...1) > passChance {
                // Intercepted — puck goes loose with recovery chance
                puck.pass(toward: midpoint, targetID: target.playerID)
                run(SKAction.wait(forDuration: 0.3)) { [weak self] in
                    guard let self = self, self.gameState == .playerOffense else { return }
                    self.puck.clearPassState()
                    self.isLoosePuck = true
                    self.loosePuckTimer = self.loosePuckRecoveryWindow
                    for s in self.playerSkaters { s.hidePassTarget() }
                    self.showMessage("INTERCEPTED!", duration: 0.6)
                }
                return
            }
        }

        // Successful pass: puck travels physically, arrival detected in update()
        puck.pass(toward: target.position, targetID: target.playerID)
    }

    private func performShot(toward target: CGPoint, power: CGFloat) {
        guard let carrier = puck.carriedBy else { return }

        // Hide pass targets and shoot indicator
        for skater in playerSkaters { skater.hidePassTarget() }
        shootIndicator.alpha = 0

        // Play shoot animation
        carrier.playShootAnimation()

        // Brief "SHOT!" flash message
        showMessage("SHOT!", duration: 0.4)

        puck.shoot(toward: target, power: power)

        // Deselect carrier (puck is now loose and shot)
        selectedSkater?.isSelected = false
        // Keep selectedSkater reference for goal event attribution
    }

    /// Puck gets knocked loose — player has a brief window to recover
    private func startLoosePuck(from carrier: SkaterNode) {
        guard gameState == .playerOffense, !isLoosePuck else { return }

        isLoosePuck = true
        loosePuckTimer = loosePuckRecoveryWindow

        // Detach puck and give it a small random impulse
        puck.detach()
        carrier.isSelected = false
        selectedSkater = nil

        let randomAngle = CGFloat.random(in: 0...(2 * .pi))
        let knockSpeed: CGFloat = 80
        puck.physicsBody?.velocity = CGVector(
            dx: cos(randomAngle) * knockSpeed,
            dy: sin(randomAngle) * knockSpeed
        )

        // Hide pass targets during loose puck
        for skater in playerSkaters { skater.hidePassTarget() }

        showMessage("LOOSE PUCK!", duration: 0.6)
    }

    /// Full turnover — play stops and goes to opponent possession
    private func completeTurnover() {
        guard gameState == .playerOffense else { return }

        isLoosePuck = false
        loosePuckTimer = 0

        for skater in playerSkaters {
            skater.hidePassTarget()
            skater.isSelected = false
        }
        selectedSkater = nil
        puck.detach()
        resetAllTouches()
        controlHintBar.run(SKAction.fadeOut(withDuration: 0.2))
        joystickBase.run(SKAction.fadeOut(withDuration: 0.2))
        joystickThumb.run(SKAction.fadeOut(withDuration: 0.2))
        shootIndicator.alpha = 0

        showMessage("TURNOVER", duration: 1.0) { [weak self] in
            self?.puck.resetToCenter()
            self?.startSimulation()
        }
    }

    // =========================================================================
    // MARK: - PHYSICS CONTACT
    // =========================================================================

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        guard gameState == .playerOffense else { return }

        // Puck hits boards while shot -> miss
        if puck.hasBeenShot {
            if (a == PhysicsCategory.puck && b == PhysicsCategory.boards) ||
               (a == PhysicsCategory.boards && b == PhysicsCategory.puck) {
                puck.hasBeenShot = false
                showMessage("Off the boards!", duration: 0.8) { [weak self] in
                    self?.puck.resetToCenter()
                    self?.startSimulation()
                }
                return
            }
        }

        // Puck hits a skater while shot -> check if it's the goalie
        if puck.hasBeenShot {
            if (a == PhysicsCategory.puck && b == PhysicsCategory.skater) ||
               (a == PhysicsCategory.skater && b == PhysicsCategory.puck) {
                let skaterNode = a == PhysicsCategory.skater ? contact.bodyA.node : contact.bodyB.node
                if let skater = skaterNode as? SkaterNode, skater.posType.isGoalie,
                   skater.teamIndex != (isPlayerHome ? 0 : 1) {
                    // Puck hit the opposing goalie!
                    let puckSpeed = hypot(puck.physicsBody?.velocity.dx ?? 0, puck.physicsBody?.velocity.dy ?? 0)
                    let goalieReflexes = Double(skater.playerStats.reflexes) / 99.0

                    // Small chance the puck trickles through (harder shot + worse goalie = higher chance)
                    let trickleChance = 0.08 + (puckSpeed / Double(GameConfig.shotSpeedMax)) * 0.07 - goalieReflexes * 0.05
                    if Double.random(in: 0...1) < trickleChance {
                        // Puck squeaks through! Let physics continue — goal contact will trigger
                        return
                    }

                    // Save! Stop the puck so it doesn't bounce endlessly
                    puck.hasBeenShot = false
                    puck.physicsBody?.velocity = .zero
                    puck.physicsBody?.isDynamic = false
                    let saveMsgs = ["SAVED!", "Great save!", "Glove save!", "Pad save!"]
                    showMessage(saveMsgs.randomElement()!, duration: 0.8) { [weak self] in
                        self?.puck.physicsBody?.isDynamic = true
                        self?.puck.resetToCenter()
                        self?.startSimulation()
                    }
                    return
                }
            }
        }

        // Puck hits goal trigger zone -> GOAL
        if (a == PhysicsCategory.puck && b == PhysicsCategory.goal) ||
           (a == PhysicsCategory.goal && b == PhysicsCategory.puck) {
            let goalNode = a == PhysicsCategory.goal ? contact.bodyA.node : contact.bodyB.node

            if (goalNode?.name == "rightGoal" && attackingRight) ||
               (goalNode?.name == "leftGoal" && !attackingRight) {
                puck.hasBeenShot = false
                handleGoalScored(byPlayerTeam: true)
            }
            return
        }

        // Loose puck hits a non-goalie skater -> that skater picks it up
        if puck.isLoose && !puck.hasBeenShot && !puck.isPass {
            if (a == PhysicsCategory.puck && b == PhysicsCategory.skater) ||
               (a == PhysicsCategory.skater && b == PhysicsCategory.puck) {
                let skaterNode = a == PhysicsCategory.skater ? contact.bodyA.node : contact.bodyB.node
                guard let skater = skaterNode as? SkaterNode, !skater.posType.isGoalie else { return }

                // Cancel any pending save/miss message actions
                messageLabel.removeAllActions()
                messageLabel.alpha = 0

                let playerTeamIndex = isPlayerHome ? 0 : 1

                if skater.teamIndex == playerTeamIndex {
                    // Player's team recovers the puck
                    puck.attachTo(skater)
                    isLoosePuck = false
                    loosePuckTimer = 0
                    skater.isSelected = true
                    selectedSkater = skater
                    puckProtectionTimer = 1.0

                    for s in playerSkaters { s.hidePassTarget() }
                    for s in playerSkaters where !s.posType.isGoalie && !s.hasPuck {
                        s.showPassTarget()
                    }
                    showMessage("RECOVERED!", duration: 0.5)
                } else {
                    // Opponent picks up the puck — turnover
                    puck.attachTo(skater)
                    isLoosePuck = false
                    loosePuckTimer = 0
                    showMessage("TURNOVER!", duration: 0.8) { [weak self] in
                        self?.puck.resetToCenter()
                        self?.startSimulation()
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - POSITIONING
    // =========================================================================

    private func positionForFaceoff() {
        let hw = rink.rinkWidth / 2
        let hh = rink.rinkHeight / 2

        // Home team positions (attacking right = left side start)
        let homePositions: [(Position, CGPoint)] = [
            (.center,       CGPoint(x: -15, y: 0)),
            (.leftWing,     CGPoint(x: -50, y: hh * 0.4)),
            (.rightWing,    CGPoint(x: -50, y: -hh * 0.4)),
            (.leftDefense,  CGPoint(x: -hw * 0.4, y: hh * 0.3)),
            (.rightDefense, CGPoint(x: -hw * 0.4, y: -hh * 0.3)),
            (.goalie,       CGPoint(x: -hw / 2 + 30, y: 0)),
        ]

        for (pos, point) in homePositions {
            if let skater = homeSkaters.first(where: { $0.posType == pos }) {
                skater.position = point
                skater.stopMoving()
            }
        }

        // Away team positions (mirrored)
        let awayPositions: [(Position, CGPoint)] = [
            (.center,       CGPoint(x: 15, y: 0)),
            (.leftWing,     CGPoint(x: 50, y: -hh * 0.4)),
            (.rightWing,    CGPoint(x: 50, y: hh * 0.4)),
            (.leftDefense,  CGPoint(x: hw * 0.4, y: -hh * 0.3)),
            (.rightDefense, CGPoint(x: hw * 0.4, y: hh * 0.3)),
            (.goalie,       CGPoint(x: hw / 2 - 30, y: 0)),
        ]

        for (pos, point) in awayPositions {
            if let skater = awaySkaters.first(where: { $0.posType == pos }) {
                skater.position = point
                skater.stopMoving()
            }
        }

        puck.resetToCenter()
    }

    // =========================================================================
    // MARK: - HELPERS
    // =========================================================================

    private func calculateOpponentScoringChance(team: Team, goalie: SkaterNode?) -> Double {
        let teamStrength = Double(team.teamOverall) / 99.0
        let goalieSkill = goalie.map {
            Double($0.playerStats.reflexes + $0.playerStats.positioning) / 198.0
        } ?? 0.3

        var chance = teamStrength * 0.35 - goalieSkill * 0.2

        switch GameManager.shared.league?.difficulty ?? .pro {
        case .rookie:  chance *= 0.6
        case .pro:     chance *= 0.8
        case .allStar: chance *= 1.0
        case .legend:  chance *= 1.3
        }

        return max(0.05, min(0.4, chance))
    }

    // MARK: - Tutorial Overlay
    private func showTutorialOverlay() {
        guard tutorialOverlay == nil else { return }

        let visW = size.width
        let visH = size.height

        let overlay = SKNode()
        overlay.zPosition = ZPos.overlay + 5

        // Semi-transparent dark backdrop (sized to panel, not full screen)
        let panelW: CGFloat = min(visW * 0.85, 420)
        let panelH: CGFloat = 160
        let backdrop = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.85),
                                     size: CGSize(width: panelW, height: panelH))
        backdrop.position = .zero
        overlay.addChild(backdrop)

        // Border
        let border = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH))
        border.strokeColor = RetroPalette.gold.withAlphaComponent(0.5)
        border.lineWidth = 1
        border.fillColor = .clear
        overlay.addChild(border)

        // Title
        let title = RetroFont.label("CONTROLS", size: RetroFont.headerSize, color: RetroPalette.gold)
        title.position = CGPoint(x: 0, y: 55)
        overlay.addChild(title)

        // Left hand section
        let colL: CGFloat = -90
        let leftTitle = RetroFont.label("LEFT THUMB", size: RetroFont.smallSize, color: RetroPalette.textYellow)
        leftTitle.position = CGPoint(x: colL, y: 50)
        overlay.addChild(leftTitle)

        let joyInstr = RetroFont.label("Drag = Skate", size: RetroFont.bodySize, color: .white)
        joyInstr.position = CGPoint(x: colL, y: 30)
        overlay.addChild(joyInstr)

        // Draw a mini joystick icon
        let miniBase = SKShapeNode(circleOfRadius: 18)
        miniBase.fillColor = UIColor.white.withAlphaComponent(0.1)
        miniBase.strokeColor = UIColor.white.withAlphaComponent(0.4)
        miniBase.lineWidth = 1.5
        miniBase.position = CGPoint(x: colL, y: 2)
        overlay.addChild(miniBase)

        let miniThumb = SKShapeNode(circleOfRadius: 7)
        miniThumb.fillColor = UIColor.white.withAlphaComponent(0.5)
        miniThumb.strokeColor = UIColor.white.withAlphaComponent(0.8)
        miniThumb.position = CGPoint(x: colL + 8, y: 6)
        overlay.addChild(miniThumb)

        // Right hand section
        let colR: CGFloat = 90
        let rightTitle = RetroFont.label("RIGHT HAND", size: RetroFont.smallSize, color: RetroPalette.textYellow)
        rightTitle.position = CGPoint(x: colR, y: 50)
        overlay.addChild(rightTitle)

        let tapInstr = RetroFont.label("Tap Player = Pass", size: RetroFont.bodySize, color: RetroPalette.textGreen)
        tapInstr.position = CGPoint(x: colR, y: 30)
        overlay.addChild(tapInstr)

        let shootInstr = RetroFont.label("Swipe = Shoot!", size: RetroFont.bodySize, color: RetroPalette.gold)
        shootInstr.position = CGPoint(x: colR, y: 10)
        overlay.addChild(shootInstr)

        let dekeInstr = RetroFont.label("Swipe Up/Down = Deke", size: RetroFont.bodySize, color: .white)
        dekeInstr.position = CGPoint(x: colR, y: -10)
        overlay.addChild(dekeInstr)

        // "Tap to start" label
        let tapStart = RetroFont.label("TAP ANYWHERE TO PLAY", size: RetroFont.smallSize, color: RetroPalette.textGray)
        tapStart.position = CGPoint(x: 0, y: -40)
        overlay.addChild(tapStart)

        let blink = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6),
        ]))
        tapStart.run(blink)

        hudNode.addChild(overlay)
        tutorialOverlay = overlay

        // Pause gameplay while tutorial is showing
        gameState = .faceoff
    }

    private func dismissTutorial() {
        guard let overlay = tutorialOverlay else { return }
        tutorialShown = true
        overlay.run(SKAction.fadeOut(withDuration: 0.2)) { [weak self] in
            overlay.removeFromParent()
            self?.tutorialOverlay = nil
            self?.gameState = .playerOffense
        }
    }

    // MARK: - Shoot Indicator Update
    private func updateShootIndicator() {
        guard let carrier = puck.carriedBy,
              carrier.teamIndex == (isPlayerHome ? 0 : 1),
              !puck.hasBeenShot else {
            shootIndicator.alpha = 0
            return
        }

        let goalMouth = attackingRight ? rink.rightGoalMouth : rink.leftGoalMouth
        let dist = carrier.position.distance(to: goalMouth)
        let shootRange = rink.rinkWidth * 0.35

        if dist < shootRange {
            // Show shoot indicator near the carrier, pointing toward goal
            let dirX: CGFloat = attackingRight ? 1 : -1
            shootIndicator.position = CGPoint(
                x: carrier.position.x + dirX * 35,
                y: carrier.position.y + 25
            )
            let targetAlpha: CGFloat = min(1.0, (shootRange - dist) / (shootRange * 0.5))
            shootIndicator.alpha = targetAlpha
        } else {
            shootIndicator.alpha = 0
        }
    }

    private func showMessage(_ text: String, duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        messageLabel.text = text
        messageLabel.numberOfLines = 0

        let fadeIn  = SKAction.fadeIn(withDuration: 0.2)
        let wait    = SKAction.wait(forDuration: duration)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)

        messageLabel.run(SKAction.sequence([fadeIn, wait, fadeOut])) {
            completion?()
        }
    }

    private func updateScoreDisplay() {
        scoreLabel.text = "\(homeScore) - \(awayScore)"
    }

    private func goalLightFlash() {
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 0, duration: 0.1),
        ])
        goalFlash.run(SKAction.repeat(flash, count: 3))
    }

    private func periodString() -> String {
        switch period {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        default: return "OT"
        }
    }

    private func transitionToPostGame() {
        let result = GameResult(
            homeScore: homeScore,
            awayScore: awayScore,
            overtime: period > 3,
            scorers: goalEvents,
            starPlayerID: goalEvents.first?.scorerID
        )

        // Award coaching credits
        GameManager.shared.awardCoachingCredits(result: result, isPlayerHome: isPlayerHome)

        GameManager.transition(from: view, toSceneType: PostGameScene.self) { [scheduleIndex, homeTeam, awayTeam] scene in
            scene.gameResult = result
            scene.homeTeam = homeTeam
            scene.awayTeam = awayTeam
            scene.scheduleIndex = scheduleIndex
        }
    }
}
