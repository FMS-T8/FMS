//
//  OrdersListView.swift
//  FMS
//
//  Created by Devanshi on 16/03/26.
//


import Foundation
import SwiftUI

public struct OrdersListView: View {
    @State private var viewModel = OrdersViewModel()
    @State private var selectedFilter: OrderFilter = .all
    @State private var showingCreateOrder = false
    @State private var searchText = ""

    enum OrderFilter: String, CaseIterable {
        case all          = "All"
        case highPriority = "High Priority"
        case active       = "Active"
    }

    public init() {}

    // MARK: - Filtered Orders
    private var filteredOrders: [Order] {
        let baseOrders: [Order]
        switch selectedFilter {
        case .all:
            baseOrders = viewModel.allOrders
        case .highPriority:
            baseOrders = viewModel.allOrders.filter {
                $0.priority == "high" || $0.priority == "urgent"
            }
        case .active:
            baseOrders = viewModel.allOrders.filter { $0.isOngoing }
        }
        
        if searchText.isEmpty {
            return baseOrders
        }
        
        let query = searchText.lowercased()
        return baseOrders.filter { order in
            order.customerName.lowercased().contains(query) ||
            (order.orderNumber?.lowercased().contains(query) ?? false) ||
            (order.originName?.lowercased().contains(query) ?? false) ||
            (order.destinationName?.lowercased().contains(query) ?? false)
        }
    }

    private var highPriorityCount: Int {
        viewModel.allOrders.filter {
            $0.priority == "high" || $0.priority == "urgent"
        }.count
    }

    private var activeCount: Int {
        viewModel.allOrders.filter { $0.isOngoing }.count
    }

    public var body: some View {
        ZStack {
            FMSTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.gray)
                    TextField("Search customer, ID or location", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(FMSTheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.15))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // MARK: - Filter Chips
                filterChips
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // MARK: - List
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(FMSTheme.amber)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredOrders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 44))
                            .foregroundColor(FMSTheme.textTertiary)
                        Text("No \(selectedFilter.rawValue.lowercased()) orders")
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredOrders) { order in
                                // FIXED: Passing the viewModel here
                                NavigationLink(destination: OrderDetailView(order: order, viewModel: viewModel)) {
                                    orderCard(for: order)
                                }
                                .buttonStyle(.plain) // Prevents iOS from overriding text colors
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("Orders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCreateOrder = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
            }
        }
        .task {
            await viewModel.fetchOrders()
        }
        .sheet(isPresented: $showingCreateOrder) {
            CreateOrderView(viewModel: viewModel)
        }
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(label: "All", count: viewModel.allOrders.count, filter: .all)
                filterChip(label: "High Priority", count: highPriorityCount, filter: .highPriority, badgeColor: FMSTheme.alertRed)
                filterChip(label: "Active", count: activeCount, filter: .active, badgeColor: .green)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func filterChip(label: String, count: Int, filter: OrderFilter, badgeColor: Color = FMSTheme.amber) -> some View {
        let isSelected = selectedFilter == filter
        Button {
            withAnimation(.snappy) { selectedFilter = filter }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? Color.black : .white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.black.opacity(0.12) : badgeColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundColor(isSelected ? Color.black : FMSTheme.textPrimary)
            .background(isSelected ? FMSTheme.amber : FMSTheme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : FMSTheme.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Refined Order Card
    @ViewBuilder
    private func orderCard(for order: Order) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Colored left border indicator
                Rectangle()
                    .fill(priorityColor(for: order.priority))
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                VStack(alignment: .leading, spacing: 12) {
                    // Header: Order ID and Chevron
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.orderNumber ?? "ORD-\(order.id.prefix(6).uppercased())")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(FMSTheme.textPrimary)
                            
                            Text(order.customerName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(FMSTheme.textSecondary)
                        }
                        
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(FMSTheme.textTertiary)
                    }

                    // Route
                    VStack(alignment: .leading, spacing: 10) {
                        // Pickup
                        HStack(alignment: .top, spacing: 12) {
                            Circle().fill(Color.blue).frame(width: 10, height: 10).padding(.top, 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PICKUP").font(.system(size: 11, weight: .bold)).kerning(0.8).foregroundColor(.blue)
                                Text(shortAddress(order.originName))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(FMSTheme.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        
                        // NEW: Intermediate Stops Indicator
                        if let waypoints = order.waypoints, !waypoints.isEmpty {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(FMSTheme.textTertiary)
                                    .frame(width: 10)
                                
                                Text("\(waypoints.count) stop\(waypoints.count == 1 ? "" : "s")")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(FMSTheme.textSecondary)
                            }
                        }
                        
                        // Delivery
                        HStack(alignment: .top, spacing: 12) {
                            Circle().fill(Color.green).frame(width: 10, height: 10).padding(.top, 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DELIVERY").font(.system(size: 11, weight: .bold)).kerning(0.8).foregroundColor(.green)
                                Text(shortAddress(order.destinationName))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(FMSTheme.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Details Footer
                    HStack(spacing: 16) {
                        Label("\(String(format: "%.0f", order.totalWeightKg)) kg", systemImage: "shippingbox")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FMSTheme.textSecondary)
                        
                        Spacer()
                        
                        // Styled Status Pill
                        if order.isPending {
                            Text("Pending Assignment")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(FMSTheme.alertOrange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(FMSTheme.alertOrange.opacity(0.15))
                                .clipShape(Capsule())
                        } else {
                            Text(order.statusLabel.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.trailing, 14)
            }
        }
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // Shortens a long address by grabbing just the first segment before the comma
    private func shortAddress(_ address: String?) -> String {
        guard let address = address, !address.isEmpty else { return "Unknown Location" }
        let components = address.split(separator: ",")
        return String(components.first ?? "").trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Helpers
    private func priorityColor(for priority: String?) -> Color {
        switch priority?.lowercased() {
        case "urgent": return FMSTheme.alertRed
        case "high":   return .orange
        case "normal": return .green
        case "low":    return FMSTheme.textTertiary
        default:       return FMSTheme.borderLight
        }
    }
}
