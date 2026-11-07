# Phase 7 Emergency Stop (Force Stop)

## Overview
Critical operational control for stalls to immediately stop accepting new orders, cancel pending ones, and temporarily close operations for maintenance, emergencies, or staff issues. Provides "force stop" capabilities beyond the existing capacity gate and overload protection.

## Key Features

### 1. Emergency Stop Button
- **Red "EMERGENCY STOP" button** prominently displayed on DashboardScreen and SettingsScreen
- **Immediate effect** - stalls can accept no new orders once activated
- **Requires confirmation dialog** with mandatory reason selection

### 2. Confirmation Dialog
- **Modal dialog** with reason dropdown (5 predefined reasons + custom)
- **Required field validation** - stops cannot be created without explicit reason
- **Reason options:**
  - System maintenance (planned shutdown)
  - Power outage / equipment failure
  - Staff shortage / break
  - Food safety issue
  - Emergency evacuation
  - Other (custom text field)

### 3. Stall Closed State
- **Persistent state** - stored in LocalStorageService (`isStallClosed`)
- **Dashboard overlay** - shows "STALL CLOSED" banner with stop details and countdown
- **Global impact** - prevents order acceptance across all screens

### 4. Queue Management
- **Automatic cancellation** - all QUEUED orders immediately marked as CANCELLED/REFUNDED
- **Manual cancellation** - per-order cancellation available during stop
- **Refund processing** - refunds automatically calculated and applied
- **No auto-promotion** - while stall is closed, queued orders are NOT promoted to Preparing

### 5. Per-Order Actions
- **Cancel with reason** - within stop window, individual orders can be cancelled with reason codes:
  - OUT_OF_STOCK
  - KITCHEN_ISSUE
  - STALL_EMERGENCY
  - CUSTOM (requires text)
- **Preserve ready orders** - READY orders remain collectable until handed over

### 6. Reopen Controls
- **Reopen button** appears when stall is closed
- **Confirmation required** for reopening
- **Auto-clear** - clears audit log after successful reopen

### 7. Audit Trail
- **Structured logging** for all stop operations:
  - Staff ID (currently from stored vendor)
  - Timestamp (ISO 8601)
  - Reason (selected + custom text)
  - Orders cancelled count
  - Reopen timestamp (if applicable)
- **Persistent storage** - stored locally and synced on reconnection

### 8. UI Integration
- **DashboardScreen** - top-right corner emergency stop button with status indicator
- **SettingsScreen** - dedicated Emergency Stop section with current status and controls
- **OrdersScreen** - clear visual indicator and contextual actions
- **AppBar** - emergency stop status indicator badge

### 9. API Integration Points
- **API-024** POST /stalls/{stallId}/emergency-stop
- **API-025** PATCH /stalls/{stallId}/reopen
- **API-026** GET /stalls/{stallId}/emergency-stop-status

### 10. Error Handling
- **Permissions** - only vendors with appropriate roles can trigger emergency stop
- **Validation** - prevent duplicate stops, handle concurrent operations
- **Recovery** - automatic retry for failed operations

## State Management

### EmergencyStopCubit
- **States:** EmergencyStopInitial, EmergencyStopLoading, EmergencyStopActive, EmergencyStopReopening
- **Properties:**
  - isActive - whether emergency stop is currently active
  - stopReason - reason for stop
  - stopTimestamp - when stop was activated
  - reopenedAt - timestamp when reopened (null if still active)
  - cancelledOrdersCount - total orders cancelled
  - auditLog - list of audit entries

### OrdersCubit Integration
- **Add emergency check** before auto-promotion
- **Add cancelOrder** method for per-order cancellation during stop
- **Update UI** based on emergency stop state
- **Handle stop loading states** appropriately

## UI Components

### EmergencyStopButton (Widget)
- **Red background** with white "STOP" text
- **Animated pulse** when active to draw attention
- **Tap shows confirmation dialog**
- **Long press** shows current status and reopen option

### EmergencyStopOverlay (Widget)
- **Full-screen overlay** when stall is closed
- **Large "STALL CLOSED" heading** with animated countdown if reopen scheduled
- **Reason and timestamp display**
- **Orders cancelled count**
- **Reopen button** (if permissions allow)

### EmergencyStopSheet (Bottom Sheet)
- **Detailed status view** accessible from dashboard
- **Audit log display**
- **Quick actions** (reopen, view details)

## Technical Implementation

### Model Updates
- **Stall model** - add `isClosed`, `closedAt`, `closedReason` properties
- **Order model** - add `isCancelledDueuvance` flag
- **EmergencyStop model** - structured stop record

### Repository Interface
- **OrderRepository** - add `emergencyStop`, `reopenStall`, `getEmergencyStopStatus` methods
- **AuthRepository** - add `canPerformEmergencyStop` method

### Service Layer
- **LocalStorageService** - persist emergency stop state
- **AnalyticsService** - log emergency stop events
- **RealtimeService** - broadcast emergency stop state changes

## Compliance
- **GDPR/Privacy** - audit logs contain minimal PII
- **Security** - emergency stop requires vendor authentication
- **Recovery** - automatic state recovery on app restart
- **Offline support** - local persistence for offline scenarios

## Testing Strategy
- **Unit tests** for EmergencyStopCubit logic
- **Widget tests** for emergency stop UI components
- **Integration tests** for emergency stop flows across screens
- **End-to-end tests** for emergency stop scenarios with mock repository

## Rollout Plan
1. **Design review** - stakeholder approval
2. **Code implementation** - core emergency stop functionality
3. **UI development** - dashboard and settings screens
4. **Testing** - comprehensive test coverage
5. **Documentation** - user guide and admin procedures
6. **Production deployment** - phased rollout with monitoring

## Dependencies
- **New:** `emergency_stop` package (if external)
- **Existing:** local storage, real-time services
- **Risks:** none identified

## Success Metrics
- **MTTR** (Mean Time to Recovery) reduced
- **Order cancellation rate** during emergencies tracked
- **Staff response time** to emergency situations measured
- **User satisfaction** with emergency controls collected