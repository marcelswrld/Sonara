import SwiftUI

@main
struct SonaraApp: App {
    @StateObject private var auth: SpotifyAuth
    @StateObject private var api: SpotifyAPI
    @StateObject private var store = DiscoveryStore()
    @StateObject private var player = PreviewPlayer()
    @StateObject private var mood: MoodEngine

    init() {
        let a = SpotifyAuth()
        let apiInstance = SpotifyAPI(auth: a)
        _auth = StateObject(wrappedValue: a)
        _api = StateObject(wrappedValue: apiInstance)
        _mood = StateObject(wrappedValue: MoodEngine(api: apiInstance))
    }

    var body: some Scene {
        WindowGroup {
            LaunchGate { RootTabView() }
                .environmentObject(auth)
                .environmentObject(api)
                .environmentObject(store)
                .environmentObject(player)
                .environmentObject(mood)
        }
    }
}

struct RootTabView: View {
    @State private var selectedTab = 0
    @State private var routeToPitchArtist: String?

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.027, green: 0.047, blue: 0.075, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TrendsView(routeToPitchArtist: $routeToPitchArtist, selectedTab: $selectedTab)
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(0)
            VibeView()
                .tabItem { Label("Vibe", systemImage: "waveform.path.ecg") }
                .tag(1)
            PitchView(incomingArtist: $routeToPitchArtist)
                .tabItem { Label("Pitch", systemImage: "dollarsign.circle") }
                .tag(2)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(Theme.Palette.mint)
        .preferredColorScheme(.dark)
    }
}
