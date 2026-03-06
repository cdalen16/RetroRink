import SpriteKit

// MARK: - Draft Scene
class DraftScene: BaseScene {

    private let gm = GameManager.shared
    private var draftPool: [Player] = []
    private var currentPick: Int = 0
    private var currentRound: Int = 1
    private var isDraftComplete: Bool = false
    private var isDraftStarted: Bool = false
    private var selectedProspectIndex: Int? = nil

    private var scrollContainer: ScrollContainer!
    private var roundInfoLabel: SKLabelNode!
    private var statusLabel: SKLabelNode!
    private var draftButton: RetroButton?
    private var announcementLabel: SKLabelNode?
    private var backButton: RetroButton!

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        // Initialize draft pool from league free agents (draft class)
        if gm.league.seasonPhase == .draft || gm.league.seasonPhase == .offseason {
            draftPool = gm.league?.freeAgents ?? []
        } else {
            // Start a fresh draft
            gm.league.startDraft()
            draftPool = gm.league?.freeAgents ?? []
        }

        setupHeader()
        setupScrollContainer()
        setupControls()
        refreshDraftBoard()

        backButton = makeBackButton(target: self) { [weak self] in
            GameManager.transition(from: self?.view, toSceneType: HubScene.self)
        }
        backButton.position = CGPoint(x: safeLeft + 52, y: safeTop - 20)
        addChild(backButton)
    }

    // MARK: - Setup

    private func setupHeader() {
        let title = RetroFont.label("ENTRY DRAFT", size: RetroFont.headerSize, color: RetroPalette.gold)
        title.position = CGPoint(x: 40, y: safeTop - 20)
        addChild(title)

        roundInfoLabel = RetroFont.label("ROUND \(currentRound) | PICK \(currentPick + 1)",
                                          size: RetroFont.bodySize, color: .white)
        roundInfoLabel.position = CGPoint(x: 40, y: safeTop - 42)
        addChild(roundInfoLabel)

        // Remaining rounds info
        statusLabel = RetroFont.label(
            "Rounds: \(currentRound)/\(GameConfig.draftRounds) | Available: \(draftPool.count)",
            size: RetroFont.tinySize, color: RetroPalette.textGray
        )
        statusLabel.position = CGPoint(x: safeRight - 100, y: safeTop - 20)
        addChild(statusLabel)
    }

    private func setupScrollContainer() {
        let containerHeight = safeHeight - 130
        scrollContainer = ScrollContainer(width: safeWidth - 20, height: containerHeight)
        scrollContainer.position = CGPoint(x: 0, y: -5)
        addChild(scrollContainer)
    }

    private func setupControls() {
        // Announcement area
        announcementLabel = RetroFont.label("", size: RetroFont.bodySize, color: RetroPalette.textYellow)
        announcementLabel?.position = CGPoint(x: 0, y: safeBottom + 60)
        addChild(announcementLabel!)

        // Draft button (hidden until player selects a prospect)
        let btn = RetroButton(text: "DRAFT PLAYER", width: 180, height: 40,
                               color: RetroPalette.midPanel, borderColor: RetroPalette.accent)
        btn.position = CGPoint(x: 0, y: safeBottom + 28)
        btn.alpha = 0.3
        btn.isUserInteractionEnabled = false
        btn.action = { [weak self] in self?.draftSelectedPlayer() }
        addChild(btn)
        draftButton = btn
    }

    // MARK: - Draft Board

    private func refreshDraftBoard() {
        scrollContainer.clearContent()
        selectedProspectIndex = nil
        draftButton?.alpha = 0.3
        draftButton?.isUserInteractionEnabled = false

        // Update header
        roundInfoLabel.text = "ROUND \(currentRound) | PICK \(currentPick + 1)"
        statusLabel.text = "Rounds: \(currentRound)/\(GameConfig.draftRounds) | Available: \(draftPool.count)"

        if isDraftComplete || draftPool.isEmpty {
            let doneLabel = RetroFont.label("DRAFT COMPLETE!", size: RetroFont.headerSize, color: RetroPalette.gold)
            scrollContainer.addScrollContent(doneLabel, at: 0)

            draftButton?.removeFromParent()
            draftButton = nil
            announcementLabel?.text = "All rounds completed"
            return
        }

        let containerW = safeWidth - 20
        let cardHeight: CGFloat = 64
        let spacing: CGFloat = 6
        let topY = scrollContainer.containerHeight / 2 - cardHeight / 2 - 10

        // Determine if it's the player's turn
        let draftOrder = gm.league.draftOrder
        let isPlayerTurn = !draftOrder.isEmpty && currentPick < draftOrder.count &&
                           draftOrder[currentPick] == gm.league.playerTeamIndex

        if isPlayerTurn {
            announcementLabel?.text = "Your pick! Select a prospect below."
            announcementLabel?.fontColor = RetroPalette.textGreen
        } else if !draftOrder.isEmpty && currentPick < draftOrder.count {
            let pickingTeam = gm.league.teams[draftOrder[currentPick]]
            announcementLabel?.text = "\(pickingTeam.abbreviation) is on the clock..."
            announcementLabel?.fontColor = RetroPalette.textYellow
        }

        // Get scouting level for the player's team
        let facilityLevel = gm.league.playerTeam.trainingFacilityLevel

        let displayCount = min(16, draftPool.count)
        for i in 0..<displayCount {
            let player = draftPool[i]
            let prospect = DraftProspect.scout(player: player, facilityLevel: facilityLevel)
            let y = topY - CGFloat(i) * (cardHeight + spacing)

            let card = SKNode()
            card.name = "prospect_\(i)"

            let isSelected = selectedProspectIndex == i

            // Background
            let bg = SKSpriteNode(
                texture: PixelArt.panelTexture(width: containerW - 20, height: cardHeight),
                size: CGSize(width: containerW - 20, height: cardHeight)
            )
            bg.zPosition = 0
            if isSelected {
                let highlight = SKSpriteNode(color: RetroPalette.accent.withAlphaComponent(0.2),
                                              size: CGSize(width: containerW - 22, height: cardHeight - 2))
                highlight.zPosition = 0
                card.addChild(highlight)
            }
            card.addChild(bg)

            let leftX = -containerW / 2 + 30

            // Position badge
            let posLabel = RetroFont.label(player.position.shortName, size: RetroFont.bodySize, color: RetroPalette.textYellow)
            posLabel.position = CGPoint(x: leftX, y: 10)
            posLabel.horizontalAlignmentMode = .left
            posLabel.zPosition = 2
            card.addChild(posLabel)

            // Name
            let nameLabel = RetroFont.label(player.fullName, size: RetroFont.bodySize, color: .white)
            nameLabel.position = CGPoint(x: leftX + 40, y: 10)
            nameLabel.horizontalAlignmentMode = .left
            nameLabel.zPosition = 2
            card.addChild(nameLabel)

            // OVR
            let ovrColor: UIColor
            switch player.overall {
            case 85...99: ovrColor = RetroPalette.gold
            case 75...84: ovrColor = RetroPalette.textGreen
            case 65...74: ovrColor = .white
            default: ovrColor = RetroPalette.textGray
            }
            let ovrLabel = RetroFont.label("OVR: \(player.overall)", size: RetroFont.smallSize, color: ovrColor)
            ovrLabel.position = CGPoint(x: leftX + 40, y: -10)
            ovrLabel.horizontalAlignmentMode = .left
            ovrLabel.zPosition = 2
            card.addChild(ovrLabel)

            // Scouting grade
            let gradeColor: UIColor
            switch prospect.scoutingGrade {
            case "A": gradeColor = RetroPalette.gold
            case "B": gradeColor = RetroPalette.textGreen
            case "C": gradeColor = .white
            case "D": gradeColor = RetroPalette.textYellow
            default: gradeColor = RetroPalette.textRed
            }
            let gradeLabel = RetroFont.label("GRADE: \(prospect.scoutingGrade)", size: RetroFont.smallSize, color: gradeColor)
            gradeLabel.position = CGPoint(x: leftX + 180, y: -10)
            gradeLabel.horizontalAlignmentMode = .left
            gradeLabel.zPosition = 2
            card.addChild(gradeLabel)

            // Age
            let ageLabel = RetroFont.label("Age \(player.age)", size: RetroFont.tinySize, color: RetroPalette.textGray)
            ageLabel.position = CGPoint(x: leftX + 280, y: -10)
            ageLabel.horizontalAlignmentMode = .left
            ageLabel.zPosition = 2
            card.addChild(ageLabel)

            // Potential indicator
            let potDiff = player.potential - player.overall
            let potText: String
            let potColor: UIColor
            if potDiff >= 15 {
                potText = "HIGH"
                potColor = RetroPalette.gold
            } else if potDiff >= 8 {
                potText = "MED"
                potColor = RetroPalette.textGreen
            } else {
                potText = "LOW"
                potColor = RetroPalette.textGray
            }
            let potLabel = RetroFont.label("POT: \(potText)", size: RetroFont.tinySize, color: potColor)
            potLabel.position = CGPoint(x: containerW / 2 - 80, y: 10)
            potLabel.horizontalAlignmentMode = .right
            potLabel.zPosition = 2
            card.addChild(potLabel)

            // Stars
            let stars = StarRating(rating: player.starRating)
            stars.position = CGPoint(x: containerW / 2 - 60, y: -10)
            stars.setScale(0.5)
            stars.zPosition = 2
            card.addChild(stars)

            scrollContainer.addScrollContent(card, at: y)
        }

        scrollContainer.setContentHeight(CGFloat(displayCount) * (cardHeight + spacing) + 20)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check if a prospect was tapped
        let draftOrder = gm.league.draftOrder
        let isPlayerTurn = !draftOrder.isEmpty && currentPick < draftOrder.count &&
                           draftOrder[currentPick] == gm.league.playerTeamIndex

        guard isPlayerTurn else {
            // If it's not the player's turn, auto-advance AI picks
            if !isDraftComplete && !draftPool.isEmpty {
                processAIPick()
            }
            return
        }

        // Find tapped prospect in the scroll container
        let nodesAtPoint = nodes(at: location)
        for node in nodesAtPoint {
            if let name = node.name, name.hasPrefix("prospect_"),
               let indexStr = name.components(separatedBy: "_").last,
               let index = Int(indexStr) {
                selectProspect(index)
                return
            }
            // Check parent nodes too
            if let parentName = node.parent?.name, parentName.hasPrefix("prospect_"),
               let indexStr = parentName.components(separatedBy: "_").last,
               let index = Int(indexStr) {
                selectProspect(index)
                return
            }
        }
    }

    private func selectProspect(_ index: Int) {
        guard index < draftPool.count else { return }
        selectedProspectIndex = index

        // Enable draft button
        draftButton?.alpha = 1.0
        draftButton?.isUserInteractionEnabled = true
        announcementLabel?.text = "Selected: \(draftPool[index].fullName) (\(draftPool[index].position.shortName))"
        announcementLabel?.fontColor = RetroPalette.textGreen

        refreshDraftBoard()
    }

    // MARK: - Draft Actions

    private func draftSelectedPlayer() {
        guard let index = selectedProspectIndex, index < draftPool.count else { return }

        var player = draftPool[index]
        player.salary = GameConfig.minSalary
        player.contractYears = 3

        gm.league.playerTeam.addPlayer(player)
        gm.league.addNewsEvent(
            type: .general,
            message: "\(gm.league.playerTeam.abbreviation) drafts \(player.position.shortName) \(player.fullName)"
        )

        draftPool.remove(at: index)
        gm.league.freeAgents = draftPool

        advancePick()
        gm.save()

        // Process AI picks until it's our turn again or round ends
        processRemainingAIPicks()
    }

    private func processAIPick() {
        let draftOrder = gm.league.draftOrder
        guard !isDraftComplete, !draftPool.isEmpty,
              currentPick < draftOrder.count else { return }

        let teamIndex = draftOrder[currentPick]
        guard teamIndex != gm.league.playerTeamIndex else { return }

        let team = gm.league.teams[teamIndex]

        // AI picks best available at position of need
        var pickIndex = 0
        let needForward = team.forwards.count < 9
        let needDefense = team.defensemen.count < 4
        let needGoalie = team.goalies.count < 1

        if needGoalie, let idx = draftPool.firstIndex(where: { $0.position.isGoalie }) {
            pickIndex = idx
        } else if needDefense, let idx = draftPool.firstIndex(where: { $0.position.isDefense }) {
            pickIndex = idx
        } else if needForward, let idx = draftPool.firstIndex(where: { $0.position.isForward }) {
            pickIndex = idx
        }

        var player = draftPool[pickIndex]
        player.salary = GameConfig.minSalary
        player.contractYears = 3

        gm.league.teams[teamIndex].addPlayer(player)

        // Show announcement
        announcementLabel?.text = "\(team.abbreviation) selects \(player.position.shortName) \(player.fullName)"
        announcementLabel?.fontColor = RetroPalette.textYellow

        draftPool.remove(at: pickIndex)
        gm.league.freeAgents = draftPool

        advancePick()
        gm.save()
    }

    private func processRemainingAIPicks() {
        let draftOrder = gm.league.draftOrder
        guard !draftOrder.isEmpty else {
            refreshDraftBoard()
            return
        }

        // Process all AI picks until it's the player's turn again
        var delay: TimeInterval = 0.5
        func scheduleNextPick() {
            guard !self.isDraftComplete, !self.draftPool.isEmpty,
                  self.currentPick < draftOrder.count else {
                self.refreshDraftBoard()
                return
            }

            let teamIndex = draftOrder[self.currentPick]
            if teamIndex == self.gm.league.playerTeamIndex {
                // Player's turn again
                self.refreshDraftBoard()
                return
            }

            self.run(SKAction.wait(forDuration: delay)) { [weak self] in
                self?.processAIPick()
                self?.refreshDraftBoard()
                scheduleNextPick()
            }
            delay = min(delay, 0.3)
        }

        scheduleNextPick()
    }

    private func advancePick() {
        currentPick += 1
        let draftOrder = gm.league.draftOrder
        if currentPick >= draftOrder.count {
            currentPick = 0
            currentRound += 1
        }

        if currentRound > GameConfig.draftRounds || draftPool.isEmpty {
            isDraftComplete = true
            gm.league.seasonPhase = .offseason
            gm.save()
        }
    }
}
