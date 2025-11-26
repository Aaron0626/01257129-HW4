import SwiftUI
import SpriteKit

// 定義首頁標題動畫的三個階段
enum TitleState {
    case entry  // 剛開始 (左上)
    case idle   // 停在中間
    case exit   // 離開 (右上)
}
// 首頁
struct HomeView: View {
    // 讀取環境中的 GameManager
    @Environment(GameManager.self) var gameManager
    @Environment(\.dismiss) var dismiss
    // 控制畫面跳轉與動畫狀態
    @State private var isGamePresented = false
    @State private var isButtonPulsing = false
    @State private var isFloating = false
    
    var body: some View {
        // TimelineView 用於驅動隨時間變化的動畫 (如流光效果)
        TimelineView(.animation) { timeline in
            let timeElapsed = timeline.date.timeIntervalSince1970
            // 每 2 秒切換一次顏色方向
            let shouldReverse = Int(timeElapsed) / 2 % 2 == 0
            VStack(spacing: 40) {
                    ZStack{
                        Image(.home)
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .ignoresSafeArea() // 全螢幕
                            .overlay(Color.black.opacity(0.4))
                        VStack(spacing: 40){
                            // 標題動畫區塊
                            VStack(spacing: 10) {
                                Text("天動萬象")
                                    .font(.system(size: 80, weight: .black, design: .rounded)) // 加大字體
                                Text("Ultimate Miner")
                                    .font(.title2.bold())
                                    .tracking(2) // 字元間距
                            }
                            // 漸層填色(金屬光澤效果)
                            .foregroundStyle(
                                LinearGradient(
                                    // 使用岩元素風格配色 (金/黃/褐)
                                    colors: shouldReverse
                                    ? [.yellow, .white, .brown]
                                    : [.orange, .yellow, .white],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            // 顏色流動動畫
                            .animation(.easeInOut(duration: 1.5), value: shouldReverse)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 2)
                            // Logo 動畫區塊
                            Image(systemName: "cube.transparent.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundStyle(
                                    LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                                )
                            // 懸浮動畫 (上下位移 + 陰影呼吸)
                                .offset(y: isFloating ? -15 : 15)
                                .shadow(color: .orange.opacity(isFloating ? 0.3 : 0.6), radius: isFloating ? 20 : 5, y: isFloating ? 40 : 10)
                                .onAppear {
                                    // 啟動懸浮動畫循環
                                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                        isFloating = true
                                    }
                                    // 啟動按鈕呼吸動畫循環
                                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                        isButtonPulsing = true
                                    }
                                }

                            Button("開始遊戲") {
                                gameManager.playSFX("button_click")
                                isGamePresented = true
                            }
                            .buttonStyle(PrimaryButtonStyle(isPulsing: isButtonPulsing))
                            .onAppear {
                                // 啟動按鈕的呼吸動畫
                                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                    isButtonPulsing = true
                                }
                            }
                            // 功能按鈕列
                            HStack(spacing: 20) {
                                Button("教學", systemImage: "map.fill") {
                                    gameManager.playSFX("button_click")
                                    gameManager.showTutorial = true
                                }
                                Button("排行榜", systemImage: "trophy.fill") {
                                    gameManager.playSFX("button_click")
                                    gameManager.showLeaderboard = true
                                }
                                Button("設定", systemImage: "gearshape.fill") {
                                    gameManager.playSFX("button_click")
                                    gameManager.showSettings = true
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                }
                // 遊戲主體
                .fullScreenCover(isPresented: $isGamePresented) {
                    GameView()
                }
            // 頁面 Sheet
            .sheet(isPresented: Bindable(gameManager).showSettings) { SettingsView() }
            .sheet(isPresented: Bindable(gameManager).showTutorial) { TutorialView() }
            .sheet(isPresented: Bindable(gameManager).showLeaderboard) { LeaderboardView() }
        }
    }
}

// 遊戲畫面
struct GameView: View {
    @Environment(GameManager.self) var gameManager
    @Environment(\.dismiss) var dismiss
    // 建立 Scene
    @State private var scene: GameScene = {
        let scene = GameScene()
        scene.size = CGSize(width: 350, height: 500) // 根據需要調整
        scene.scaleMode = .aspectFit
        return scene
    }()
    var body: some View {
        ZStack {
            Image(.back)
                .resizable()
                .scaledToFill()
                .containerRelativeFrame(.horizontal)
                .ignoresSafeArea()
            
            VStack {
                // HUD
                HStack {
                    // 左側資訊：體力與時間
                    VStack(alignment: .leading) {
                         Text("體力: \(gameManager.stamina)")
                            .foregroundStyle(gameManager.stamina < 10 ? .red : .green)
                         Text("時間: \(gameManager.playTime)s")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    // 中間：元素收集槽
                    HStack(spacing: 5) {
                        ForEach(0..<2) { index in
                            // 如果這個位置有收集到元素，顯示圖片
                            if index < gameManager.collectedElementIcons.count {
                                Image(gameManager.collectedElementIcons[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .transition(.scale) // 出現動畫
                            } else {
                                // 尚未收集到的空槽 (半透明圓圈)
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                    .padding(8)
                    .background(.black.opacity(0.3))
                    .cornerRadius(15)
                    
                    Spacer()
                    // 右側：分數與暫停
                    HStack {
                        Text("\(gameManager.score)")
                            .font(.title2).bold().foregroundStyle(.yellow)
                        
                        Button {
                            gameManager.playSFX("button_click")
                            gameManager.isPaused = true
                        } label: {
                            Image(systemName: "pause.circle.fill")
                                .font(.largeTitle).foregroundStyle(.white)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
                
                // 遊戲視圖
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(width: 350, height: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.2), lineWidth: 2)
                    )
                
                Spacer()
                
                // Controls
                HStack(spacing: 40) {
                    ControlBtn(icon: "arrow.left", action: { scene.move(direction: "Left") })
                    ControlBtn(icon: "arrow.down", action: { scene.move(direction: "Down") })
                    ControlBtn(icon: "arrow.right", action: { scene.move(direction: "Right") })
                }
                .padding(.bottom, 40).opacity(gameManager.isPaused ? 0.3 : 1.0)
                .disabled(gameManager.isPaused)
            }
            
            // 暫停選單
            if gameManager.isPaused {
                Color.black.opacity(0.7).ignoresSafeArea() // 半透明背景
                VStack(spacing: 25) {
                    Text("遊戲暫停")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.white)
                    // 繼續遊戲按鈕
                    Button {
                        gameManager.isPaused = false
                        gameManager.playSFX("button_click")
                        gameManager.showTutorial = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("繼續遊戲")
                        }
                        .frame(width: 200, height: 50)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    // 回主選單按鈕
                    Button {
                        gameManager.stopGame(reason: "玩家退出")
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "house.fill")
                            Text("回主選單")
                        }
                        .frame(width: 200, height: 50)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                }
                .transition(.scale) // 彈出動畫
            }
            
            // Game Over Overlay
            if gameManager.isGameOver {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text(gameManager.gameOverTitle)
                        .font(.title)
                        .bold()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    
                    Text("最終分數: \(gameManager.score)")
                        .font(.title2)
                    
                    Text("用時\(gameManager.playTime)秒")
                        .foregroundStyle(.gray)
                    
                    HStack {
                        Button("回主選單") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        }
                        .buttonStyle(.bordered)
                        Button("再玩一次") {
                            gameManager.resetGame()
                            scene.startNewGame()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .transition(.scale)
            }
            // 3-2-1 倒數顯示
            if gameManager.isCountingDown {
                Color.black.opacity(0.7).ignoresSafeArea() // 半透明背景
                            
                Text("\(gameManager.countdownValue)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange, radius: 10)
                    .transition(.scale.combined(with: .opacity)) // 縮放動畫
                    .id(gameManager.countdownValue) // 強制讓 SwiftUI 識別數字變化以播放動畫
            }
        }
        .onAppear {
            // 注入 Manager 到 Scene
            scene.gameManager = gameManager
            gameManager.prepareNewGame()
            scene.startNewGame()
        }
    }
}

// 子頁面 (設定、教學、排行)
struct SettingsView: View {
    @Environment(GameManager.self) var gameManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("音效") {
                    Toggle("背景音樂", isOn: Bindable(gameManager).isMusicOn)
                    // 當開關改變時，立刻通知 GameManager 更新音樂狀態
                    .onChange(of: gameManager.isMusicOn) {
                        gameManager.updateMusicState()
                    }
                    Toggle("音效", isOn: Bindable(gameManager).isSoundEffectOn)
                }
            }
            .navigationTitle("設定")
            .toolbar { Button("關閉") { dismiss() } }
        }
    }
}

struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 探索礦洞
                    TutorialSection(icon: "sparkles", title: "探索礦洞", color: .indigo) {
                        Text("使用下方的 **左、下、右** 按鍵控制角色")
                        Text("採集越多礦石，分數越高；生存時間越長，排名越高")
                        Text("善用元素可獲得更多分數\n")
                        Text("挖掘方塊與礦物可以獲得分數：")
                        let blocks: [(name: String, img: String, score: Int)] = [
                            ("土塊1", "dirt_1", 1),
                            ("土塊2", "dirt_2", 1),
                            ("土塊3", "dirt_3", 1),
                            ("煤礦", "mineral_coal", 10),
                            ("鐵礦", "mineral_iron", 20),
                            ("水晶", "mineral_crystal", 30)
                        ]
                        HStack(spacing: 10) { // 負間距產生重疊效果
                            ForEach(blocks, id: \.name) { item in
                                VStack(spacing: 5) {
                                    // 方塊圖片
                                    Image(item.img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 45, height: 45)
                                        .shadow(radius: 2)
                                    
                                    // 分數文字
                                    Text("+\(item.score)")
                                        .font(.system(.caption, design: .rounded))
                                        .bold()
                                        .foregroundStyle(.yellow) // 用黃色強調分數
                                }
                            }
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 2)
                        
                        HStack{
                            VStack{
                                HStack{
                                    Image(.dirt1)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 2)
                                    Text("消耗1點體力")
                                }
                                HStack{
                                    Image(.dirt2)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 2)
                                    Text("消耗2點體力")
                                }
                                HStack{
                                    Image(.dirt3)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 2)
                                    Text("消耗3點體力")
                                }
                            }
                            Spacer()
                            VStack{
                                HStack(spacing: -10){
                                    Image(.mineralCoal)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 2)
                                    Image(.mineralIron)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 2)
                                    Image(.mineralCrystal)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 2)
                                }
                                Text("消耗0~3點體力")
                            }
                        }
                    }
                    
                    // 2. 體力機制
                    TutorialSection(icon: "fork.knife", title: "體力管理", color: .orange) {
                        Text("初始體力為70，挖掘方塊會消耗1~3體力")
                        Text("當體力歸零時，冒險結束！")
                        HStack{
                            Image(.food)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .shadow(radius: 2)
                            Text("獲得\"一夢治癒\"，可恢復 10 點體力")
                        }
                    }
                    // 3. 小心頭頂
                    TutorialSection(icon: "exclamationmark.triangle", title: "小心頭頂", color: .red) {
                        Text("地圖會隨著時間不斷**向上捲動**")
                        HStack{
                            Image("plant")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .shadow(radius: 2)
                            Text("動作要快！如果不小心碰到最上方的**紫色荊棘**，冒險就會強制結束")
                        }
                    }
                    
                    // 4. 元素共鳴
                    TutorialSection(icon: "bolt", title: "元素共鳴", color: .yellow) {
                        Text("收集場上的元素球可觸發特殊效果：")
                        HStack(alignment: .top) {
                            Image("Geo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .shadow(radius: 2)
                            VStack(alignment: .leading) {
                                Text("**岩元素 (Geo)**").bold()
                                Text("讓周圍堅硬的礦石變軟，一擊必碎")
                            }
                        }
                        HStack(alignment: .top) {
                            Image("Anemo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .shadow(radius: 2)
                            VStack(alignment: .leading) {
                                Text("**風元素 (Anemo)**").bold()
                                Text("吸取全場所有礦物！")
                            }
                        }
                        HStack(alignment: .top) {
                            Image(systemName: "atom")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.purple)
                                .frame(width: 40, height: 40)
                                .shadow(radius: 2)
                            VStack(alignment: .leading) {
                                Text("**元素爆發 (Combo)**").bold()
                                Text("收集任意 **2 個** 以下元素，將引發大爆炸，直接消除下方三排障礙物！")
                                HStack(spacing: 10) { // 負間距產生重疊效果
                                    Spacer()
                                    // 1. 篩選出所有收集型元素
                                    let collectibles = ElementType.allCases.filter { $0.isCollectible }
                                    
                                    ForEach(collectibles, id: \.self) { type in
                                        Image(type.imageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 30, height: 30)
                                            .shadow(radius: 2)
                                            .zIndex(Double(collectibles.firstIndex(of: type) ?? 0))
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("冒險家指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("明白了") { dismiss() }
                }
            }
        }
    }
}
// 輔助說明區塊樣式
struct TutorialSection<Content: View>: View {
    var icon: String
    var title: String
    var color: Color
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                Text(title)
                    .font(.title3)
                    .bold()
            }
            
            VStack(alignment: .leading, spacing: 5) {
                content
            }
            .font(.body)
            .foregroundStyle(.secondary) // 讓說明文字稍微淡一點
            .padding(.leading, 5) // 稍微縮排
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground)) // 區塊背景
        .cornerRadius(12)
    }
}

