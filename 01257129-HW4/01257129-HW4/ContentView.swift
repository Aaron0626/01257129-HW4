import SwiftUI
import Observation

struct ContentView: View {
    @State private var gameManager = GameManager()
    
    var body: some View {
        NavigationStack {
            HomeView()
        }
        // 將 gameManager 注入環境 (Environment)
        // 這樣 HomeView, GameView, SettingsView 都不用一直傳參數，直接讀取即可
        .environment(gameManager)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
