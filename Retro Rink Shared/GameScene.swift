import SpriteKit

class GameScene: SKScene {
    override func didMove(to view: SKView) {
        // Redirect to MainMenuScene
        let menu = BaseScene.create(MainMenuScene.self, in: view)
        view.presentScene(menu)
    }
}
