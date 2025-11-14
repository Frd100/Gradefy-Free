//
//  PARALLAXWidgetLiveActivity.swift
//  PARALLAXWidget
//
//  Created by  on 7/6/25.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct PARALLAXWidgetAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PARALLAXWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PARALLAXWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

private extension PARALLAXWidgetAttributes {
    static var preview: PARALLAXWidgetAttributes {
        PARALLAXWidgetAttributes(name: "World")
    }
}

private extension PARALLAXWidgetAttributes.ContentState {
    static var smiley: PARALLAXWidgetAttributes.ContentState {
        PARALLAXWidgetAttributes.ContentState(emoji: "😀")
    }

    static var starEyes: PARALLAXWidgetAttributes.ContentState {
        PARALLAXWidgetAttributes.ContentState(emoji: "🤩")
    }
}

#Preview("Notification", as: .content, using: PARALLAXWidgetAttributes.preview) {
    PARALLAXWidgetLiveActivity()
} contentStates: {
    PARALLAXWidgetAttributes.ContentState.smiley
    PARALLAXWidgetAttributes.ContentState.starEyes
}
