import SwiftUI

struct ContentView: View {
    var body: some View {
        ProteinSceneContainer(selectedProteinId: "1CRN") // 기본값으로 1CRN (크로모그라닌) 표시
            .ignoresSafeArea()
            .preferredColorScheme(.light) // 밝은 테마를 기본으로 설정
            .statusBarHidden(false) // 상태바 표시
            .supportedOrientations(.allButUpsideDown)
    }
}

extension View {
    func supportedOrientations(_ orientations: UIInterfaceOrientationMask) -> some View {
        self.onAppear {
            AppDelegate.orientationLock = orientations
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.allButUpsideDown
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("iPhone 15 Pro")
    }
} 