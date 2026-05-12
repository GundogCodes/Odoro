//
//  OdoroApp.swift
//  Odoro
//
//  Created by Gunish Sharma on 2025-08-08.
//

import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct OdoroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate  // Add this line

    init() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
