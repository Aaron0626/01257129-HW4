import AVFoundation

extension AVPlayer {
    
    // 按鈕點擊音效
    static let sharedClickPlayer: AVPlayer = {
        guard let url = #bundle.url(forResource: "button_click",withExtension: "mp3") else {
            print("錯誤：在 Resources 資料夾找不到 button_click.mp3")
            return AVPlayer()
        }
        return AVPlayer(url: url)
    }()
    
    // 挖掘泥土音效
    static let sharedDigPlayer: AVPlayer = {
        guard let url = #bundle.url(forResource: "dig", withExtension: "mp3") else {
            print("錯誤：找不到 dig.mp3")
            return AVPlayer()
        }
        return AVPlayer(url: url)
    }()
    
    // 挖掘石頭/礦物音效
    static let sharedDigStonePlayer: AVPlayer = {
        guard let url = #bundle.url(forResource: "dig_stone", withExtension: "mp3") else {
            print("錯誤：找不到 dig_stone.mp3")
            return AVPlayer()
        }
        return AVPlayer(url: url)
    }()
    
    // 發動技能/消除音效 (拔刀聲)
    static let sharedDrawSwordPlayer: AVPlayer = {
        guard let url = #bundle.url(forResource: "drawsword", withExtension: "mp3") else {
            print("錯誤：找不到 drawsword.mp3")
            return AVPlayer()
        }
        return AVPlayer(url: url)
    }()
    
    // 獲得物品/元素音效
    static let sharedGetPlayer: AVPlayer = {
        guard let url = #bundle.url(forResource: "get", withExtension: "mp3") else {
            print("錯誤：找不到 get.mp3")
            return AVPlayer()
        }
        return AVPlayer(url: url)
    }()
    
    // 背景音樂設定
    static var bgQueuePlayer = AVQueuePlayer()
    static var bgPlayerLooper: AVPlayerLooper!
    
    static func setupBgMusic() {
        guard let url = Bundle.main.url(forResource: "backgroundmusic", withExtension: "mp3") else { return }
        let item = AVPlayerItem(url: url)
        bgPlayerLooper = AVPlayerLooper(player: bgQueuePlayer, templateItem: item)
    }
    
    // 從頭開始播放
    func playFromStart() {
        seek(to: .zero) // 倒帶回開始
        play()          // 播放
    }
}
