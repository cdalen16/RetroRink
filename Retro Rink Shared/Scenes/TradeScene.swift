import SpriteKit

// MARK: - Trade Scene
class TradeScene: BaseScene {

    private let gm = GameManager.shared

    enum TradeState {
        case selectTeam
        case selectPlayers
        case review
    }

    private var tradeState: TradeState = .selectTeam
    private var selectedTeamIndex: Int? = nil
    private var myPlayersInTrade: [Player] = []
    private var theirPlayersInTrade: [Player] = []

    private var contentNode: SKNode!
    private var myScrollContainer: ScrollContainer?
    private var theirScrollContainer: ScrollContainer?

    override func didMove(to view: SKView) {
        backgroundColor = RetroPalette.background
        super.didMove(to: view)

        contentNode = SKNode()
        addChild(contentNode)

        setupHeader()
        setupBackButton()
        updateView()
    }

    // MARK: - Setup

    private func setupHeader() {
        let title = RetroFont.label("TRADE CENTER", size: RetroFont.headerSize, color: RetroPalette.gold)
        title.position = CGPoint(x: 40, y: safeTop - 20)
        title.zPosition = ZPos.hud
        addChild(title)
    }

    private func setupBackButton() {
        let back = makeBackButton(target: self) { [weak self] in
            guard let self = self else { return }
            switch self.tradeState {
            case .selectTeam:
                GameManager.transition(from: self.view, toSceneType: HubScene.self)
            case .selectPlayers:
                self.tradeState = .selectTeam
                self.selectedTeamIndex = nil
                self.myPlayersInTrade.removeAll()
                self.theirPlayersInTrade.removeAll()
                self.updateView()
            case .review:
                self.tradeState = .selectPlayers
                self.updateView()
            }
        }
        back.position = CGPoint(x: safeLeft + 52, y: safeTop - 20)
        back.zPosition = ZPos.hud
        addChild(back)
    }

    private func updateView() {
        contentNode.removeAllChildren()
        myScrollContainer = nil
        theirScrollContainer = nil

        switch tradeState {
        case .selectTeam:
            showTeamList()
        case .selectPlayers:
            showPlayerSelection()
        case .review:
            showReview()
        }
    }

    // MARK: - State 1: Select Trade Partner

    private func showTeamList() {
        guard let league = gm.league else { return }

        let subtitle = RetroFont.label("SELECT A TEAM TO TRADE WITH", size: RetroFont.smallSize, color: RetroPalette.textGray)
        subtitle.position = CGPoint(x: 40, y: safeTop - 44)
        contentNode.addChild(subtitle)

        let scroll = ScrollContainer(width: safeWidth - 40, height: safeHeight - 80)
        scroll.position = CGPoint(x: 0, y: -20)
        contentNode.addChild(scroll)

        let rowHeight: CGFloat = 36
        let containerW = safeWidth - 40
        let topY = scroll.containerHeight / 2 - rowHeight / 2 - 5

        var rowIndex = 0
        for (i, team) in league.teams.enumerated() {
            guard i != league.playerTeamIndex else { continue }

            let y = topY - CGFloat(rowIndex) * (rowHeight + 4)

            let row = SKNode()
            row.name = "team_\(i)"

            let bg = SKSpriteNode(
                texture: PixelArt.buttonTexture(width: containerW - 20, height: rowHeight,
                                                 color: UIColor(hex: "222233"),
                                                 borderColor: team.colors.primaryColor),
                size: CGSize(width: containerW - 20, height: rowHeight)
            )
            bg.zPosition = 0
            row.addChild(bg)

            // Team info
            let teamLabel = RetroFont.label(
                "\(team.abbreviation)  \(team.fullName)",
                size: RetroFont.smallSize, color: team.colors.primaryColor
            )
            teamLabel.position = CGPoint(x: -containerW / 2 + 40, y: 2)
            teamLabel.horizontalAlignmentMode = .left
            teamLabel.zPosition = 2
            row.addChild(teamLabel)

            let infoLabel = RetroFont.label(
                "OVR: \(team.teamOverall)  |  \(team.record)  |  \(team.points) pts",
                size: RetroFont.tinySize, color: RetroPalette.textGray
            )
            infoLabel.position = CGPoint(x: containerW / 2 - 40, y: 2)
            infoLabel.horizontalAlignmentMode = .right
            infoLabel.zPosition = 2
            row.addChild(infoLabel)

            // Make tappable via a button overlay
            let selectBtn = RetroButton(text: "SELECT", width: 70, height: 24,
                                         color: UIColor(hex: "333344"), borderColor: UIColor(hex: "555577"),
                                         fontSize: RetroFont.tinySize)
            selectBtn.position = CGPoint(x: containerW / 2 - 60, y: 0)
            selectBtn.zPosition = 2
            selectBtn.action = { [weak self] in
                self?.selectedTeamIndex = i
                self?.tradeState = .selectPlayers
                self?.updateView()
            }
            row.addChild(selectBtn)

            scroll.addScrollContent(row, at: y)
            rowIndex += 1
        }

        scroll.setContentHeight(CGFloat(rowIndex) * (rowHeight + 4) + 20)
    }

