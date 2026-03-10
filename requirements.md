# FMS Project Specification (V1 Reboot)

## 1. Project Vision & Architecture

A premium B2B iOS SaaS for logistics scalability. The system replaces physical OBD-II hardware with smartphone sensor fusion (GPS, Accelerometer, Gyroscope), focusing on industrial-grade reliability and a high-visibility UX.

**Design Language:** Rapido-inspired. High-contrast Amber (#F6C944) on Obsidian (#121212).

**Platform:** iOS 17+ (SwiftUI, Observation Framework, Supabase).

**Architecture:** 100% MVVM. Logic resides in ViewModels; Views handle the "Amber" Design System.

**Tracking:** Software-only (Phone as the sensor node).

---

## 2. Role-Based Functional Requirements

### 2.1 Fleet Manager (The Control Plane)

- **Asset Management:** Manual CRUD for Vehicles (VIN, Plate, Model, Brand).
- **Fleet Dashboard:** Quick-view metrics of total vehicles, active drivers, and ongoing trips.
- **Live Map:** Real-time visualization of fleet status using color-coded states (Moving/Idle/Stopped).
- **Reporting Suite:**
  - Performance analytics (Fleet, Trip, and Driver-specific).
  - Maintenance expense tracking.
  - Export functionality for external sharing (CSV/PDF templates).

---

### 2.2 Driver (The Execution Plane)

- **Shift Gateway:** Direct access to assigned vehicle details.
- **Initialization:** Manual capture of physical Odometer and a visual Fuel Slider (0–100%).
- **Passive Telemetry:** Background collection of GPS distance and motion data (Harsh maneuvers).
- **Fuel Break:** Manual logging of top-up details: Volume (Liters), Cost ($), and current Odometer.
- **Safety:** Pre-inspection checklists and automated crash detection (High-G impact).

---

### 2.3 Maintenance (The Lifecycle Plane)

- **Service Queue:** Dashboard of vehicles requiring immediate attention or preventative maintenance.
- **Health Logs:** Record repair details and update vehicle "Ready/In-Shop" status.
- **Parts Inventory:** Basic tracking of essential parts with automated restock alerts.

---

## 3. The Triple-Verification Fuel Model

To prevent fuel leakage, the system audits logs via:

- **Manual Input:** Data entered by the driver during a "Fuel Break."
- **GPS Estimation:** Distance tracked / Vehicle baseline = Expected consumption.
- **Visual Delta:** Comparison of start-trip vs. end-trip Fuel Slider estimates.

---

## 4. Technical Implementation Details

### 4.1 Sensor Fusion & Battery Strategy

- **Adaptive Polling:** GPS frequency scales based on Accelerometer activity (saves battery when parked).
- **Sensor Mapping:** CMMotionManager detects hard braking or rapid acceleration without external hardware.

---

### 4.2 Data Management (Supabase)

- **Offline-First:** Handled via Supabase offline capabilities / local storage. Logs are saved locally and synced automatically when connectivity permits.
- **Multi-Tenancy:** All records are partitioned by CompanyID to ensure data isolation between different fleet owners.

---

### 4.3 Navigation & UI Shell

- **Fleet Manager / Maintenance:** NavigationSplitView (Sidebar) optimized for high-density information.
- **Driver:** TabView optimized for one-handed use and mobile field conditions.
- **Gateway:** App-wide RoleSelectionView presented on launch to facilitate role-specific feature testing.