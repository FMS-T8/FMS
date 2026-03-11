//
//  FMSApp.swift
//  FMS
//
//  Created by Anish on 10/03/26.
//

import SwiftUI

@main
struct FMSApp: App {
    @State private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !authViewModel.isAuthenticated {
                    LoginView()
                } else {
                    MainDashboardView()
                }
            }
            .environment(authViewModel)
        }
    }
}
