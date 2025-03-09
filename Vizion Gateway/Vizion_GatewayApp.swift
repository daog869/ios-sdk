//
//  Vizion_GatewayApp.swift
//  Vizion Gateway
//
//  Created by Andre Browne on 1/13/25.
//

import SwiftUI
import SwiftData

@main
struct Vizion_GatewayApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                Transaction.self,
                User.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