struct LeaderboardView: View {
    @Environment(GameManager.self) var gameManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if gameManager.highScores.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "trophy.circle")
                            .font(.system(size: 80))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("暫無紀錄")
                            .font(.title2)
                            .foregroundStyle(.gray)
                        Text("快去創造傳說吧！")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(Array(gameManager.highScores.enumerated()), id: \.element.id) { index, item in
                        HStack {
                            // 排名區塊 (前三名特殊圖示)
                            HStack(spacing: 4) {
                                if index < 3 {
                                    Image(systemName: "crown.fill")
                                        .font(index == 0 ? .title2 : .body)
                                } else {
                                    Text("#")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                
                                Text("\(index + 1)")
                                    .font(index < 3 ? .title3.bold() : .body.monospacedDigit())
                            }
                            .foregroundStyle(getRankColor(index))
                            .frame(width: 60, alignment: .leading)
                            
                            Spacer()
                            
                            // 分數
                            Text("\(item.score)")
                                .font(index == 0 ? .title.bold() : .title3.bold())
                                .foregroundStyle(getRankColor(index))
                                .shadow(color: index == 0 ? .yellow.opacity(0.6) : .clear, radius: 8) // 第一名發光
                            
                            Spacer()
                            // 生存時間
                            VStack(alignment: .trailing) {
                                Text("生存時間")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                                Text("\(item.duration) 秒")
                                    .font(.callout)
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("冒險家名錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }
    // 取得排名顏色
    func getRankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow // 金
        case 1: return Color(white: 0.85) // 銀 (亮灰)
        case 2: return .brown // 銅
        default: return .white // 一般
        }
    }
}

// 圓形漸層控制按鈕
struct ControlBtn: View {
    var icon: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title.bold())
                .frame(width: 75, height: 75)
                .foregroundStyle(.white)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange], // 黃 -> 橘
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 5, x: 0, y: 5)
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.6), lineWidth: 3)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
// 按鈕點擊縮放效果
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
// 主按鈕樣式
struct PrimaryButtonStyle: ButtonStyle {
    var isPulsing: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.bold())
            .foregroundColor(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 40)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: configuration.isPressed ? [.brown, .orange] : [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    // 外發光效果 (Stroke)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.5), lineWidth: 2)
                }
            )
            // 按下時縮小 (0.95)，平常呼吸時放大 (1.05)
            .scaleEffect(configuration.isPressed ? 0.95 : (isPulsing ? 1.05 : 1.0))
            .shadow(color: .orange.opacity(isPulsing ? 0.6 : 0.3), radius: isPulsing ? 15 : 5, x: 0, y: 5)
            .animation(.spring, value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
