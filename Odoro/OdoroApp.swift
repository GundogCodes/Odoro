//
//  OdoroApp.swift
//  Odoro
//
//  Created by Gunish Sharma on 2025-08-08.
//

import SwiftUI
import UIKit

@MainActor
enum AppOrientationPolicy {
    static var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown

    static func update(for page: AppPage, usesDuoLayout: Bool) {
        let orientations: UIInterfaceOrientationMask = page == .tracker && usesDuoLayout
            ? .portrait
            : .allButUpsideDown
        guard supportedOrientations != orientations else { return }
        supportedOrientations = orientations

        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.first(where: \.isKeyWindow)?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
        }
    }
}

final class OdoroAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientationPolicy.supportedOrientations
    }
}

@main
struct OdoroApp: App {
    @UIApplicationDelegateAdaptor(OdoroAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
