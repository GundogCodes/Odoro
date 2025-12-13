//
//  OdoroTimerAttributes.swift
//  Odoro
//
//  Shared between main app and widget extension
//

import ActivityKit
import Foundation

// MARK: - Activity Attributes (Shared)
struct OdoroTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startTime: Date
        var endTime: Date
        var isStudy: Bool
        var isPaused: Bool
        var sessionNumber: Int
        var totalSessions: Int
    }
    
    // Fixed attributes that don't change during the activity
    var timerName: String
}
