//
//  OdoroWidgetBundle.swift
//  OdoroWidgetExtension
//
//  Widget Extension Bundle
//

import WidgetKit
import SwiftUI

@main
struct OdoroWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity for timer
        OdoroLiveActivity()
        
        // Home screen widgets for habits
        HabitWidget()
    }
}
