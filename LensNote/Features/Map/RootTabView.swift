import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CameraView()
            }
            .tabItem {
                Label("Camera", systemImage: "camera")
            }
            
            NavigationStack {
                GalleryView()
            }
            .tabItem {
                Label("Gallery", systemImage: "photo.on.rectangle")
            }
            
            NavigationStack {
                MapView(viewModel: MapViewModel())
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
        }
    }
}

#Preview {
    RootTabView()
}
