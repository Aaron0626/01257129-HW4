import SpriteKit
import GameplayKit

// 礦物類型
// 定義煤、鐵、水晶，以及它們的分數與對應圖片
enum MineralType {
    case coal, iron, crystal
    // 挖掘獲得的分數
    var score: Int {
        switch self {
        case .coal: return 10
        case .iron: return 20
        case .crystal: return 30
        }
    }
    var imageName: String {
        switch self {
        case .coal: return "mineral_coal"
        case .iron: return "mineral_iron"
        case .crystal: return "mineral_crystal"
        }
    }
}
// 元素類型
enum ElementType: CaseIterable {
    // 火、水、風、雷、草、冰、岩
    case anemo, geo
    case pyro, hydro, electro, dendro, cryo
    var imageName: String {
        switch self {
        case .geo: return "Geo"
        case .anemo: return "Anemo"
        case .pyro: return "Pyro"
        case .hydro: return "Hydro"
        case .electro: return "Electro"
        case .dendro: return "Dendro"
        case .cryo: return "Cryo"
        }
    }
    
    // 判斷是否為需要收集的「其他」元素(非岩、非風)
    var isCollectible: Bool {
        return self != .geo && self != .anemo
    }
}
// 格子內容 定義地圖上每一個格子可能存在的狀態
enum TileContent {
    case empty                      // 空氣 (已挖掘)
    case dirt(hp: Int)              // 泥土 (有耐久度)
    case mineral(type: MineralType, hp: Int)    // 礦物 (有類型與耐久度)
    case food                       // 食物 (回復體力)
    case element(type: ElementType) // 元素 (技能/收集)
    case thorns                     // 荊棘 (碰到即死)
}
// 遊戲場景
class GameScene: SKScene {
    
    // 連結 SwiftUI 的狀態管理器 (用於更新分數、體力等 UI)
    var gameManager: GameManager?
    // 地圖參數設定
    let rows = 12
    let cols = 8
    let tileSize: CGFloat = 40.0
    // 遊戲資料與節點
    var grid: [[TileContent]] = []
    var tileNodes: [[SKSpriteNode?]] = []
    // 玩家狀態
    var playerPos: (row: Int, col: Int) = (3, 4)    // 玩家在網格中的座標
    var playerNode: SKSpriteNode!
    let playerTextureIdle = SKTexture(imageNamed: "pimon 1")    // 移動圖片
    let playerTextureDig = SKTexture(imageNamed: "pimon 2")     // 挖掘圖片
    // 遊戲數值
    var scoreMultiplier = 1
    var collectedOtherElements = 0
    // 自動捲動參數
    var autoScrollSpeed: TimeInterval = 2.0 // 每幾秒捲動一次
    var lastScrollTime: TimeInterval = 0// 上次捲動的時間點
    
    var mapStartY: CGFloat {
        return frame.maxY - tileSize / 2
    }
    
    let gameLayer = SKNode()
    
    override func didMove(to view: SKView) {
        // 設定背景為半透明黑，讓底圖透出來
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        addChild(gameLayer)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // 檢查遊戲狀態：必須是「進行中」、「未暫停」、「非倒數中」才執行
        guard let gm = gameManager, gm.isPlaying, !gm.isPaused, !gm.isCountingDown else {
            lastScrollTime = currentTime // 暫停時重置計時基準
            return
        }
            
        // 自動捲動邏輯
        if lastScrollTime == 0 { lastScrollTime = currentTime }
        // 如果時間差超過設定速度，執行捲動
        if currentTime - lastScrollTime > autoScrollSpeed {
            scrollMapUp() // 觸發地圖上捲
            lastScrollTime = currentTime
                
            // 難度曲線：隨著時間，捲動速度變快
            if autoScrollSpeed > 0.5 { autoScrollSpeed -= 0.01 }
        }
    }
    // 開始新遊戲
    func startNewGame() {
        gameLayer.removeAllChildren()
        grid = []
        tileNodes = []
        scoreMultiplier = 1
        collectedOtherElements = 0
        autoScrollSpeed = 2.0   // 重置速度
        playerPos = (3, 4)      // 重置玩家位置
        initGrid()              // 生成初始地圖
        spawnPlayer()           // 生成玩家
    }
    // 隨機生成一整排的資料
    func generateRowData(yPos: CGFloat) -> ([TileContent], [SKSpriteNode?]) {
        var rowData: [TileContent] = []
        var rowNodes: [SKSpriteNode?] = []
        
        let startX = frame.midX - (CGFloat(cols) * tileSize) / 2 + tileSize / 2
        
        // 隨機決定這一排要有幾個東西 (3 ~ 8 個)
        let itemsCount = Int.random(in: 3...8)
        let filledIndices = Array(0..<cols).shuffled().prefix(itemsCount)
        
        for c in 0..<cols {
            let pos = CGPoint(x: startX + CGFloat(c) * tileSize, y: yPos)
            var content: TileContent = .empty
            var node: SKSpriteNode? = nil
            // 如果這個位置被選中，隨機生成物品
            if filledIndices.contains(c) {
                // 機率配置：
                let seed = Int.random(in: 1...100)
                if seed <= 75 { // 75% 泥土
                    let hp = Int.random(in: 1...3)
                    content = .dirt(hp: hp)
                    node = createTileNode(imageName: "dirt_\(hp)", pos: pos)
                } else if seed <= 90 { // 15% 礦石
                    let mType: MineralType = [.coal, .iron, .crystal].randomElement()!
                    let hp = Int.random(in: 0...3)
                    content = .mineral(type: mType, hp: hp)
                    // 礦石顯示耐久度數字
                    node = createTileNode(imageName: mType.imageName, pos: pos, text: "\(hp)")
                } else if seed <= 95 {  // 5% 食物
                    content = .food
                    node = createTileNode(imageName: "food", pos: pos, icon: "🍎")
                } else { // 5% 元素
                    let eType = ElementType.allCases.randomElement()!
                    content = .element(type: eType)
                    node = createTileNode(imageName: eType.imageName, pos: pos)
                }
            } else {
                content = .empty
            }
            if let n = node { gameLayer.addChild(n) }
            rowData.append(content)
            rowNodes.append(node)
        }
        
        return (rowData, rowNodes)
    }
    