    // MARK: - State 2: Player Selection

    private func showPlayerSelection() {
        guard let league = gm.league, let teamIdx = selectedTeamIndex else { return }
        let otherTeam = league.teams[teamIdx]
        let myTeam = league.playerTeam

        let halfW = (safeWidth - 30) / 2
        let listHeight = safeHeight - 140

        // Subtitle
        let subtitle = RetroFont.label(
            "Trading with \(otherTeam.fullName)",
            size: RetroFont.smallSize, color: otherTeam.colors.primaryColor
        )
        subtitle.position = CGPoint(x: 40, y: safeTop - 44)
        contentNode.addChild(subtitle)

        // -- Trade Block Area (center) --
        let tradeBlockBg = SKSpriteNode(color: UIColor(hex: "1A1A3E").withAlphaComponent(0.8),
                                         size: CGSize(width: safeWidth - 20, height: 46))
        tradeBlockBg.position = CGPoint(x: 0, y: safeTop - 78)
        tradeBlockBg.zPosition = 0
        contentNode.addChild(tradeBlockBg)

        let tradeBlockTitle = RetroFont.label("TRADE BLOCK", size: RetroFont.tinySize, color: RetroPalette.gold)
        tradeBlockTitle.position = CGPoint(x: 0, y: safeTop - 68)
        tradeBlockTitle.zPosition = 2
        contentNode.addChild(tradeBlockTitle)

        // Show selected players
        var myTradeText = "Sending: "
        if myPlayersInTrade.isEmpty {
            myTradeText += "(none)"
        } else {
            myTradeText += myPlayersInTrade.map { "\($0.shortName)(\($0.overall))" }.joined(separator: ", ")
        }
        let myTradeLabel = RetroFont.label(myTradeText, size: RetroFont.tinySize, color: RetroPalette.textRed)
        myTradeLabel.position = CGPoint(x: -safeWidth / 4, y: safeTop - 86)
        myTradeLabel.zPosition = 2
        contentNode.addChild(myTradeLabel)

        var theirTradeText = "Receiving: "
        if theirPlayersInTrade.isEmpty {
            theirTradeText += "(none)"
        } else {
            theirTradeText += theirPlayersInTrade.map { "\($0.shortName)(\($0.overall))" }.joined(separator: ", ")
        }
        let theirTradeLabel = RetroFont.label(theirTradeText, size: RetroFont.tinySize, color: RetroPalette.textGreen)
        theirTradeLabel.position = CGPoint(x: safeWidth / 4, y: safeTop - 86)
        theirTradeLabel.zPosition = 2
        contentNode.addChild(theirTradeLabel)

        // -- YOUR PLAYERS (left side) --
        let myTitle = RetroFont.label("YOUR PLAYERS", size: RetroFont.smallSize, color: myTeam.colors.primaryColor)
        myTitle.position = CGPoint(x: -halfW / 2 - 5, y: safeTop - 108)
        contentNode.addChild(myTitle)

        let myScroll = ScrollContainer(width: halfW, height: listHeight)
        myScroll.position = CGPoint(x: -halfW / 2 - 5, y: safeTop - 108 - listHeight / 2 - 14)
        contentNode.addChild(myScroll)
        myScrollContainer = myScroll

        let myPlayers = myTeam.roster.sorted { $0.overall > $1.overall }
        buildPlayerList(players: myPlayers, inScroll: myScroll, containerW: halfW,
                        selectedIDs: Set(myPlayersInTrade.map { $0.id }),
                        isMyTeam: true)

        // -- THEIR PLAYERS (right side) --
        let theirTitle = RetroFont.label("\(otherTeam.abbreviation) PLAYERS", size: RetroFont.smallSize, color: otherTeam.colors.primaryColor)
        theirTitle.position = CGPoint(x: halfW / 2 + 5, y: safeTop - 108)
        contentNode.addChild(theirTitle)

        let theirScroll = ScrollContainer(width: halfW, height: listHeight)
        theirScroll.position = CGPoint(x: halfW / 2 + 5, y: safeTop - 108 - listHeight / 2 - 14)
        contentNode.addChild(theirScroll)
        theirScrollContainer = theirScroll

        let theirPlayers = otherTeam.roster.sorted { $0.overall > $1.overall }
        buildPlayerList(players: theirPlayers, inScroll: theirScroll, containerW: halfW,
                        selectedIDs: Set(theirPlayersInTrade.map { $0.id }),
                        isMyTeam: false)

        // Trade value indicator
        let myTotalOVR = myPlayersInTrade.reduce(0) { $0 + $1.overall }
        let theirTotalOVR = theirPlayersInTrade.reduce(0) { $0 + $1.overall }

        if !myPlayersInTrade.isEmpty || !theirPlayersInTrade.isEmpty {
            let diff = theirTotalOVR - myTotalOVR
            let valueText: String
            let valueColor: UIColor
            if diff >= 3 {
                valueText = "GOOD DEAL"
                valueColor = RetroPalette.textGreen
            } else if diff >= -5 {
                valueText = "FAIR TRADE"
                valueColor = RetroPalette.textYellow
            } else {
                valueText = "BAD DEAL"
                valueColor = RetroPalette.textRed
            }

            let valueLabel = RetroFont.label(valueText, size: RetroFont.smallSize, color: valueColor)
            valueLabel.position = CGPoint(x: 0, y: safeBottom + 54)
            contentNode.addChild(valueLabel)
        }

        // Propose Trade button
        if !myPlayersInTrade.isEmpty && !theirPlayersInTrade.isEmpty {
            let proposeBtn = RetroButton(text: "PROPOSE TRADE", width: 180, height: 40,
                                          color: RetroPalette.midPanel, borderColor: RetroPalette.accent)
            proposeBtn.position = CGPoint(x: 0, y: safeBottom + 25)
            proposeBtn.action = { [weak self] in self?.proposeTrade() }
            contentNode.addChild(proposeBtn)
        }
    }

