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
    private var attackingRight: Bool { true }  // player always attacks right

    // MARK: - State
    private var gameState: GameplayState = .pregame
    private var possession: PossessionState = .loosePuck
    private var period: Int = 1
    private var homeScore: Int = 0
    private var awayScore: Int = 0
    private var goalEvents: [GoalEvent] = []

    // MARK: - Touch State (Two-Hand: Joystick + Action)
    private var joystickTouch: UITouch?
    private var joystickDisplacement: CGPoint = .zero

    enum ActionTouchState {
        case none
        case holding(start: CGPoint, time: TimeInterval)
    }
    private var actionTouchState: ActionTouchState = .none
    private var actionTouch: UITouch?
    private var selectedSkater: SkaterNode?       // offense: puck carrier
    private var selectedDefender: SkaterNode?      // defense: player-controlled defender

    // MARK: - HUD
    private var scoreLabel: SKLabelNode!
    private var periodLabel: SKLabelNode!
    private var periodClockLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!
    private var goalFlash: SKSpriteNode!
    private var hudNode: SKNode!
    private var controlHintBar: SKNode!
    private var shootIndicator: SKNode!
    private var tutorialOverlay: SKNode?
    private var tutorialShown: Bool = false

    // MARK: - Joystick HUD Nodes
    private var joystickBase: SKShapeNode!
    private var joystickThumb: SKShapeNode!
    private var joystickCenter: CGPoint = .zero
    private var joystickOrigin: CGPoint = .zero

    // MARK: - Camera
    private var cameraShakeTimer: TimeInterval = 0
    private var cameraShakeDuration: TimeInterval = 0
    private var cameraShakeIntensity: CGFloat = 0
    private var celebrationZoom: Bool = false

    // MARK: - Timing
    private var lastUpdateTime: TimeInterval = 0
    private var periodClock: TimeInterval = GameConfig.periodDuration

    // MARK: - Body Check & Puck Protection
    private var lastBodyCheckTime: TimeInterval = 0
    private let bodyCheckInterval: TimeInterval = 0.5
    private var puckProtectionTimer: TimeInterval = 0
    private var defenseCheckCooldown: TimeInterval = 0

    // MARK: - Loose Puck
    private var loosePuckTimer: TimeInterval = 0
    private var isLoosePuck: Bool = false
    private let loosePuckRecoveryWindow: TimeInterval = 3.0

    // MARK: - Opponent Offense
    private var opponentShotClock: TimeInterval = 0

    // MARK: - Setup
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: "111122")
        super.didMove(to: view)

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

        // Position skaters in formation before pregame message
        positionForFaceoff()
        startPregame()
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        cameraNode = SKCameraNode()
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
        // Player team is always teamIndex 0 (left side, attacks right)
        // Opponent team is always teamIndex 1 (right side, attacks left)
        let playerTeam = isPlayerHome ? homeTeam! : awayTeam!
        let opponentTeam = isPlayerHome ? awayTeam! : homeTeam!
        let playerColors = playerTeam.colors
        let opponentColors = opponentTeam.colors

        let playerFwdLine = playerTeam.forwardLine(0)
        let playerDefPair = playerTeam.defensePair(0)
        let playerGoalie = playerTeam.startingGoaliePlayer

        for player in playerFwdLine {
            let node = SkaterNode(player: player, teamColors: playerColors, teamIndex: 0)
            rink.addChild(node)
            if isPlayerHome { homeSkaters.append(node) } else { awaySkaters.append(node) }
        }
        for player in playerDefPair {
            let node = SkaterNode(player: player, teamColors: playerColors, teamIndex: 0)
            rink.addChild(node)
            if isPlayerHome { homeSkaters.append(node) } else { awaySkaters.append(node) }
        }
        if let goalie = playerGoalie {
            let node = SkaterNode(player: goalie, teamColors: playerColors, teamIndex: 0)
            rink.addChild(node)
            if isPlayerHome { homeSkaters.append(node) } else { awaySkaters.append(node) }
        }

        let oppFwdLine = opponentTeam.forwardLine(0)
        let oppDefPair = opponentTeam.defensePair(0)
        let oppGoalie = opponentTeam.startingGoaliePlayer

        for player in oppFwdLine {
            let node = SkaterNode(player: player, teamColors: opponentColors, teamIndex: 1)
            rink.addChild(node)
            if isPlayerHome { awaySkaters.append(node) } else { homeSkaters.append(node) }
        }
        for player in oppDefPair {
            let node = SkaterNode(player: player, teamColors: opponentColors, teamIndex: 1)
            rink.addChild(node)
            if isPlayerHome { awaySkaters.append(node) } else { homeSkaters.append(node) }
        }
        if let goalie = oppGoalie {
            let node = SkaterNode(player: goalie, teamColors: opponentColors, teamIndex: 1)
            rink.addChild(node)
            if isPlayerHome { awaySkaters.append(node) } else { homeSkaters.append(node) }
        }
    }

    // MARK: - HUD Setup
    private func setupHUD() {
        hudNode = SKNode()
        hudNode.zPosition = ZPos.hud
        cameraNode.addChild(hudNode)

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
        periodLabel.position = CGPoint(x: -30, y: topY - 34)
        hudNode.addChild(periodLabel)

        // Period clock
        periodClockLabel = RetroFont.label(
            formatClock(GameConfig.periodDuration),
            size: RetroFont.tinySize,
            color: .white
        )
        periodClockLabel.position = CGPoint(x: 30, y: topY - 34)
        hudNode.addChild(periodClockLabel)

        // Message label
        messageLabel = RetroFont.label("", size: RetroFont.headerSize, color: .white)
        messageLabel.position = CGPoint(x: 0, y: 20)
        messageLabel.zPosition = ZPos.overlay
        messageLabel.alpha = 0
        hudNode.addChild(messageLabel)

        // Goal flash overlay
        goalFlash = SKSpriteNode(color: RetroPalette.goalRed, size: CGSize(width: visW + 40, height: visH + 40))
        goalFlash.position = .zero
        goalFlash.zPosition = ZPos.overlay - 1
        goalFlash.alpha = 0
        hudNode.addChild(goalFlash)

        // --- Control Hint Bar ---
        controlHintBar = SKNode()
        controlHintBar.zPosition = ZPos.hud + 1
        controlHintBar.alpha = 0
        hudNode.addChild(controlHintBar)

        // --- Virtual Joystick ---
        let joyR = JoystickConfig.baseRadius
        joystickCenter = CGPoint(x: -visW / 2 + joyR + 20, y: -visH / 2 + joyR + 20)

        joystickBase = SKShapeNode(circleOfRadius: joyR)
        joystickBase.position = joystickCenter
        joystickBase.fillColor = UIColor.white.withAlphaComponent(0.08)
        joystickBase.strokeColor = UIColor.white.withAlphaComponent(0.3)
        joystickBase.lineWidth = 2
        joystickBase.zPosition = ZPos.hud + 2
        joystickBase.isAntialiased = false
        joystickBase.alpha = 0
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

        let moveLabel = RetroFont.label("MOVE", size: RetroFont.tinySize, color: RetroPalette.textGray)
        moveLabel.position = CGPoint(x: joystickCenter.x, y: joystickCenter.y - joyR - 10)
        moveLabel.name = "joystickMoveLabel"
        joystickBase.addChild(moveLabel)

        // --- Shoot Indicator ---
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

    // MARK: - Clock Helper
    private func formatClock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // =========================================================================
    // MARK: - STATE MACHINE
    // =========================================================================

    private func startPregame() {
        gameState = .pregame
        periodClock = (period <= 3) ? GameConfig.periodDuration : GameConfig.otPeriodDuration
        periodClockLabel.text = formatClock(periodClock)
        periodClockLabel.fontColor = .white
        showMessage("PERIOD \(period)") { [weak self] in
            self?.startFaceoff()
        }
    }

    private func startFaceoff(at faceoffPosition: CGPoint = .zero, nextPossession: PossessionState? = nil) {
        gameState = .faceoff
        positionForFaceoff(at: faceoffPosition)

        // Determine faceoff winner based on center faceoff stats
        let resolvedPossession: PossessionState
        if let forced = nextPossession {
            resolvedPossession = forced
        } else {
            let playerCenter = playerSkaters.first(where: { $0.posType == .center })
            let opponentCenter = opponentSkaters.first(where: { $0.posType == .center })
            let playerFO = Double(playerCenter?.playerStats.faceoff ?? 50)
            let opponentFO = Double(opponentCenter?.playerStats.faceoff ?? 50)
            let playerWinChance = playerFO / (playerFO + opponentFO)
            resolvedPossession = Double.random(in: 0...1) < playerWinChance
                ? .playerOffense : .playerDefense
        }

        showMessage("FACE OFF", duration: 0.8) { [weak self] in
            self?.startPlaying(initialPossession: resolvedPossession)
        }
    }

    private func startPlaying(initialPossession: PossessionState) {
        gameState = .playing
        isLoosePuck = false
        loosePuckTimer = 0

        switch initialPossession {
        case .playerOffense:
            enterPlayerOffense(fromFaceoff: true)
        case .playerDefense:
            enterPlayerDefense(fromFaceoff: true)
        case .loosePuck:
            enterLoosePuck()
        }

        // Show tutorial on first possession
        if !tutorialShown {
            showTutorialOverlay()
        }
    }

    // MARK: - Offense Mode
    private func enterPlayerOffense(fromFaceoff: Bool = false) {
        possession = .playerOffense
        puckProtectionTimer = fromFaceoff ? 1.5 : 1.0

        // If nobody has puck, give to nearest player skater
        if puck.carriedBy == nil {
            let candidates = playerSkaters.filter { !$0.posType.isGoalie }
            if fromFaceoff, let center = candidates.first(where: { $0.posType == .center }) {
                puck.attachTo(center)
                center.isSelected = true
                selectedSkater = center
            } else if let closest = candidates.min(by: {
                $0.position.distance(to: puck.position) < $1.position.distance(to: puck.position)
            }) {
                puck.attachTo(closest)
                closest.isSelected = true
                selectedSkater = closest
            }
        } else if let carrier = puck.carriedBy {
            carrier.isSelected = true
            selectedSkater = carrier
        }

        // Show pass targets
        for skater in playerSkaters where !skater.posType.isGoalie && !skater.hasPuck {
            skater.showPassTarget()
        }

        // Show offense controls
        showControls()
        updateControlHints()

        // Clear defense state
        selectedDefender?.isSelected = false
        selectedDefender = nil
    }

    // MARK: - Defense Mode
    private func enterPlayerDefense(fromFaceoff: Bool = false) {
        possession = .playerDefense
        opponentShotClock = 0
        puckProtectionTimer = fromFaceoff ? 1.5 : 1.0

        // Clean up offense state
        for skater in playerSkaters { skater.hidePassTarget() }
        selectedSkater?.isSelected = false
        selectedSkater = nil
        shootIndicator.alpha = 0

        // If no opponent has puck from faceoff, give to opponent center
        if puck.carriedBy == nil {
            let candidates = opponentSkaters.filter { !$0.posType.isGoalie }
            if fromFaceoff, let center = candidates.first(where: { $0.posType == .center }) {
                puck.attachTo(center)
            } else if let closest = candidates.min(by: {
                $0.position.distance(to: puck.position) < $1.position.distance(to: puck.position)
            }) {
                puck.attachTo(closest)
            }
        }

        selectNearestDefender()
        showControls()
        updateControlHints()
    }

    // MARK: - Loose Puck Mode
    private func enterLoosePuck() {
        possession = .loosePuck
        isLoosePuck = true
        loosePuckTimer = loosePuckRecoveryWindow

        // Clean up
        for skater in playerSkaters { skater.hidePassTarget() }
        selectedSkater?.isSelected = false
        selectedSkater = nil
        shootIndicator.alpha = 0

        selectNearestDefender()
        showControls()
        updateControlHints()
    }

    // MARK: - Transitions
    private func switchToOffense() {
        guard gameState == .playing else { return }
        enterPlayerOffense()
    }

    private func switchToDefense() {
        guard gameState == .playing else { return }

        // If puck not carried, attach to nearest opponent
        if puck.carriedBy == nil {
            let candidates = opponentSkaters.filter { !$0.posType.isGoalie }
            if let nearest = candidates.min(by: {
                $0.position.distance(to: puck.position) < $1.position.distance(to: puck.position)
            }) {
                puck.attachTo(nearest)
            }
        }

        enterPlayerDefense()
    }

    private func selectNearestDefender() {
        let puckPos = puck.carriedBy?.position ?? puck.position
        let candidates = playerSkaters.filter { !$0.posType.isGoalie }

        if let nearest = candidates.min(by: {
            $0.position.distance(to: puckPos) < $1.position.distance(to: puckPos)
        }) {
            selectedDefender?.isSelected = false
            selectedDefender = nearest
            nearest.isSelected = true
        }
    }

    // MARK: - Control Helpers
    private func showControls() {
        joystickBase.run(SKAction.fadeAlpha(to: 0.6, duration: 0.15))
        joystickThumb.run(SKAction.fadeAlpha(to: 0.6, duration: 0.15))
        joystickDisplacement = .zero
        joystickThumb.position = joystickCenter
    }

    private func hideControls() {
        for skater in playerSkaters { skater.hidePassTarget() }
        selectedSkater?.isSelected = false
        selectedSkater = nil
        selectedDefender?.isSelected = false
        selectedDefender = nil
        resetAllTouches()
        controlHintBar.run(SKAction.fadeOut(withDuration: 0.2))
        joystickBase.run(SKAction.fadeOut(withDuration: 0.2))
        joystickThumb.run(SKAction.fadeOut(withDuration: 0.2))
        shootIndicator.alpha = 0
    }

    private func updateControlHints() {
        controlHintBar.removeAllChildren()

        let visW = size.width
        let bottomY: CGFloat = -size.height / 2 + 14

        let hintBg = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.5),
                                   size: CGSize(width: visW * 0.45, height: 22))
        hintBg.position = CGPoint(x: visW / 4 + 10, y: bottomY)
        controlHintBar.addChild(hintBg)

        switch possession {
        case .playerOffense:
            let tapHint = RetroFont.label("TAP: Pass", size: RetroFont.tinySize, color: RetroPalette.textGreen)
            tapHint.position = CGPoint(x: visW / 5, y: bottomY)
            controlHintBar.addChild(tapHint)

            let swipeHint = RetroFont.label("SWIPE: Shoot", size: RetroFont.tinySize, color: RetroPalette.gold)
            swipeHint.position = CGPoint(x: visW / 5 + 80, y: bottomY)
            controlHintBar.addChild(swipeHint)

        case .playerDefense:
            let tapHint = RetroFont.label("TAP: Switch", size: RetroFont.tinySize, color: RetroPalette.textGreen)
            tapHint.position = CGPoint(x: visW / 5, y: bottomY)
            controlHintBar.addChild(tapHint)

            let swipeHint = RetroFont.label("SWIPE: Check", size: RetroFont.tinySize, color: RetroPalette.accent)
            swipeHint.position = CGPoint(x: visW / 5 + 80, y: bottomY)
            controlHintBar.addChild(swipeHint)

        case .loosePuck:
            let hint = RetroFont.label("GET THE PUCK!", size: RetroFont.tinySize, color: RetroPalette.textYellow)
            hint.position = CGPoint(x: visW / 4 + 10, y: bottomY)
            controlHintBar.addChild(hint)
        }

        controlHintBar.run(SKAction.fadeIn(withDuration: 0.15))
    }

    // MARK: - End Period / Game
    private func endPeriod() {
        gameState = .periodBreak
        hideControls()
        for skater in allSkaters { skater.stopMoving() }
        puck.resetToCenter()

        if period < GameConfig.periodsPerGame {
            showMessage("END OF PERIOD \(period)", duration: 2.0) { [weak self] in
                guard let self = self else { return }
                self.period += 1
                self.periodLabel.text = "\(self.periodString()) PERIOD"
                self.startPregame()
            }
        } else if homeScore == awayScore {
            showMessage("OVERTIME!", duration: 2.0) { [weak self] in
                guard let self = self else { return }
                self.period = 4
                self.periodLabel.text = "OVERTIME"
                self.gameState = .overtime
                self.startPregame()
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
            if isPlayerHome { homeScore += 1 } else { awayScore += 1 }
        } else {
            if isPlayerHome { awayScore += 1 } else { homeScore += 1 }
        }

        // Record goal event
        let scorerTeam = byPlayerTeam ? playerSkaters : opponentSkaters
        if let scorer = puck.carriedBy ?? selectedSkater ?? scorerTeam.first(where: { !$0.posType.isGoalie }) {
            let teammates = scorerTeam.filter { $0.playerID != scorer.playerID && !$0.posType.isGoalie }
            goalEvents.append(GoalEvent(
                period: period,
                scorerID: scorer.playerID,
                assist1ID: teammates.first?.playerID,
                assist2ID: nil,
                teamIndex: byPlayerTeam ? 0 : 1,
                isPowerPlay: false
            ))
        }

        hideControls()
        updateScoreDisplay()

        // Effects
        puck.goalEffect()
        if byPlayerTeam {
            goalLightFlash()
            startCameraShake(intensity: 4, duration: 0.5)
            startCelebrationZoom()
            for skater in playerSkaters where !skater.posType.isGoalie {
                skater.playCelebration()
            }
        } else {
            startCameraShake(intensity: 2, duration: 0.3)
        }

        let scoringTeam = byPlayerTeam
            ? (isPlayerHome ? homeTeam! : awayTeam!)
            : (isPlayerHome ? awayTeam! : homeTeam!)
        let msgText = byPlayerTeam
            ? "GOAL!\n\(scoringTeam.name.uppercased())!"
            : "THEY SCORE!\n\(scoringTeam.name.uppercased())"

        // After goal: scored-upon team gets next puck (standard hockey)
        let nextPossession: PossessionState = byPlayerTeam ? .playerDefense : .playerOffense

        showMessage(msgText, duration: 2.5) { [weak self] in
            guard let self = self else { return }

            // Overtime is sudden death: game ends immediately on goal
            if self.period > GameConfig.periodsPerGame {
                self.puck.resetToCenter()
                self.endGame()
            } else if self.periodClock <= 0 {
                self.puck.resetToCenter()
                self.endPeriod()
            } else {
                // Center ice faceoff after goal
                self.startFaceoff(nextPossession: nextPossession)
            }
        }
    }

    // =========================================================================
    // MARK: - GAME LOOP
    // =========================================================================

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        updateCamera(dt: dt)
        puck.update(dt: dt)

        guard gameState == .playing else { return }

        // Period clock
        periodClock -= dt
        periodClockLabel.text = formatClock(periodClock)
        if periodClock < 10 {
            periodClockLabel.fontColor = RetroPalette.textRed
        }
        if periodClock <= 0 {
            endPeriod()
            return
        }

        // Puck position (follows carrier)
        puck.updatePosition()

        // Timers
        if puckProtectionTimer > 0 { puckProtectionTimer -= dt }
        if defenseCheckCooldown > 0 { defenseCheckCooldown -= dt }

        switch possession {
        case .playerOffense:
            updatePlayerOffense(currentTime: currentTime, dt: dt)
        case .playerDefense:
            updatePlayerDefense(currentTime: currentTime, dt: dt)
        case .loosePuck:
            updateLoosePuck(currentTime: currentTime, dt: dt)
        }
    }

    // MARK: - Offense Update
    private func updatePlayerOffense(currentTime: TimeInterval, dt: TimeInterval) {
        let puckVel = puck.physicsBody?.velocity ?? .zero

        // AI: opponent defense
        ai.updateDefenders(
            skaters: opponentSkaters,
            puckPosition: puck.position,
            puckCarrier: puck.carriedBy,
            puckVelocity: puckVel,
            currentTime: currentTime
        )

        // AI: player teammates
        ai.updateOffensiveAI(
            skaters: playerSkaters,
            puckCarrier: puck.carriedBy,
            attackingRight: attackingRight,
            opponents: opponentSkaters,
            currentTime: currentTime
        )

        // Pass arrival
        if puck.isPass {
            let all = playerSkaters + opponentSkaters
            if let receiver = puck.checkPassArrival(skaters: all) {
                let playerTeamIndex = 0  // player team is always teamIndex 0
                puck.attachTo(receiver)

                if receiver.teamIndex == playerTeamIndex {
                    // Teammate caught the pass
                    receiver.isSelected = true
                    selectedSkater = receiver
                    puckProtectionTimer = 0.8
                    for s in playerSkaters { s.hidePassTarget() }
                    for s in playerSkaters where !s.posType.isGoalie && !s.hasPuck {
                        s.showPassTarget()
                    }
                } else {
                    // Opponent intercepted!
                    switchToDefense()
                    return
                }
            } else if !puck.isPass {
                // Pass timed out
                enterLoosePuck()
                return
            }
        }

        // Loose puck during offense (from body check etc.)
        if isLoosePuck {
            updateLoosePuckRecovery(currentTime: currentTime, dt: dt)
            return
        }

        // Shot resolution (timeout)
        if puck.hasBeenShot {
            if puck.timeSinceShot > 2.5 {
                puck.hasBeenShot = false
                enterLoosePuck()
            }
            return
        }

        // Body check by AI defenders
        if puckProtectionTimer <= 0,
           let carrier = puck.carriedBy,
           carrier.teamIndex == 0,
           currentTime - lastBodyCheckTime > bodyCheckInterval {
            lastBodyCheckTime = currentTime

            for defender in opponentSkaters where !defender.posType.isGoalie {
                if ai.checkBodyCheck(defender: defender, puckCarrier: carrier) {
                    startLoosePuck(from: carrier)
                    return
                }
            }
        }

        // Shoot indicator
        updateShootIndicator()

        // Joystick movement (move carrier)
        if joystickDisplacement != .zero,
           let carrier = puck.carriedBy,
           carrier.teamIndex == 0 {
            let moveTarget = CGPoint(
                x: carrier.position.x + joystickDisplacement.x * 80,
                y: carrier.position.y + joystickDisplacement.y * 80
            )
            carrier.moveToward(moveTarget)
        } else if joystickDisplacement == .zero,
                  let carrier = puck.carriedBy,
                  carrier.teamIndex == 0,
                  joystickTouch == nil {
            carrier.stopMoving()
        }

        // Puck out of bounds
        let hw = rink.rinkWidth / 2 + 20
        let hh = rink.rinkHeight / 2 + 20
        if abs(puck.position.x) > hw || abs(puck.position.y) > hh {
            puck.resetToCenter()
            startFaceoff(nextPossession: .playerOffense)
        }
    }

    // MARK: - Defense Update
    private func updatePlayerDefense(currentTime: TimeInterval, dt: TimeInterval) {
        let puckVel = puck.physicsBody?.velocity ?? .zero
        let playerTeamIndex = 0  // player team is always teamIndex 0

        // AI: player's team defends (excluding player-controlled defender)
        ai.updateDefenders(
            skaters: playerSkaters,
            puckPosition: puck.position,
            puckCarrier: puck.carriedBy,
            puckVelocity: puckVel,
            currentTime: currentTime
        )

        // AI: opponent offense
        opponentShotClock += dt
        if let carrier = puck.carriedBy, carrier.teamIndex != playerTeamIndex {
            let action = ai.updateOpponentOffense(
                skaters: opponentSkaters,
                puckCarrier: carrier,
                attackingRight: !attackingRight,
                defenders: playerSkaters,
                puck: puck,
                currentTime: currentTime,
                opponentShotClock: opponentShotClock
            )
            executeOpponentAction(action, carrier: carrier)
        } else if puck.carriedBy == nil && !puck.hasBeenShot && !puck.isPass {
            // Puck is loose during defense — switch to loose puck mode
            enterLoosePuck()
            return
        }

        // Pass arrival for opponent passes
        if puck.isPass {
            let all = playerSkaters + opponentSkaters
            if let receiver = puck.checkPassArrival(skaters: all) {
                puck.attachTo(receiver)

                if receiver.teamIndex == playerTeamIndex {
                    // Player team intercepted opponent pass!
                    switchToOffense()
                    return
                } else {
                    // Opponent teammate received pass
                    puckProtectionTimer = 0.8
                    opponentShotClock = max(opponentShotClock - 1, 0)
                }
            } else if !puck.isPass {
                // Opponent pass timed out
                enterLoosePuck()
                return
            }
        }

        // Shot resolution (opponent shot timeout)
        if puck.hasBeenShot {
            if puck.timeSinceShot > 2.5 {
                puck.hasBeenShot = false
                enterLoosePuck()
            }
            return
        }

        // Joystick moves selected defender
        if joystickDisplacement != .zero, let defender = selectedDefender {
            let moveTarget = CGPoint(
                x: defender.position.x + joystickDisplacement.x * 80,
                y: defender.position.y + joystickDisplacement.y * 80
            )
            defender.moveToward(moveTarget)
        } else if joystickDisplacement == .zero, let defender = selectedDefender, joystickTouch == nil {
            defender.stopMoving()
        }

        // Body check charge resolution
        if let defender = selectedDefender, defender.isCharging,
           let carrier = puck.carriedBy {
            let dist = defender.position.distance(to: carrier.position)
            if dist < GameConfig.skaterRadius * 2.5 {
                defender.isCharging = false
                if ai.checkBodyCheck(defender: defender, puckCarrier: carrier) {
                    startLoosePuck(from: carrier)
                    startCameraShake(intensity: 2, duration: 0.2)
                } else {
                    defender.playHitAnimation()
                }
            }
        }

        // AI-initiated body checks by player's other defenders
        if puckProtectionTimer <= 0,
           let carrier = puck.carriedBy,
           carrier.teamIndex != playerTeamIndex,
           currentTime - lastBodyCheckTime > bodyCheckInterval {
            lastBodyCheckTime = currentTime

            for defender in playerSkaters where !defender.posType.isGoalie && defender !== selectedDefender {
                if ai.checkBodyCheck(defender: defender, puckCarrier: carrier) {
                    startLoosePuck(from: carrier)
                    return
                }
            }
        }

        // Puck out of bounds
        let hw = rink.rinkWidth / 2 + 20
        let hh = rink.rinkHeight / 2 + 20
        if abs(puck.position.x) > hw || abs(puck.position.y) > hh {
            puck.resetToCenter()
            startFaceoff(nextPossession: .playerDefense)
        }
    }

    // MARK: - Loose Puck Update
    private func updateLoosePuck(currentTime: TimeInterval, dt: TimeInterval) {
        updateLoosePuckRecovery(currentTime: currentTime, dt: dt)
    }

    private func updateLoosePuckRecovery(currentTime: TimeInterval, dt: TimeInterval) {
        // Guard against race condition: physics contact may have already resolved possession
        guard puck.isLoose else { return }

        // Check if goalie should cover the puck
        checkGoalieCover()
        guard puck.isLoose else { return }

        loosePuckTimer -= dt
        let playerTeamIndex = 0  // player team is always teamIndex 0
        let puckVel = puck.physicsBody?.velocity ?? .zero

        // Both teams chase the puck
        ai.updateDefenders(
            skaters: playerSkaters,
            puckPosition: puck.position,
            puckCarrier: nil,
            puckVelocity: puckVel,
            currentTime: currentTime
        )
        ai.updateDefenders(
            skaters: opponentSkaters,
            puckPosition: puck.position,
            puckCarrier: nil,
            puckVelocity: puckVel,
            currentTime: currentTime
        )

        // Joystick controls selected defender/skater
        if joystickDisplacement != .zero, let controlled = selectedDefender {
            let moveTarget = CGPoint(
                x: controlled.position.x + joystickDisplacement.x * 80,
                y: controlled.position.y + joystickDisplacement.y * 80
            )
            controlled.moveToward(moveTarget)
        }

        // Proximity pickup (skip if physics contact already resolved this frame)
        guard puck.isLoose else { return }
        for skater in allSkaters where !skater.posType.isGoalie {
            let dist = skater.position.distance(to: puck.position)
            if dist < GameConfig.skaterRadius * 2.5 {
                puck.attachTo(skater)
                isLoosePuck = false
                loosePuckTimer = 0

                if skater.teamIndex == playerTeamIndex {
                    switchToOffense()
                } else {
                    switchToDefense()
                }
                return
            }
        }

        // Timeout — give to whichever team's skater is closest
        if loosePuckTimer <= 0 {
            isLoosePuck = false
            let nearest = allSkaters.filter { !$0.posType.isGoalie }
                .min { $0.position.distance(to: puck.position) < $1.position.distance(to: puck.position) }
            if let skater = nearest {
                puck.attachTo(skater)
                if skater.teamIndex == playerTeamIndex {
                    switchToOffense()
                } else {
                    switchToDefense()
                }
            } else {
                switchToOffense()
            }
        }
    }

    // MARK: - Opponent Action Execution
    private func executeOpponentAction(_ action: OpponentAction, carrier: SkaterNode) {
        switch action {
        case .none:
            // Default: carrier skates toward goal, but hold position if already close
            let goalMouth = !attackingRight ? rink.rightGoalMouth : rink.leftGoalMouth
            let distToGoal = carrier.position.distance(to: goalMouth)
            if distToGoal < 80 {
                carrier.stopMoving()
            } else {
                let target = CGPoint(
                    x: goalMouth.x + (!attackingRight ? -80 : 80),
                    y: carrier.position.y * 0.9
                )
                carrier.moveToward(target)
            }

        case .skate(let target):
            carrier.moveToward(target)

        case .pass(let target):
            puck.pass(toward: target.position, targetID: target.playerID)
            opponentShotClock = max(opponentShotClock - 2, 0)

        case .shoot(let target, let power):
            puck.shoot(toward: target, power: power)  // shoot() calls playShootAnimation() on the carrier
        }
    }

    // MARK: - Loose Puck Start
    private func startLoosePuck(from carrier: SkaterNode) {
        guard gameState == .playing else { return }

        puck.detach()
        carrier.isSelected = false
        if selectedSkater?.playerID == carrier.playerID { selectedSkater = nil }

        let randomAngle = CGFloat.random(in: 0...(2 * .pi))
        let knockSpeed: CGFloat = 80
        puck.physicsBody?.velocity = CGVector(
            dx: cos(randomAngle) * knockSpeed,
            dy: sin(randomAngle) * knockSpeed
        )

        for skater in playerSkaters { skater.hidePassTarget() }
        enterLoosePuck()
    }

    // =========================================================================
    // MARK: - CAMERA SYSTEM
    // =========================================================================

    private func updateCamera(dt: TimeInterval) {
        guard dt > 0 else { return }

        var targetPos: CGPoint

        if let carrier = puck.carriedBy {
            targetPos = carrier.position
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

        targetPos = rink.convert(targetPos, to: self)

        let lerpFactor = CameraConfig.followSpeed
        var camPos = cameraNode.position
        camPos.x += (targetPos.x - camPos.x) * lerpFactor
        camPos.y += (targetPos.y - camPos.y) * lerpFactor

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
            camPos.x = 0
        }
        if minY < maxY {
            camPos.y = max(minY, min(maxY, camPos.y))
        } else {
            camPos.y = 0
        }

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
    // MARK: - TOUCH CONTROLS
    // =========================================================================

    private func isJoystickTouch(_ touch: UITouch) -> Bool {
        let loc = touch.location(in: self)
        let hudLoc = hudNode.convert(loc, from: self)
        return hudLoc.x < 0
    }

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
            if tutorialOverlay != nil {
                dismissTutorial()
                return
            }

            guard gameState == .playing else { return }

            // --- Joystick (left side) ---
            if joystickTouch == nil && isJoystickTouch(touch) {
                joystickTouch = touch
                let loc = touch.location(in: self)
                let hudLoc = hudNode.convert(loc, from: self)
                joystickOrigin = hudLoc
                joystickBase.position = hudLoc
                joystickThumb.position = hudLoc
                continue
            }

            // --- Action touch (right side) ---
            if actionTouch == nil {
                actionTouch = touch
                let sceneLocation = touch.location(in: self)
                let rinkLocation = convert(sceneLocation, to: rink)

                switch possession {
                case .playerOffense:
                    // Pass is now resolved on touchesEnded (tap detection)
                    actionTouchState = .holding(start: sceneLocation, time: touch.timestamp)

                case .playerDefense:
                    // Tap own player = switch defender
                    for skater in playerSkaters where !skater.posType.isGoalie {
                        let dist = rinkLocation.distance(to: skater.position)
                        if dist < TouchConfig.tapRadius {
                            selectedDefender?.isSelected = false
                            selectedDefender = skater
                            skater.isSelected = true
                            actionTouch = nil
                            actionTouchState = .none
                            return
                        }
                    }
                    actionTouchState = .holding(start: sceneLocation, time: touch.timestamp)

                case .loosePuck:
                    // Tap own player = switch controlled skater
                    for skater in playerSkaters where !skater.posType.isGoalie {
                        let dist = rinkLocation.distance(to: skater.position)
                        if dist < TouchConfig.tapRadius {
                            selectedDefender?.isSelected = false
                            selectedDefender = skater
                            skater.isSelected = true
                            actionTouch = nil
                            actionTouchState = .none
                            return
                        }
                    }
                    actionTouchState = .holding(start: sceneLocation, time: touch.timestamp)
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
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
                    let clampedDist = min(dist, maxR)
                    let nx = dx / dist
                    let ny = dy / dist
                    joystickThumb.position = CGPoint(
                        x: joystickOrigin.x + nx * clampedDist,
                        y: joystickOrigin.y + ny * clampedDist
                    )
                    let magnitude = clampedDist / maxR
                    joystickDisplacement = CGPoint(x: nx * magnitude, y: ny * magnitude)
                }
                continue
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch === joystickTouch {
                joystickTouch = nil
                joystickDisplacement = .zero
                joystickBase.position = joystickCenter
                joystickThumb.position = joystickCenter
                continue
            }

            if touch === actionTouch {
                guard gameState == .playing else {
                    actionTouch = nil
                    actionTouchState = .none
                    continue
                }

                let sceneLocation = touch.location(in: self)

                switch possession {
                case .playerOffense:
                    handleOffenseSwipe(sceneLocation: sceneLocation, endTime: touch.timestamp)

                case .playerDefense:
                    handleDefenseSwipe(sceneLocation: sceneLocation, endTime: touch.timestamp)

                case .loosePuck:
                    break // no swipe action during loose puck
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

    // MARK: - Swipe Handlers
    private func handleOffenseSwipe(sceneLocation: CGPoint, endTime: TimeInterval) {
        switch actionTouchState {
        case .holding(let start, let startTime):
            let dist = sceneLocation.distance(to: start)
            let duration = endTime - startTime

            let isSwipe = dist > TouchConfig.swipeMinDistance && duration < TouchConfig.swipeMaxDuration

            if !isSwipe {
                // TAP — check if tapping a teammate to pass
                let rinkLocation = convert(sceneLocation, to: rink)
                for skater in playerSkaters where !skater.posType.isGoalie && !skater.hasPuck {
                    let tapDist = rinkLocation.distance(to: skater.position)
                    if tapDist < TouchConfig.tapRadius {
                        performPass(to: skater)
                        return
                    }
                }
                return  // tap on empty space — do nothing
            }

            // SWIPE — shoot or deke
            let swipeVector = sceneLocation - start
            let swipeAngle = atan2(swipeVector.y, swipeVector.x)

            let goalDir: CGFloat = attackingRight ? 0 : .pi
            var angleDiff = abs(swipeAngle - goalDir)
            if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }

            if angleDiff < TouchConfig.dekeAngleThreshold {
                // Shoot
                let power = min(dist * 5, GameConfig.shotSpeedMax)
                let goalMouth = attackingRight ? rink.rightGoalMouth : rink.leftGoalMouth
                let rinkTarget = convert(sceneLocation, to: rink)
                let aimX = goalMouth.x * 0.7 + rinkTarget.x * 0.3
                let aimY = rinkTarget.y * 0.6 + goalMouth.y * 0.4
                performShot(toward: CGPoint(x: aimX, y: aimY), power: power)
            } else {
                // Deke
                if let carrier = puck.carriedBy {
                    carrier.deke(direction: swipeAngle)
                }
            }
        case .none:
            break
        }
    }

    private func handleDefenseSwipe(sceneLocation: CGPoint, endTime: TimeInterval) {
        switch actionTouchState {
        case .holding(let start, let startTime):
            let dist = sceneLocation.distance(to: start)
            let duration = endTime - startTime
            guard dist > TouchConfig.swipeMinDistance && duration < TouchConfig.swipeMaxDuration else { return }

            performDefensiveBodyCheck()
        case .none:
            break
        }
    }

    // =========================================================================
    // MARK: - ACTIONS
    // =========================================================================

    private func performPass(to target: SkaterNode) {
        guard let carrier = puck.carriedBy,
              carrier.teamIndex == 0 else { return }

        carrier.isSelected = false

        let passAccuracy = Double(carrier.playerStats.passing) / 99.0
        let passChance = 0.6 + passAccuracy * 0.35

        let midpoint = CGPoint(
            x: (carrier.position.x + target.position.x) / 2,
            y: (carrier.position.y + target.position.y) / 2
        )
        let teammates = playerSkaters.filter { !$0.posType.isGoalie }

        for defender in opponentSkaters where !defender.posType.isGoalie {
            let defDist = defender.position.distance(to: midpoint)
            if defDist < 25 && Double.random(in: 0...1) > passChance {
                puck.pass(toward: midpoint, targetID: target.playerID, teammates: teammates)
                run(SKAction.wait(forDuration: 0.3)) { [weak self] in
                    guard let self = self, self.gameState == .playing else { return }
                    self.puck.clearPassState()
                    self.enterLoosePuck()
                }
                return
            }
        }

        puck.pass(toward: target.position, targetID: target.playerID, teammates: teammates)
    }

    private func performShot(toward target: CGPoint, power: CGFloat) {
        guard puck.carriedBy != nil else { return }

        for skater in playerSkaters { skater.hidePassTarget() }
        shootIndicator.alpha = 0
        puck.shoot(toward: target, power: power)  // shoot() calls playShootAnimation() on the carrier
        selectedSkater?.isSelected = false
    }

    private func performDefensiveBodyCheck() {
        guard defenseCheckCooldown <= 0,
              let defender = selectedDefender,
              let carrier = puck.carriedBy,
              carrier.teamIndex != 0 else { return }

        defenseCheckCooldown = 0.8

        // Sprint defender toward carrier
        let sprintSpeed = defender.maxSpeed * 1.4
        defender.moveToward(carrier.position, speed: sprintSpeed)
        defender.isCharging = true
    }

    // =========================================================================
    // MARK: - PHYSICS CONTACT
    // =========================================================================

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        guard gameState == .playing else { return }

        let playerTeamIndex = 0  // player team is always teamIndex 0

        // Puck hits boards while shot -> loose puck
        if puck.hasBeenShot {
            if (a == PhysicsCategory.puck && b == PhysicsCategory.boards) ||
               (a == PhysicsCategory.boards && b == PhysicsCategory.puck) {
                puck.hasBeenShot = false
                enterLoosePuck()
                return
            }
        }

        // Puck hits a skater while shot -> check if it's a goalie
        if puck.hasBeenShot {
            if (a == PhysicsCategory.puck && b == PhysicsCategory.skater) ||
               (a == PhysicsCategory.skater && b == PhysicsCategory.puck) {
                let skaterNode = a == PhysicsCategory.skater ? contact.bodyA.node : contact.bodyB.node
                if let skater = skaterNode as? SkaterNode, skater.posType.isGoalie {
                    let puckSpeed = hypot(puck.physicsBody?.velocity.dx ?? 0, puck.physicsBody?.velocity.dy ?? 0)
                    let goalieReflexes = Double(skater.playerStats.reflexes) / 99.0

                    let trickleChance = 0.08 + (puckSpeed / Double(GameConfig.shotSpeedMax)) * 0.07 - goalieReflexes * 0.05
                    if Double.random(in: 0...1) < trickleChance {
                        return // puck squeaks through
                    }

                    // Save!
                    puck.hasBeenShot = false
                    puck.physicsBody?.velocity = .zero
                    puck.physicsBody?.isDynamic = false

                    let faceoffPos = self.nearestFaceoffDot(to: self.puck.position)
                    run(SKAction.wait(forDuration: 0.6)) { [weak self] in
                        guard let self = self, self.gameState == .playing else { return }
                        self.puck.physicsBody?.isDynamic = true
                        if skater.teamIndex == playerTeamIndex {
                            self.startFaceoff(at: faceoffPos, nextPossession: .playerOffense)
                        } else {
                            self.startFaceoff(at: faceoffPos, nextPossession: .playerDefense)
                        }
                    }
                    return
                }
            }
        }

        // Puck hits goal trigger zone -> GOAL
        // Attribution based on which goal: right goal = team attacking right scored,
        // left goal = team attacking left scored. No velocity check needed since
        // the trigger zone is positioned inside the net.
        if (a == PhysicsCategory.puck && b == PhysicsCategory.goal) ||
           (a == PhysicsCategory.goal && b == PhysicsCategory.puck) {
            let goalNode = a == PhysicsCategory.goal ? contact.bodyA.node : contact.bodyB.node

            if goalNode?.name == "rightGoal" {
                puck.hasBeenShot = false
                puck.physicsBody?.velocity = .zero
                puck.physicsBody?.isDynamic = false
                handleGoalScored(byPlayerTeam: attackingRight)
            } else if goalNode?.name == "leftGoal" {
                puck.hasBeenShot = false
                puck.physicsBody?.velocity = .zero
                puck.physicsBody?.isDynamic = false
                handleGoalScored(byPlayerTeam: !attackingRight)
            }
            return
        }

        // Loose puck hits a non-goalie skater -> pickup
        if puck.isLoose && !puck.hasBeenShot && !puck.isPass {
            if (a == PhysicsCategory.puck && b == PhysicsCategory.skater) ||
               (a == PhysicsCategory.skater && b == PhysicsCategory.puck) {
                let skaterNode = a == PhysicsCategory.skater ? contact.bodyA.node : contact.bodyB.node
                guard let skater = skaterNode as? SkaterNode, !skater.posType.isGoalie else { return }

                messageLabel.removeAllActions()
                messageLabel.alpha = 0

                puck.attachTo(skater)
                isLoosePuck = false
                loosePuckTimer = 0
                puckProtectionTimer = 0.8

                if skater.teamIndex == playerTeamIndex {
                    switchToOffense()
                } else {
                    switchToDefense()
                }
            }
        }
    }

    // =========================================================================
    // MARK: - POSITIONING
    // =========================================================================

    private func positionForFaceoff(at faceoffPosition: CGPoint = .zero) {
        let hw = rink.rinkWidth / 2
        let hh = rink.rinkHeight / 2
        let fx = faceoffPosition.x
        let fy = faceoffPosition.y

        // Player team always on left (attacking right), opponent on right
        let leftPositions: [(Position, CGPoint)] = [
            (.center,       CGPoint(x: fx - 15, y: fy)),
            (.leftWing,     CGPoint(x: fx - 50, y: fy + hh * 0.15)),
            (.rightWing,    CGPoint(x: fx - 50, y: fy - hh * 0.15)),
            (.leftDefense,  CGPoint(x: fx - 80, y: fy + hh * 0.12)),
            (.rightDefense, CGPoint(x: fx - 80, y: fy - hh * 0.12)),
            (.goalie,       CGPoint(x: -hw + GameConfig.goalDepth + 20, y: 0)),
        ]

        let rightPositions: [(Position, CGPoint)] = [
            (.center,       CGPoint(x: fx + 15, y: fy)),
            (.leftWing,     CGPoint(x: fx + 50, y: fy - hh * 0.15)),
            (.rightWing,    CGPoint(x: fx + 50, y: fy + hh * 0.15)),
            (.leftDefense,  CGPoint(x: fx + 80, y: fy - hh * 0.12)),
            (.rightDefense, CGPoint(x: fx + 80, y: fy + hh * 0.12)),
            (.goalie,       CGPoint(x: hw - GameConfig.goalDepth - 20, y: 0)),
        ]

        let playerPositions = leftPositions
        let opponentPositions = rightPositions

        for (pos, point) in playerPositions {
            if let skater = playerSkaters.first(where: { $0.posType == pos }) {
                skater.position = CGPoint(
                    x: max(-hw + 20, min(hw - 20, point.x)),
                    y: max(-hh + 20, min(hh - 20, point.y))
                )
                skater.stopMoving()
            }
        }

        for (pos, point) in opponentPositions {
            if let skater = opponentSkaters.first(where: { $0.posType == pos }) {
                skater.position = CGPoint(
                    x: max(-hw + 20, min(hw - 20, point.x)),
                    y: max(-hh + 20, min(hh - 20, point.y))
                )
                skater.stopMoving()
            }
        }

        // Position puck at faceoff location
        puck.detach()
        puck.clearPassState()
        puck.position = faceoffPosition
        puck.physicsBody?.velocity = .zero
        puck.physicsBody?.isDynamic = true
        puck.hasBeenShot = false
        puck.timeSinceShot = 0
    }

    // MARK: - Goalie Covers Puck
    /// When puck is loose and slow near the crease, the goalie skates to it and covers it.
    private var goalieCoveringPuck: Bool = false
    private var goalieSkatingToPuck: SkaterNode? = nil

    private func checkGoalieCover() {
        guard puck.isLoose, !puck.hasBeenShot, !puck.isPass, !goalieCoveringPuck else { return }

        let puckSpeed = hypot(puck.physicsBody?.velocity.dx ?? 0, puck.physicsBody?.velocity.dy ?? 0)
        guard puckSpeed < 80 else {
            goalieSkatingToPuck = nil
            return
        }

        // Find a goalie whose crease contains the puck
        let allGoalies = allSkaters.filter { $0.posType.isGoalie }
        var nearGoalie: SkaterNode? = nil
        for goalie in allGoalies {
            let dist = goalie.position.distance(to: puck.position)
            if dist < GameConfig.creaseRadius {
                nearGoalie = goalie
                break
            }
        }

        guard let goalie = nearGoalie else {
            goalieSkatingToPuck = nil
            return
        }

        // Goalie skates toward the puck
        goalieSkatingToPuck = goalie
        let coverRadius: CGFloat = 12
        let dist = goalie.position.distance(to: puck.position)

        if dist > coverRadius {
            // Move goalie toward the puck
            goalie.moveToward(puck.position, speed: goalie.maxSpeed * 0.6)
            return
        }

        // Goalie has reached the puck — check it's still loose
        guard puck.isLoose else { return }

        // Cover it
        goalieCoveringPuck = true
        goalieSkatingToPuck = nil
        goalie.stopMoving()
        puck.physicsBody?.velocity = .zero
        puck.physicsBody?.isDynamic = false
        puck.position = goalie.position
        isLoosePuck = false
        loosePuckTimer = 0

        let faceoffPos = nearestFaceoffDot(to: goalie.position)
        let nextPossession: PossessionState = goalie.teamIndex == 0
            ? .playerOffense : .playerDefense

        run(SKAction.wait(forDuration: 1.5)) { [weak self] in
            guard let self = self, self.gameState == .playing else { return }
            self.puck.physicsBody?.isDynamic = true
            self.goalieCoveringPuck = false
            self.startFaceoff(at: faceoffPos, nextPossession: nextPossession)
        }
    }

    /// Find the nearest faceoff dot to a position (excluding center ice for zone faceoffs)
    private func nearestFaceoffDot(to position: CGPoint) -> CGPoint {
        let dots = rink.faceoffDots
        let zoneDots = Array(dots.dropFirst())  // exclude center ice
        return zoneDots.min(by: {
            $0.distance(to: position) < $1.distance(to: position)
        }) ?? .zero
    }

    // =========================================================================
    // MARK: - HELPERS
    // =========================================================================

    // MARK: - Tutorial Overlay
    private func showTutorialOverlay() {
        guard tutorialOverlay == nil else { return }

        let overlay = SKNode()
        overlay.zPosition = ZPos.overlay + 5

        let panelW: CGFloat = min(size.width * 0.85, 420)
        let panelH: CGFloat = 180
        let backdrop = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.85),
                                     size: CGSize(width: panelW, height: panelH))
        backdrop.position = .zero
        overlay.addChild(backdrop)

        let border = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH))
        border.strokeColor = RetroPalette.gold.withAlphaComponent(0.5)
        border.lineWidth = 1
        border.fillColor = .clear
        overlay.addChild(border)

        let title = RetroFont.label("CONTROLS", size: RetroFont.headerSize, color: RetroPalette.gold)
        title.position = CGPoint(x: 0, y: 65)
        overlay.addChild(title)

        // Offense section
        let offTitle = RetroFont.label("OFFENSE", size: RetroFont.smallSize, color: RetroPalette.textYellow)
        offTitle.position = CGPoint(x: -90, y: 40)
        overlay.addChild(offTitle)

        let move = RetroFont.label("Drag = Skate", size: RetroFont.bodySize, color: .white)
        move.position = CGPoint(x: -90, y: 22)
        overlay.addChild(move)

        let pass = RetroFont.label("Tap Player = Pass", size: RetroFont.bodySize, color: RetroPalette.textGreen)
        pass.position = CGPoint(x: -90, y: 4)
        overlay.addChild(pass)

        let shoot = RetroFont.label("Swipe = Shoot!", size: RetroFont.bodySize, color: RetroPalette.gold)
        shoot.position = CGPoint(x: -90, y: -14)
        overlay.addChild(shoot)

        // Defense section
        let defTitle = RetroFont.label("DEFENSE", size: RetroFont.smallSize, color: RetroPalette.textYellow)
        defTitle.position = CGPoint(x: 90, y: 40)
        overlay.addChild(defTitle)

        let defMove = RetroFont.label("Drag = Move Defender", size: RetroFont.bodySize, color: .white)
        defMove.position = CGPoint(x: 90, y: 22)
        overlay.addChild(defMove)

        let defSwitch = RetroFont.label("Tap Player = Switch", size: RetroFont.bodySize, color: RetroPalette.textGreen)
        defSwitch.position = CGPoint(x: 90, y: 4)
        overlay.addChild(defSwitch)

        let defCheck = RetroFont.label("Swipe = Body Check!", size: RetroFont.bodySize, color: RetroPalette.accent)
        defCheck.position = CGPoint(x: 90, y: -14)
        overlay.addChild(defCheck)

        let tapStart = RetroFont.label("TAP ANYWHERE TO PLAY", size: RetroFont.smallSize, color: RetroPalette.textGray)
        tapStart.position = CGPoint(x: 0, y: -50)
        overlay.addChild(tapStart)

        let blink = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6),
        ]))
        tapStart.run(blink)

        hudNode.addChild(overlay)
        tutorialOverlay = overlay

        gameState = .faceoff
    }

    private func dismissTutorial() {
        guard let overlay = tutorialOverlay else { return }
        tutorialShown = true
        overlay.run(SKAction.fadeOut(withDuration: 0.2)) { [weak self] in
            overlay.removeFromParent()
            self?.tutorialOverlay = nil
            self?.gameState = .playing
        }
    }

    // MARK: - Shoot Indicator
    private func updateShootIndicator() {
        guard possession == .playerOffense,
              let carrier = puck.carriedBy,
              carrier.teamIndex == 0,
              !puck.hasBeenShot else {
            shootIndicator.alpha = 0
            return
        }

        let goalMouth = attackingRight ? rink.rightGoalMouth : rink.leftGoalMouth
        let dist = carrier.position.distance(to: goalMouth)
        let shootRange = rink.rinkWidth * 0.35

        if dist < shootRange {
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

        GameManager.shared.awardCoachingCredits(result: result, isPlayerHome: isPlayerHome)

        GameManager.transition(from: view, toSceneType: PostGameScene.self) { [scheduleIndex, homeTeam, awayTeam] scene in
            scene.gameResult = result
            scene.homeTeam = homeTeam
            scene.awayTeam = awayTeam
            scene.scheduleIndex = scheduleIndex
        }
    }
}
