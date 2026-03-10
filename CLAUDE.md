# CLAUDE.md - FMS Project Intelligence

## Project Overview
A premium B2B iOS SaaS (Amber/Rapido Theme) for logistics. Replaces OBD-II hardware with smartphone sensor fusion. 
**Style:** High-contrast Industrial (Amber #F6C944 on Obsidian #121212).

## Tech Stack
- **Architecture:** 100% MVVM (Model-View-ViewModel).
- **Frameworks:** SwiftUI (iOS 17+), Observation Framework, Supabase (Planned).
- **Design:** Rapido-inspired; heavy buttons, rounded-rect cards, SF Symbols 6 Semibold.

## Build Commands
```bash
# Debug Build
xcodebuild -project FMS.xcodeproj -scheme FMS -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build


## 1. Role Definitions
- **Fleet Manager:** Administrative lead. Manages the vehicle registry (VIN, Plate, Model) and assigns drivers.
- **Driver:** The data-source. Logs fuel, odometer, and performs safety checks. Phone handles passive tracking.
- **Maintenance:** The service lead. Manages service logs and vehicle health status.

## 2. Core Features
- **Role Gateway:** A landing screen to choose between the 3 roles.
- **Vehicle CRUD:** Manual entry for VIN, Plate, Brand, and Model.
- **Fuel Intelligence:** Triple-Verification (Manual Fuel Entry vs. GPS distance vs. Fuel Slider).
- **Live Map:** High-contrast map showing vehicle status (Moving/Idle/Stopped).

## 3. Data Models (Codable / Future Supabase)
1. **Company:** The tenant root.
2. **Vehicle:** Assets with VIN, Plate, and Status.
3. **Driver:** Personnel records.
4. **Trip:** Start/End logs with GPS distance.
5. **FuelLog:** Volume, Cost, and Odometer capture.
6. **TelemetryData:** LocationCoordinate wrapper for sensor logs.
7. **VehicleEvent:** Harsh braking or maintenance alerts

