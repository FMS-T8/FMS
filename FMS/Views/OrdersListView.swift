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
                                orderCard(for: order)
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
                // All
                filterChip(
                    label: "All",
                    count: viewModel.allOrders.count,
                    filter: .all
                )
                // High Priority
                filterChip(
                    label: "High Priority",
                    count: highPriorityCount,
                    filter: .highPriority,
                    badgeColor: FMSTheme.alertRed
                )
                // Active
                filterChip(
                    label: "Active",
                    count: activeCount,
                    filter: .active,
                    badgeColor: .green
                )
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func filterChip(
        label: String,
        count: Int,
        filter: OrderFilter,
        badgeColor: Color = FMSTheme.amber
    ) -> some View {
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : badgeColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundColor(isSelected ? .white : FMSTheme.textPrimary)
            .background(
                isSelected
                    ? (filter == .all ? FMSTheme.amber : badgeColor)
                    : FMSTheme.cardBackground
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : FMSTheme.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Order Card
    @ViewBuilder
    private func orderCard(for order: Order) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Colored left border indicator
                Rectangle()
                    .fill(priorityColor(for: order.priority))
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                VStack(alignment: .leading, spacing: 10) {
                    // Customer Name
                    Text(order.customerName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FMSTheme.textPrimary)

                    // Route
                    VStack(alignment: .leading, spacing: 16) {
                        // Pickup
                        HStack(alignment: .center, spacing: 12) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PICKUP")
                                    .font(.system(size: 11, weight: .bold))
                                    .kerning(0.8)
                                    .foregroundColor(.blue)
                                Text(order.originName ?? "Unknown")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(FMSTheme.textPrimary)
                            }
                        }
                        
                        // Delivery
                        HStack(alignment: .center, spacing: 12) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DELIVERY")
                                    .font(.system(size: 11, weight: .bold))
                                    .kerning(0.8)
                                    .foregroundColor(.green)
                                Text(order.destinationName ?? "Unknown")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(FMSTheme.textPrimary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Weight + Truck
                    HStack(spacing: 16) {
                        Label(
                            "\(String(format: "%.0f", order.totalWeightKg)) kg",
                            systemImage: "shippingbox"
                        )
                        Label(
                            "Truck • \(order.orderNumber ?? "—")",
                            systemImage: "truck.box"
                        )
                    }
                    .font(.system(size: 13))
                    .foregroundColor(FMSTheme.textSecondary)

                    Divider()

                    // Action Buttons
                    HStack(spacing: 12) {
                        // Left button: context-sensitive
                        Button {
                            // assign / track action
                        } label: {
                            Text(order.isPending ? "Assign Driver" : "Track")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(FMSTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(FMSTheme.backgroundPrimary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(FMSTheme.borderLight, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        // View Details
                        NavigationLink(destination: Text("Order Detail TBD")) {
                            HStack(spacing: 4) {
                                Text("View Details")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(FMSTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(FMSTheme.backgroundPrimary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(FMSTheme.borderLight, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
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
