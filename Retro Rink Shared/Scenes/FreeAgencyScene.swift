import SpriteKit

// MARK: - Free Agency Scene
class FreeAgencyScene: BaseScene {

    private let gm = GameManager.shared
    private var scrollContainer: ScrollContainer!
    private var capLabel: SKLabelNode!
    private var selectedPlayerIndex: Int? = nil
    private var detailPanel: SKNode?
    private var contractYears: Int = 1

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        setupHeader()
        setupScrollContainer()
        populatePlayerList()

        let back = makeBackButton(target: self) { [weak self] in
            GameManager.transition(from: self?.view, toSceneType: HubScene.self)
        }
        back.position = CGPoint(x: safeLeft + 52, y: safeTop - 20)
        addChild(back)
    }

    // MARK: - Setup

    private func setupHeader() {
        guard let league = gm.league else { return }

        let title = RetroFont.label("FREE AGENCY", size: RetroFont.headerSize, color: RetroPalette.gold)
        title.position = CGPoint(x: 40, y: safeTop - 20)
        addChild(title)

        let capSpace = league.playerTeam.capSpace
        let capColor: UIColor = capSpace > 0 ? RetroPalette.textGreen : RetroPalette.textRed
        let capText = "Cap Space: $\(capSpace / 1_000_000).\(abs(capSpace / 100_000) % 10)M"
        capLabel = RetroFont.label(capText, size: RetroFont.smallSize, color: capColor)
        capLabel.position = CGPoint(x: 40, y: safeTop - 42)
        addChild(capLabel)

        let rosterLabel = RetroFont.label(
            "Roster: \(league.playerTeam.roster.count)/\(GameConfig.maxRosterSize)",
            size: RetroFont.tinySize, color: RetroPalette.textGray
        )
        rosterLabel.position = CGPoint(x: safeRight - 80, y: safeTop - 20)
        addChild(rosterLabel)
    }

    private func setupScrollContainer() {
        let containerHeight = safeHeight - 80
        scrollContainer = ScrollContainer(width: safeWidth - 20, height: containerHeight)
        scrollContainer.position = CGPoint(x: 0, y: -10)
        addChild(scrollContainer)
    }

    // MARK: - Player List

    private func populatePlayerList() {
        scrollContainer.clearContent()

        guard let league = gm.league else { return }
        let freeAgents = league.freeAgents

        if freeAgents.isEmpty {
            let emptyLabel = RetroFont.label("No free agents available", size: RetroFont.bodySize, color: RetroPalette.textGray)
            scrollContainer.addScrollContent(emptyLabel, at: 0)
            return
        }

        let containerW = safeWidth - 20
        let rowHeight: CGFloat = 68
        let spacing: CGFloat = 4
        let topY = scrollContainer.containerHeight / 2 - rowHeight / 2 - 5

        // Column header
        let headerRow = SKNode()
        let headerTexts = ["POS", "NAME", "OVR", "AGE", "SALARY"]
        let headerXs: [CGFloat] = [
            -containerW / 2 + 20,
            -containerW / 2 + 60,
            containerW / 2 - 250,
            containerW / 2 - 190,
            containerW / 2 - 120
        ]
        for (text, x) in zip(headerTexts, headerXs) {
            let label = RetroFont.label(text, size: RetroFont.tinySize, color: RetroPalette.gold)
            label.position = CGPoint(x: x, y: 0)
            label.horizontalAlignmentMode = .left
            headerRow.addChild(label)
        }
        scrollContainer.addScrollContent(headerRow, at: topY + rowHeight / 2 + 10)

        for (i, player) in freeAgents.enumerated() {
            let y = topY - CGFloat(i) * (rowHeight + spacing)

            let card = SKNode()
            card.name = "fa_\(i)"

            let isSelected = selectedPlayerIndex == i

            // Background panel
            let bg = SKSpriteNode(
                texture: PixelArt.panelTexture(width: containerW - 20, height: rowHeight),
                size: CGSize(width: containerW - 20, height: rowHeight)
            )
            bg.zPosition = 0
            card.addChild(bg)

            if isSelected {
                let highlight = SKSpriteNode(color: RetroPalette.accent.withAlphaComponent(0.15),
                                              size: CGSize(width: containerW - 22, height: rowHeight - 2))
                highlight.zPosition = 0
                card.addChild(highlight)
            }

            let leftX = -containerW / 2 + 30

            // Position
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
            let ovrLabel = RetroFont.label("\(player.overall)", size: RetroFont.headerSize, color: ovrColor)
            ovrLabel.position = CGPoint(x: containerW / 2 - 260, y: 10)
            ovrLabel.zPosition = 2
            card.addChild(ovrLabel)

            // Stats line
            let statsText: String
            if player.position.isGoalie {
                statsText = "REF:\(player.reflexes) POS:\(player.positioning) REB:\(player.reboundControl)"
            } else {
                statsText = "SPD:\(player.speed) SHT:\(player.shooting) PAS:\(player.passing) CHK:\(player.checking)"
            }
            let statsLabel = RetroFont.label(statsText, size: RetroFont.tinySize, color: RetroPalette.textGray)
            statsLabel.position = CGPoint(x: leftX + 40, y: -10)
            statsLabel.horizontalAlignmentMode = .left
            statsLabel.zPosition = 2
            card.addChild(statsLabel)

            // Age
            let ageLabel = RetroFont.label("Age \(player.age)", size: RetroFont.smallSize, color: RetroPalette.textGray)
            ageLabel.position = CGPoint(x: containerW / 2 - 200, y: 10)
            ageLabel.zPosition = 2
            card.addChild(ageLabel)

            // Salary
            let salaryLabel = RetroFont.label(player.salaryString, size: RetroFont.smallSize, color: .white)
            salaryLabel.position = CGPoint(x: containerW / 2 - 120, y: 10)
            salaryLabel.zPosition = 2
            card.addChild(salaryLabel)

            // Stars
            let stars = StarRating(rating: player.starRating)
            stars.position = CGPoint(x: containerW / 2 - 120, y: -10)
            stars.setScale(0.5)
            stars.zPosition = 2
            card.addChild(stars)

            // Sign button
            let canAfford = league.playerTeam.capSpace >= player.salary
            let canRoster = league.playerTeam.roster.count < GameConfig.maxRosterSize
            let canSign = canAfford && canRoster

            let signBtn = RetroButton(text: "SIGN", width: 60, height: 28,
                                       color: canSign ? RetroPalette.midPanel : UIColor(hex: "333333"),
                                       borderColor: canSign ? RetroPalette.textGreen : UIColor(hex: "555555"),
                                       fontSize: RetroFont.tinySize)
            signBtn.position = CGPoint(x: containerW / 2 - 45, y: 0)
            signBtn.zPosition = 2
            if canSign {
                signBtn.action = { [weak self] in
                    self?.showSigningDialog(playerIndex: i)
                }
            }
            card.addChild(signBtn)

            scrollContainer.addScrollContent(card, at: y)
        }

        scrollContainer.setContentHeight(CGFloat(freeAgents.count) * (rowHeight + spacing) + 40)
    }

    // MARK: - Signing Dialog

    private func showSigningDialog(playerIndex: Int) {
        guard let league = gm.league, playerIndex < league.freeAgents.count else { return }
        let player = league.freeAgents[playerIndex]

        // Remove previous detail panel if any
        detailPanel?.removeFromParent()
        contractYears = 1

        let panel = SKNode()
        panel.zPosition = ZPos.overlay
        panel.name = "signingDialog"

        // Dim background
        let dimBg = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: CGSize(width: 2000, height: 2000))
        dimBg.zPosition = -1
        panel.addChild(dimBg)

        // Panel background
        let bg = RetroPanel(width: 360, height: 240, title: "SIGN \(player.fullName.uppercased())")
        bg.zPosition = 0
        panel.addChild(bg)

        // Player info
        let infoText = "\(player.position.shortName) | OVR: \(player.overall) | Age \(player.age)"
        let infoLabel = RetroFont.label(infoText, size: RetroFont.bodySize, color: .white)
        infoLabel.position = CGPoint(x: 0, y: 50)
        infoLabel.zPosition = 2
        panel.addChild(infoLabel)

        // Salary
        let salaryLabel = RetroFont.label("Salary: \(player.salaryString) / year", size: RetroFont.smallSize, color: RetroPalette.textGreen)
        salaryLabel.position = CGPoint(x: 0, y: 28)
        salaryLabel.zPosition = 2
        panel.addChild(salaryLabel)

        // Contract length options
        let contractTitle = RetroFont.label("CONTRACT LENGTH:", size: RetroFont.tinySize, color: RetroPalette.textGray)
        contractTitle.position = CGPoint(x: 0, y: 5)
        contractTitle.zPosition = 2
        panel.addChild(contractTitle)

        for years in 1...3 {
            let isSelected = years == contractYears
            let yearBtn = RetroButton(
                text: "\(years) YR",
                width: 70, height: 28,
                color: isSelected ? RetroPalette.midPanel : UIColor(hex: "222233"),
                borderColor: isSelected ? RetroPalette.accent : UIColor(hex: "444466"),
                fontSize: RetroFont.smallSize
            )
            yearBtn.position = CGPoint(x: CGFloat(years - 2) * 85, y: -22)
            yearBtn.zPosition = 2
            yearBtn.action = { [weak self] in
                self?.contractYears = years
                // Refresh dialog
                self?.detailPanel?.removeFromParent()
                self?.showSigningDialog(playerIndex: playerIndex)
            }
            panel.addChild(yearBtn)
        }

        // Total cost
        let totalCost = player.salary * contractYears
        let totalLabel = RetroFont.label(
            "Total: $\(totalCost / 1_000_000).\(abs(totalCost / 100_000) % 10)M over \(contractYears) yr(s)",
            size: RetroFont.tinySize, color: RetroPalette.textGray
        )
        totalLabel.position = CGPoint(x: 0, y: -50)
        totalLabel.zPosition = 2
        panel.addChild(totalLabel)

        // Sign button
        let signBtn = RetroButton(text: "SIGN PLAYER", width: 160, height: 36,
                                   color: RetroPalette.midPanel, borderColor: RetroPalette.textGreen)
        signBtn.position = CGPoint(x: -85, y: -85)
        signBtn.zPosition = 2
        signBtn.action = { [weak self] in
            self?.signPlayer(index: playerIndex)
        }
        panel.addChild(signBtn)

        // Cancel button
        let cancelBtn = RetroButton(text: "CANCEL", width: 100, height: 36,
                                     color: UIColor(hex: "333344"), borderColor: UIColor(hex: "555577"))
        cancelBtn.position = CGPoint(x: 85, y: -85)
        cancelBtn.zPosition = 2
        cancelBtn.action = { [weak self] in
            self?.detailPanel?.removeFromParent()
            self?.detailPanel = nil
        }
        panel.addChild(cancelBtn)

        addChild(panel)
        detailPanel = panel
    }

    // MARK: - Sign Player

    private func signPlayer(index: Int) {
        guard var league = gm.league, index < league.freeAgents.count else { return }

        let player = league.freeAgents[index]

        // Validate cap space
        guard league.playerTeam.capSpace >= player.salary else {
            detailPanel?.removeFromParent()
            detailPanel = nil
            let toast = RetroToast(message: "Not enough cap space!", color: RetroPalette.textRed)
            toast.position = CGPoint(x: 0, y: safeBottom + 40)
            toast.zPosition = ZPos.overlay
            addChild(toast)
            return
        }

        // Validate roster size
        guard league.playerTeam.roster.count < GameConfig.maxRosterSize else {
            detailPanel?.removeFromParent()
            detailPanel = nil
            let toast = RetroToast(message: "Roster is full!", color: RetroPalette.textRed)
            toast.position = CGPoint(x: 0, y: safeBottom + 40)
            toast.zPosition = ZPos.overlay
            addChild(toast)
            return
        }

        var signedPlayer = player
        signedPlayer.contractYears = contractYears

        league.playerTeam.addPlayer(signedPlayer)
        league.freeAgents.remove(at: index)
        league.addNewsEvent(type: .general, message: "SIGNED: \(player.fullName) joins \(league.playerTeam.fullName)")

        gm.league = league
        gm.save()

        // Dismiss dialog and refresh
        detailPanel?.removeFromParent()
        detailPanel = nil
        selectedPlayerIndex = nil

        // Update cap label
        let capSpace = gm.league.playerTeam.capSpace
        let capColor: UIColor = capSpace > 0 ? RetroPalette.textGreen : RetroPalette.textRed
        capLabel.text = "Cap Space: $\(capSpace / 1_000_000).\(abs(capSpace / 100_000) % 10)M"
        capLabel.fontColor = capColor

        // Show toast
        let toast = RetroToast(message: "\(player.fullName) signed!", color: RetroPalette.textGreen)
        toast.position = CGPoint(x: 0, y: safeBottom + 40)
        toast.zPosition = ZPos.overlay
        addChild(toast)

        populatePlayerList()
    }
}
