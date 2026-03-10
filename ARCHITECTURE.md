# FMS Master Architecture & Technical Specification (V1 Reboot)

## 1. Design System (Rapido-Inspired / iOS Native)
- **Primary Color:** `RGB(246, 201, 68)` (Amber Yellow).
- **Secondary Color:** `#121212` (Deep Black) for high-contrast cards.
- **Vibe:** High-visibility industrial. Heavy use of rounded corners and thick borders for buttons.
- **Icons:** Consistent SF Symbols 6 (semibold or bold weight).

## 2. Core MVVM Structure
- **Model:** Standard Swift Models (Codable) (Future: Supabase).
- **ViewModel:** @Observable logic for each major view.
- **View:** Component-based UI using the Amber Design System.

## 3. The 3-Role Gateway Flow
- **Entry:** App starts at `RoleSelectionView` (Amber buttons on Black background).
- **Fleet Manager:** - Top Level: `Dashboard`, `Map`, `Fleet Management`.
  - Sidebar style: `NavigationSplitView`.
- **Driver:** - Top Level: `Active Trip`, `Fuel Break`, `History`.
  - Tab style: Optimized for mobile/handheld use.
- **Maintenance:** - Top Level: `Service Queue`, `Inventory`, `Vehicle Status`.

## 4. Key Component Library
- `FMSPrimaryButton`: Amber background, Black rounded-rect style.
- `FMSRoleCard`: Large interactive cards for the landing page.
- `FMSStatusBadge`: High-visibility labels for "Active/Inactive/Low Fuel."

## 5. File Implementation Roadmap
- **Chunk 1:** `FMSTheme.swift`, `Models/`, `RoleSelectionView.swift`.
- **Chunk 2:** `MainSideBarView.swift` (Manager) and `MainTabView.swift` (Driver).
- **Chunk 3:** `AddVehicleForm` and `FuelEntryForm`.