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
            PitchView(incomingArtist: $routeToPitchArtist)
                .tabItem { Label("Pitch", systemImage: "dollarsign.circle") }
                .tag(1)
            WrappedView()
                .tabItem { Label("Wrapped", systemImage: "sparkles") }
                .tag(2)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(Theme.Palette.mint)
        .preferredColorScheme(.dark)
    }
}
