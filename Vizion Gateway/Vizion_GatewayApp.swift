//
//  Vizion_GatewayApp.swift
//  Vizion Gateway
//
//  Created by Andre Browne on 1/13/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions

@main
struct Vizion_GatewayApp: App {
    let modelContainer: ModelContainer
    @State private var isInitialized = false
    
    init() {
        // Configure Firebase first - only if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("Firebase configured in app initialization")
        } else {
            print("Firebase already configured, skipping")
        }
        
        // Set up emulator connection for local testing if needed
        #if DEBUG
        // Uncomment these lines to use Firebase Local Emulator Suite during development
        // Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        // Functions.functions().useEmulator(withHost: "localhost", port: 5001)
        // let settings = Firestore.firestore().settings
        // settings.host = "localhost:8080"
        // settings.isSSLEnabled = false
        // Firestore.firestore().settings = settings
        // Storage.storage().useEmulator(withHost: "localhost", port: 9199)
        #endif
        
        // Then setup SwiftData with migration strategy
        do {
            // Define the schema
            let schema = Schema([
                User.self,
                Transaction.self
            ])
            
            // Handle schema migration with a destructive strategy due to type conflicts
            // First try to remove any existing stores
            let containerURL = URL.applicationSupportDirectory.appending(path: "default.sqlite")
            try? FileManager.default.removeItem(at: containerURL)
            
            // Configure with fresh database
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("Successfully created new model container")
        } catch {
            print("Error initializing ModelContainer: \(error)")
            
            // Fallback to in-memory only if persistent store fails
            do {
                let schema = Schema([
                    User.self,
                    Transaction.self
                ])
                let backupConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: [backupConfig])
                print("Fallback to in-memory container successful")
            } catch {
                fatalError("Fatal error: Could not initialize any ModelContainer: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !isInitialized {
                        setupFirebaseManager()
                        isInitialized = true
                    }
                }
        }
        .modelContainer(modelContainer)
    }
    
    private func setupFirebaseManager() {
        // Get the model context from the container
        let context = modelContainer.mainContext
        
        // Configure Firebase manager with the context
        FirebaseManager.shared.configure(with: context)
        
        // Update environment from UserDefaults if needed
        if let savedEnv = UserDefaults.standard.string(forKey: "environment"),
           let env = AppEnvironment(rawValue: savedEnv) {
            FirebaseManager.shared.setEnvironment(env)
        }
        
        // Set default environment if none exists
        if UserDefaults.standard.string(forKey: "environment") == nil {
            UserDefaults.standard.set(AppEnvironment.sandbox.rawValue, forKey: "environment")
        }
        
        print("Vizion Gateway initialized with Firebase")
    }
}
