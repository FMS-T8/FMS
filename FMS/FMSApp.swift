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
            if authViewModel.selectedRole == nil {
                RoleSelectionView()
                    .environment(authViewModel)
            } else {
                MainDashboardView()
                    .environment(authViewModel)
            }
        }
    }
}
