//
//  OdoroLiveActivity.swift
//  OdoroWidgetExtension
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OdoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OdoroTimerAttributes.self) { context in
            // Lock Screen UI
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(context.state.isStudy ? Color.purple.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: context.state.isStudy ? "brain.head.profile" : "cup.and.saucer.fill")
                        .font(.title2)
                        .foregroundColor(context.state.isStudy ? .purple : .orange)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.isStudy ? "Lock In Time" : "Chill Time")
                        .font(.headline)
                    
                    Text("Session \(context.state.sessionNumber) of \(context.state.totalSessions)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Timer
                if context.state.isPaused {
                    Text("PAUSED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.yellow.opacity(0.2)))
                } else {
                    Text(context.state.endTime, style: .timer)
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(context.state.isStudy ? .purple : .orange)
                }
            }
            .padding(16)
            .background(Color(UIColor.systemBackground))
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isStudy ? "brain.head.profile" : "cup.and.saucer.fill")
                            .font(.title2)
                            .foregroundColor(context.state.isStudy ? .purple : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.isStudy ? "Lock In" : "Chill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Session \(context.state.sessionNumber)/\(context.state.totalSessions)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text("PAUSED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    } else {
                        Text(context.state.endTime, style: .timer)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(context.state.isStudy ? .purple : .orange)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
                
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                Image(systemName: context.state.isStudy ? "brain.head.profile" : "cup.and.saucer.fill")
                    .font(.system(size: 9))
                    .foregroundColor(context.state.isStudy ? .purple : .orange)
            } compactTrailing: {
                Text(context.state.endTime, style: .timer)
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundColor(context.state.isStudy ? .purple : .orange)
                    .contentTransition(.numericText())
            } minimal: {
                Image(systemName: context.state.isStudy ? "brain.head.profile" : "cup.and.saucer.fill")
                    .font(.caption2)
                    .foregroundColor(context.state.isStudy ? .purple : .orange)
            }
        }
    }
}