    // 初始化初始畫面
    func initGrid() {
        for r in 0..<rows {
            let posY = mapStartY - CGFloat(r) * tileSize
            var rowData: [TileContent] = []
            var rowNodes: [SKSpriteNode?] = []
                    
            // 計算 X 軸起始點 (給手動生成的排使用)
            let startX = frame.midX - (CGFloat(cols) * tileSize) / 2 + tileSize / 2
            
            if r == 0 {
                // --- 第 0 排：荊棘(死亡邊界) ---
                for c in 0..<cols {
                    let pos = CGPoint(x: startX + CGFloat(c) * tileSize, y: posY)
                    let node = createTileNode(imageName: "plant", pos: pos) // 荊棘顏色
                    gameLayer.addChild(node)
                    rowData.append(.thorns)
                    rowNodes.append(node)
                }
            } else if r >= 1 && r <= 3 {
                // --- 第 1~3 排：完全淨空 (安全區) ---
                for _ in 0..<cols {
                    rowData.append(.empty)
                    rowNodes.append(nil)
                }
            } else if r == 4 {
                // --- 第 4 排：全都是 1 體力的方塊 ---
                for c in 0..<cols {
                    let pos = CGPoint(x: startX + CGFloat(c) * tileSize, y: posY)
                    // 強制生成 dirt, hp: 1
                    let node = createTileNode(imageName: "dirt_1", pos: pos)
                    gameLayer.addChild(node)
                    rowData.append(.dirt(hp: 1))
                    rowNodes.append(node)
                }
                
            } else {
                // --- 第 5 排以後：隨機生成 ---
                let (data, nodes) = generateRowData(yPos: posY)
                rowData = data
                rowNodes = nodes
            }
            grid.append(rowData)
            tileNodes.append(rowNodes)
        }
    }
    // 生成新的一排並從底部滑入
    func generateNewRow(at r: Int) {
        let posY = mapStartY - CGFloat(r) * tileSize
        let (data, nodes) = generateRowData(yPos: posY)
        // 加入滑入動畫
        for (_, node) in nodes.enumerated() {
            if let n = node {
                n.position = CGPoint(x: n.position.x, y: n.position.y - tileSize)
                n.run(SKAction.moveBy(x: 0, y: tileSize, duration: 0.2))
            }
        }
        grid[r] = data
        tileNodes[r] = nodes
    }
    // 建立方塊節點
    func createTileNode(imageName: String, pos: CGPoint, text: String? = nil, icon: String? = nil) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: imageName)
        node.size = CGSize(width: tileSize - 2, height: tileSize - 2) // 留一點縫隙
        node.position = pos
        if let t = text {
            let lbl = SKLabelNode(text: t)
            lbl.fontSize = 16
            lbl.fontName = "Arial-BoldMT"
            lbl.verticalAlignmentMode = .center
            lbl.fontColor = .white // 確保文字在圖片上清楚
            lbl.zPosition = 10 // 確保文字在圖片上層
            lbl.name = "label"
            node.addChild(lbl)
        }
        return node
    }
    // 生成玩家角色
    func spawnPlayer() {
        playerNode = SKSpriteNode(texture: playerTextureIdle)
        playerNode.size = CGSize(width: tileSize/1.2, height: tileSize/1.2) // 調整大小
        updatePlayerPos()
        gameLayer.addChild(playerNode)
    }
    // 音效播放輔助函式
    func playSound(_ fileName: String) {
        // 直接呼叫 GameManager，讓他去處理 AVPlayer 的播放與靜音判斷
        gameManager?.playSFX(fileName)
    }
    // 接收外部按鈕輸入 (左/右/下)
    func move(direction: String) {
        guard let gm = gameManager, gm.isPlaying, !gm.isPaused, !gm.isCountingDown else { return }
        var dR = 0, dC = 0
        // 判斷方向與翻轉圖片
        if direction == "Left" {
            dC = -1
            // 面向左：xScale = 1 (假設圖片原圖是朝左)
            playerNode.xScale = 1.0
        } else if direction == "Right" {
            dC = 1
            // 面向右：xScale = -1 (水平翻轉)
            playerNode.xScale = -1.0
        } else if direction == "Down" {
            dR = 1
        }
        // 計算目標座標
        let nextR = playerPos.row + dR
        let nextC = playerPos.col + dC
        // 邊界檢查
        if nextC < 0 || nextC >= cols { return }
        if nextR >= rows { return }
        
        handleInteraction(r: nextR, c: nextC, isMovingDown: dR > 0, isGravity: false)
    }
    // 重力檢查：如果腳下是空的，自動掉落
    func checkGravity() {
        let belowR = playerPos.row + 1
        if belowR < rows {
            if case .empty = grid[belowR][playerPos.col] {
                let wait = SKAction.wait(forDuration: 0.05)
                let fall = SKAction.run {
                    // 執行掉落 (isGravity: true 代表不扣體力)
                    self.handleInteraction(r: belowR, c: self.playerPos.col, isMovingDown: true, isGravity: true)
                }
                self.run(SKAction.sequence([wait, fall]))
            }
        }
    }
    // 處理移動與碰撞邏輯
    func handleInteraction(r: Int, c: Int, isMovingDown: Bool, isGravity: Bool) {
        guard let gm = gameManager else { return }
        let content = grid[r][c]
        var willMoveIn = false
        // 重置玩家圖片為閒置狀態 (除非正在自動掉落)
        if !isGravity {
            playerNode.texture = playerTextureIdle
        }
        switch content {
        case .thorns:
            gm.stopGame(reason: "碰到荊棘")
            return
            
        case .empty:
            willMoveIn = true
            
        case .dirt(var hp), .mineral(_, var hp):
            if isGravity { return }    // 重力無法穿透障礙物
            
            if case .dirt = content {
                playSound("dig")       // 挖土聲
            } else {
                playSound("dig_stone") // 挖礦聲
            }
            // 切換挖掘圖片與動畫
            playerNode.texture = playerTextureDig
            let restoreAction = SKAction.run { [weak self] in
                self?.playerNode.texture = self?.playerTextureIdle
            }
            playerNode.run(SKAction.sequence([SKAction.wait(forDuration: 0.2), restoreAction]))
            // 扣除耐久與體力
            hp -= 1
            gm.consumeStamina()
            
            if hp <= 0 {
                breakBlock(r: r, c: c) // 破壞方塊
                willMoveIn = true
            } else {
                updateTileHP(r: r, c: c, hp: hp) // 更新耐久度顯示
            }
            
        case .food:
            playSound("get")
            gm.restoreStamina(10) // 吃到食物恢復10點體力
            removeTile(r: r, c: c)
            willMoveIn = true
            
        case .element(let type):
            playSound("get")
            activateElement(type: type, r: r, c: c) // 發動元素效果
            removeTile(r: r, c: c)
            willMoveIn = true
        }
        if willMoveIn {
            playerPos = (r, c)
            // 如果往下挖得太深，觸發捲動以保持視野
            if isMovingDown && playerPos.row > 6 { scrollMapUp() }
            updatePlayerPos()
            checkGravity()// 移動後檢查是否懸空
        }
    }
    // 地圖向上捲動邏輯
    func scrollMapUp() {
        // 移除最上面一排
        for c in 0..<cols { tileNodes[1][c]?.removeFromParent() }
        // 所有方塊往上移
        for r in 1..<(rows - 1) {
            grid[r] = grid[r+1]
            tileNodes[r] = tileNodes[r+1]
            for node in tileNodes[r] {
                node?.run(SKAction.moveBy(x: 0, y: tileSize, duration: 0.2))
            }
        }
        // 生成新底層
        generateNewRow(at: rows - 1)
        // 修正玩家座標 (被推上去)
        playerPos.row -= 1
        updatePlayerPos()
        // 死亡判定：被推到第 0 排
        if playerPos.row <= 0 {
            playerNode.run(SKAction.scale(to: 0, duration: 0.2))
            gameManager?.stopGame(reason: "被荊棘刺死")
        }
    }
    // 破壞方塊並加分
    func breakBlock(r: Int, c: Int) {
        let content = grid[r][c]
        var points = 1
        if case .mineral(let type, _) = content { points += type.score }
        gameManager?.addScore(points * scoreMultiplier)
        removeTile(r: r, c: c)
    }
    // 移除方塊節點
    func removeTile(r: Int, c: Int) {
        tileNodes[r][c]?.removeFromParent()
        tileNodes[r][c] = nil
        grid[r][c] = .empty
    }
    // 更新方塊耐久度
    func updateTileHP(r: Int, c: Int, hp: Int) {
        let currentContent = grid[r][c]
        // 更新資料
        if case .dirt = currentContent {
            grid[r][c] = .dirt(hp: hp)
        } else if case .mineral(let t, _) = currentContent {
            grid[r][c] = .mineral(type: t, hp: hp)
        }
        
        // 3. 更新視覺 (圖片與動畫)
        if let node = tileNodes[r][c] {
            // 方塊換圖
            if case .dirt = currentContent {
                // 例如：剩 2 滴血 -> 換成 "dirt_2"
                node.texture = SKTexture(imageNamed: "dirt_\(hp)")
            }
            // 礦物更新文字
            if let label = node.childNode(withName: "label") as? SKLabelNode {
                label.text = "\(hp)"
                if let shadow = label.children.first as? SKLabelNode {
                    shadow.text = "\(hp)"
                }
            }
            // 受擊動畫
            let scale = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.05),
                SKAction.scale(to: 1.0, duration: 0.05)
            ])
            node.run(scale)
        }
    }
    // 更新玩家畫面位置
    func updatePlayerPos() {
        let startX = frame.midX - (CGFloat(cols) * tileSize) / 2 + tileSize / 2
        let target = CGPoint(x: startX + CGFloat(playerPos.col) * tileSize, y: mapStartY - CGFloat(playerPos.row) * tileSize)
        playerNode.run(SKAction.move(to: target, duration: 0.1))
    }
    // 元素技能系統
    func activateElement(type: ElementType, r: Int, c: Int) {
        // 如果是收集型元素 (非岩、非風)
        if type.isCollectible {
            // 加入 UI 顯示
            gameManager?.addCollectedElement(icon: type.imageName)
            // 檢查是否集滿 2 個
            if let count = gameManager?.collectedElementIcons.count, count >= 2 {
                // [發動技能] 消除下方 3 排
                eliminateRowsBelowPlayer(count: 3)
                // 清空收集槽
                gameManager?.clearCollectedElements()
            }
            return
        }
        // 功能型元素
        switch type {
        case .geo:
            // 岩：周圍變軟 (HP -> 1)
            for i in -1...1 {
                for j in -1...1 {
                    let tr = r+i, tc = c+j
                    if tr >= 0 && tr < rows && tc >= 0 && tc < cols {
                        if case .dirt = grid[tr][tc] { updateTileHP(r: tr, c: tc, hp: 1) }
                        if case .mineral(_, _) = grid[tr][tc] { updateTileHP(r: tr, c: tc, hp: 1) }
                    }
                }
            }
        case .anemo:
            // 風：全圖吸取
            absorbAllMinerals()
        default: break
        }
    }
    
    // 技能：消除下方指定排數
    func eliminateRowsBelowPlayer(count: Int) {
        let startR = playerPos.row + 1
        let endR = min(startR + count, rows)
        guard startR < endR else { return } // 下方沒東西就不做
        
        playSound("drawsword")// 技能音效
        
        for r in startR..<endR {
            for c in 0..<cols {
                // 只消除方塊和礦物，保留空地(避免重複計算)
                let content = grid[r][c]
                switch content {
                case .dirt, .mineral:
                    breakBlock(r: r, c: c)
                default:
                    continue
                }
            }
        }
        checkGravity()// 消除完可能會造成懸空，觸發重力檢查
    }
    // 技能：風元素吸取全圖礦物
    func absorbAllMinerals() {
        playSound("drawsword") // 技能音效
        for r in 0..<rows {
            for c in 0..<cols {
                if case .mineral = grid[r][c] {
                    breakBlock(r: r, c: c)
                }
            }
        }
    }
}
