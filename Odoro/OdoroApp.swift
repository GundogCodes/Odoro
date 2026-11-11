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
    private static var refreshGeneration = 0

    static func update(for page: AppPage, usesFoldedDuoLayout: Bool) {
        if usesFoldedDuoLayout {
            enterFoldedMode(for: page)
        } else {
            enterInnerDisplayMode()
        }
    }

    static func enterFoldedMode(for page: AppPage) {
        let orientations: UIInterfaceOrientationMask = page == .tracker ? .portrait : .allButUpsideDown
        supportedOrientations = orientations
        refreshGeneration += 1
        refreshSupportedOrientations()

        // Only the outer display honors interface-orientation requests. The
        // Tracker is intentionally portrait-only there; Picker and Timer stay
        // free to follow the system.
        if page == .tracker {
            requestOuterDisplayPortrait()
        }
    }

    static func enterInnerDisplayMode() {
        supportedOrientations = .allButUpsideDown
        refreshGeneration += 1
        let generation = refreshGeneration
        refreshSupportedOrientations()

        // The Duo inner display does not honor interface-orientation requests;
        // it resizes the scene. Refresh only the supported mask while UIKit
        // finishes moving the scene, then let SwiftUI react to its new bounds.
        for delay in [0.15, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard generation == refreshGeneration else { return }
                refreshSupportedOrientations()
            }
        }
    }

    private static func refreshSupportedOrientations() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.first(where: \.isKeyWindow)?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private static func requestOuterDisplayPortrait() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
        }
    }
}

final class OdoroAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

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
