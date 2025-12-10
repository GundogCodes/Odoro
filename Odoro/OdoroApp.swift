//
//  OdoroApp.swift
//  Odoro
//
//  Created by Gunish Sharma on 2025-08-08.
//

import SwiftUI

@main
struct OdoroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate  // Add this line
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