    private func buildPlayerList(players: [Player], inScroll scroll: ScrollContainer,
                                  containerW: CGFloat, selectedIDs: Set<UUID>, isMyTeam: Bool) {
        let rowHeight: CGFloat = 26
        let topY = scroll.containerHeight / 2 - rowHeight / 2 - 5

        for (i, player) in players.enumerated() {
            let y = topY - CGFloat(i) * (rowHeight + 2)
            let isSelected = selectedIDs.contains(player.id)

            let row = SKNode()

            let bgColor = isSelected ? RetroPalette.accent : UIColor(hex: "222233")
            let borderColor = isSelected ? RetroPalette.gold : UIColor(hex: "444466")

            let btn = RetroButton(
                text: "\(player.position.shortName) \(player.shortName) \(player.overall) \(player.salaryString)",
                width: containerW - 10, height: rowHeight - 2,
                color: bgColor, borderColor: borderColor,
                fontSize: RetroFont.tinySize
            )
            btn.action = { [weak self] in
                self?.togglePlayer(player, isMyTeam: isMyTeam)
            }
            row.addChild(btn)

            scroll.addScrollContent(row, at: y)
        }

        scroll.setContentHeight(CGFloat(players.count) * (rowHeight + 2) + 20)
    }

    private func togglePlayer(_ player: Player, isMyTeam: Bool) {
        if isMyTeam {
            if let index = myPlayersInTrade.firstIndex(where: { $0.id == player.id }) {
                myPlayersInTrade.remove(at: index)
            } else {
                myPlayersInTrade.append(player)
            }
        } else {
            if let index = theirPlayersInTrade.firstIndex(where: { $0.id == player.id }) {
                theirPlayersInTrade.remove(at: index)
            } else {
                theirPlayersInTrade.append(player)
            }
        }
        updateView()
    }

    // MARK: - State 3: Review / Trade Proposal

