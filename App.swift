import SwiftUI

@main
struct SonaraApp: App {
    @StateObject private var auth: SpotifyAuth
    @StateObject private var api: SpotifyAPI
    @StateObject private var store = DiscoveryStore()
    @StateObject private var player = PreviewPlayer()

    init() {
        let a = SpotifyAuth()
        _auth = StateObject(wrappedValue: a)
        _api = StateObject(wrappedValue: SpotifyAPI(auth: a))
    }

    var body: some Scene {
        WindowGroup {
            LaunchGate { RootTabView() }
                .environmentObject(auth)
                .environmentObject(api)
                .environmentObject(store)
                .environmentObject(player)
        }
    }
}

struct RootTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.03, green: 0.05, blue: 0.07, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    var body: some View {
        TabView {
            DiscoverView().tabItem { Label("Discover", systemImage: "waveform") }
            PitchView().tabItem { Label("Pitch", systemImage: "chart.line.uptrend.xyaxis") }
            WrappedView().tabItem { Label("Wrapped", systemImage: "sparkles") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Theme.Palette.mint)
        .preferredColorScheme(.dark)
    }
}
