import SpriteKit

// MARK: - Base Scene
// All game scenes inherit from this. It handles:
// 1. Centering the coordinate system (0,0 = center of screen)
// 2. Matching scene size to the device's actual screen
// 3. Providing safe edge properties for positioning UI (respects notch, Dynamic Island, etc.)

class BaseScene: SKScene {

    // Required for generic factory method
    required override init(size: CGSize) {
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // Safe area edges - computed from actual view safe area insets
    var safeTop: CGFloat { size.height / 2 - safeInsetTop }
    var safeBottom: CGFloat { -size.height / 2 + safeInsetBottom }
    var safeLeft: CGFloat { -size.width / 2 + safeInsetLeft }
    var safeRight: CGFloat { size.width / 2 - safeInsetRight }
    var safeWidth: CGFloat { size.width - safeInsetLeft - safeInsetRight }
    var safeHeight: CGFloat { size.height - safeInsetTop - safeInsetBottom }

    private var safeInsetTop: CGFloat = 12
    private var safeInsetBottom: CGFloat = 12
    private var safeInsetLeft: CGFloat = 12
    private var safeInsetRight: CGFloat = 12

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        let viewSize = view.bounds.size
        let w = max(viewSize.width, viewSize.height)
        let h = min(viewSize.width, viewSize.height)
        self.size = CGSize(width: w, height: h)
        self.scaleMode = .aspectFill

        // Use actual safe area insets (handles notch, Dynamic Island, etc.)
        // In landscape, left/right insets map to the notch side
        let insets = view.safeAreaInsets
        // Landscape: left = max(left,top), right = max(right,bottom) when rotated
        safeInsetLeft = max(insets.left, 12)
        safeInsetRight = max(insets.right, 12)
        safeInsetTop = max(insets.top, 12)
        safeInsetBottom = max(insets.bottom, 12)
    }

    // Factory for creating scenes sized to the view
    static func create<T: BaseScene>(_ type: T.Type, in view: SKView) -> T {
        let viewSize = view.bounds.size
        let w = max(viewSize.width, viewSize.height)
        let h = min(viewSize.width, viewSize.height)
        let scene = T(size: CGSize(width: w, height: h))
        scene.scaleMode = .aspectFill
        return scene
    }
}