    private func showReview() {
        guard let league = gm.league, let teamIdx = selectedTeamIndex else { return }
        let otherTeam = league.teams[teamIdx]
        let myTeam = league.playerTeam

        let subtitle = RetroFont.label("TRADE COMPLETE!", size: RetroFont.headerSize, color: RetroPalette.textGreen)
        subtitle.position = CGPoint(x: 0, y: 60)
        contentNode.addChild(subtitle)

        // Sent
        let sentTitle = RetroFont.label("SENT TO \(otherTeam.abbreviation):", size: RetroFont.smallSize, color: RetroPalette.textRed)
        sentTitle.position = CGPoint(x: 0, y: 30)
        contentNode.addChild(sentTitle)

        for (i, player) in myPlayersInTrade.enumerated() {
            let label = RetroFont.label(
                "\(player.position.shortName) \(player.fullName) (\(player.overall)) - \(player.salaryString)",
                size: RetroFont.tinySize, color: RetroPalette.textGray
            )
            label.position = CGPoint(x: 0, y: 12 - CGFloat(i) * 18)
            contentNode.addChild(label)
        }

        let receivedY: CGFloat = 12 - CGFloat(myPlayersInTrade.count) * 18 - 24

        // Received
        let recTitle = RetroFont.label("RECEIVED FROM \(otherTeam.abbreviation):", size: RetroFont.smallSize, color: RetroPalette.textGreen)
        recTitle.position = CGPoint(x: 0, y: receivedY)
        contentNode.addChild(recTitle)

        for (i, player) in theirPlayersInTrade.enumerated() {
            let label = RetroFont.label(
                "\(player.position.shortName) \(player.fullName) (\(player.overall)) - \(player.salaryString)",
                size: RetroFont.tinySize, color: RetroPalette.textGray
            )
            label.position = CGPoint(x: 0, y: receivedY - 18 - CGFloat(i) * 18)
            contentNode.addChild(label)
        }

        // Cap impact
        let mySalaryChange = theirPlayersInTrade.reduce(0) { $0 + $1.salary } - myPlayersInTrade.reduce(0) { $0 + $1.salary }
        let capAfter = myTeam.capSpace - mySalaryChange
        let capText = "Your Cap Space After: $\(capAfter / 1_000_000)M"
        let capLabel = RetroFont.label(capText, size: RetroFont.smallSize,
                                        color: capAfter >= 0 ? RetroPalette.textGreen : RetroPalette.textRed)
        capLabel.position = CGPoint(x: 0, y: receivedY - 18 - CGFloat(theirPlayersInTrade.count) * 18 - 24)
        contentNode.addChild(capLabel)

        // Done button
        let doneBtn = RetroButton(text: "DONE", width: 140, height: 40,
                                   color: RetroPalette.midPanel, borderColor: RetroPalette.accent)
        doneBtn.position = CGPoint(x: 0, y: safeBottom + 32)
        doneBtn.action = { [weak self] in
            GameManager.transition(from: self?.view, toSceneType: HubScene.self)
        }
        contentNode.addChild(doneBtn)
    }

    // MARK: - Trade Logic

    private func proposeTrade() {
        guard let league = gm.league,
              let teamIdx = selectedTeamIndex,
              !myPlayersInTrade.isEmpty,
              !theirPlayersInTrade.isEmpty else { return }

        // Calculate trade value with age weighting
        let sendingValue = myPlayersInTrade.reduce(0.0) { total, player in
            total + Double(player.overall) + Double(player.potential) * 0.3 - Double(player.age) * 0.5
        }
        let receivingValue = theirPlayersInTrade.reduce(0.0) { total, player in
            total + Double(player.overall) + Double(player.potential) * 0.3 - Double(player.age) * 0.5
        }

        let fairnessDiff = sendingValue - receivingValue
        // AI accepts if they're getting similar or better value (within ~5 OVR points)
        let acceptThreshold = Double.random(in: -8...5)

        if fairnessDiff >= acceptThreshold {
            // Trade accepted
            executeTrade(teamIdx: teamIdx)
            tradeState = .review
        } else {
            // Trade rejected
            let toast = RetroToast(message: "\(league.teams[teamIdx].abbreviation) REJECTED the trade!")
            toast.position = CGPoint(x: 0, y: safeBottom + 60)
            toast.zPosition = ZPos.overlay
            addChild(toast)
        }

        updateView()
    }

    private func executeTrade(teamIdx: Int) {
        // Remove players from current teams
        for player in myPlayersInTrade {
            gm.league.playerTeam.removePlayer(id: player.id)
        }
        for player in theirPlayersInTrade {
            gm.league.teams[teamIdx].removePlayer(id: player.id)
        }

        // Add to new teams
        for player in theirPlayersInTrade {
            gm.league.playerTeam.addPlayer(player)
        }
        for player in myPlayersInTrade {
            gm.league.teams[teamIdx].addPlayer(player)
        }

        // News event
        let sentNames = myPlayersInTrade.map { $0.shortName }.joined(separator: ", ")
        let recNames = theirPlayersInTrade.map { $0.shortName }.joined(separator: ", ")
        gm.league.addNewsEvent(
            type: .trade,
            message: "TRADE: \(gm.league.playerTeam.abbreviation) sends \(sentNames) to \(gm.league.teams[teamIdx].abbreviation) for \(recNames)"
        )

        gm.save()
    }
}
