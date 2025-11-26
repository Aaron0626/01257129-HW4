import SwiftUI
import Observation
import AVFoundation

// 用來儲存單筆遊戲紀錄的結構
struct HighScore: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var score: Int
    var duration: Int // 生存時間 (秒)
}

@Observable
class GameManager {
    // 遊戲狀態
    var score: Int = 0              // 當前分數
    var stamina: Int = 70           // 當前體力 (歸零結束)
    var isGameOver: Bool = false    // 是否遊戲結束 (控制彈出視窗)
    var isPlaying: Bool = false     // 是否正在遊玩中 (控制計時器與操作)
    var isPaused: Bool = false      // 是否暫停
    var playTime: Int = 0           // 遊玩時間 (秒)
    
    // 倒數
    var isCountingDown: Bool = false// 是否正在 3-2-1 倒數
    var countdownValue: Int = 3
    
    // 設定
    var isMusicOn: Bool = true      // 背景音樂開關
    var isSoundEffectOn: Bool = true// 音效開關
    
    // 記錄
    var highScores: [HighScore] = []// 排行榜資料陣列
    var gameOverTitle: String = ""  // 遊戲結束時顯示的標題 (根據死因變化)
    var collectedElementIcons: [String] = [] // 目前收集到的元素圖示
    
    // 導航控制
    var showSettings: Bool = false
    var showTutorial: Bool = false
    var showLeaderboard: Bool = false
    
    
    
    init() {
        loadHighScores()    // 讀取歷史紀錄
        setupBGM()
    }
    
    // 音樂控制
    func setupBGM() {
        AVPlayer.setupBgMusic()
        AVPlayer.bgQueuePlayer.volume = 0.5
        if isMusicOn {
            AVPlayer.bgQueuePlayer.play()
        }
    }
    
    // 播放音效
    func playSFX(_ name: String) {
        // 檢查音效開關是否開啟
        guard isSoundEffectOn else { return }
        
        // 根據名稱呼叫對應的 Singleton Player
        switch name {
        case "button_click":
            AVPlayer.sharedClickPlayer.playFromStart()
        case "dig":
            AVPlayer.sharedDigPlayer.playFromStart()
        case "dig_stone":
            AVPlayer.sharedDigStonePlayer.playFromStart()
        case "drawsword":
            AVPlayer.sharedDrawSwordPlayer.playFromStart()
        case "get":
            AVPlayer.sharedGetPlayer.playFromStart()
        default:
            print("未知的音效名稱: \(name)")
        }
    }
    
    // 當使用者在設定頁面切換開關時呼叫此函式
    func updateMusicState() {
        if isMusicOn {
            AVPlayer.bgQueuePlayer.play()
        } else {
            AVPlayer.bgQueuePlayer.pause()
        }
    }
    
    // 清空收集槽 (集滿發動技能後呼叫)
    func clearCollectedElements() {
        collectedElementIcons.removeAll()
    }
    
    // 加入收集到的元素
    func addCollectedElement(icon: String) {
        collectedElementIcons.append(icon)
    }
    
    // 準備開始新遊戲
    func prepareNewGame() {
        // 重置數值
        score = 0
        stamina = 70
        playTime = 0
        isGameOver = false
        isPaused = false
        isPlaying = false
        
        // 開始倒數
        isCountingDown = true
        countdownValue = 3
        
        // 使用 Task.sleep 實作 3-2-1 倒數
        Task {
            for i in stride(from: 3, to: 0, by: -1) {
                await MainActor.run { self.countdownValue = i }
                // 暫停 1 秒 (1_000_000_000 奈秒)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            // 倒數結束，正式開始
            await MainActor.run {
                self.isCountingDown = false
                self.isPlaying = true
                self.startTimer() // 啟動生存計時器
            }
        }
    }
    // 停止遊戲
    func stopGame(reason: String) {
        guard isPlaying else {return}
        isPlaying = false
        isGameOver = true
        timerTask?.cancel() // 停止計時
        // 根據死因設定結束標題
        if reason.contains("體力") {
            gameOverTitle = "應急食品消耗殆盡了...(T^T)"
        } else if reason.contains("荊棘") {
            gameOverTitle = "啊！被荊棘纏住了(⋟﹏⋞)"
        } else {
            gameOverTitle = "旅途暫告終止" // 手動離開時的預設文字
        }
        saveHighScore() // 自動儲存紀錄
    }
    // 重置遊戲 (其實就是重新準備)
    func resetGame() {
        prepareNewGame()
    }
    // 數值操作
    func addScore(_ value: Int) {
        score += value
    }
    // 消耗體力 (如果歸零則結束遊戲)
    func consumeStamina(_ value: Int = 1) {
        stamina -= value
        if stamina <= 0 {
            stamina = 0
            stopGame(reason: "體力耗盡")
        }
    }
    // 恢復體力 (吃到食物)
    func restoreStamina(_ value: Int) {
        stamina += value
    }
    
    // 計算玩家存活了多久
    private var timerTask: Task<Void, Never>?
    
    func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while isPlaying {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                if isPlaying && !isPaused {
                    await MainActor.run {
                        self.playTime += 1
                    }
                }
            }
        }
    }
    

    
    // 儲存排行榜
    func saveHighScore() {
        let newRecord = HighScore(date: Date(), score: score, duration:playTime)
        highScores.append(newRecord)
        // 排序邏輯：分數優先，分數相同則時間越久越好
        highScores.sort {
            if $0.score == $1.score { return $0.duration > $1.duration }
            return $0.score > $1.score
        }
        // 只保留前 10 名
        if highScores.count > 10 { highScores.removeLast() }
        if let data = try? JSONEncoder().encode(highScores) {
            UserDefaults.standard.set(data, forKey: "HighScores")
        }
    }
    // 讀取排行榜
    func loadHighScores() {
        if let data = UserDefaults.standard.data(forKey: "HighScores"),
           let decoded = try? JSONDecoder().decode([HighScore].self, from: data) {
            highScores = decoded
        }
    }
}
