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
    @State private var bannerManager = BannerManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !authViewModel.isAuthenticated {
                    LoginView()
                } else {
                    MainDashboardView()
                }
            }
            .overlay(alignment: .top) {
                FMSBanner()
            }
            .environment(authViewModel)
            .environment(bannerManager)
        }
    }
}
