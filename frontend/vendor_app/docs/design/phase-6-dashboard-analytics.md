# Phase 6 - Dashboard Analytics Design

## Problem Statement
The Brunchy Vendor Dashboard needs to implement comprehensive analytics with:
- Today / This Week / This Month time period selection
- Revenue, Orders, AOV metrics with "vs previous" comparisons
- Sales trend chart (Revenue/Orders toggle)
- Top items, peak hours, average prep time metrics
- Loading states (skeleton), empty states, error-with-retry states
- No overflow at 320dp width and text scale 2.0

## Technical Plan
### 1. Dashboard Screen Enhancements
- Add time period selector with Today/This Week/This Month tabs
- Implement Revenue/Orders toggle for the sales chart
- Add dedicated analytics cards for key metrics
- Ensure 320dp width compliance with responsive layout

### 2. Widget Updates
- **SalesChart**: Ensure 320dp compliance with adjusted bar widths and label spacing
- **SummaryCard**: Add new analytics metric cards with proper loading states
- **SalesTrendHeader**: Implement metric toggle with proper accessibility

### 3. Data Model Extensions
- Extend `DashboardStats` to include:
  - Peak hours breakdown
  - Average prep time calculation
  - Top items with revenue/orders data
  - "vs previous" comparison values

### 4. New Components
- **AnalyticsMetricCard**: Reusable card for revenue, orders, AOV metrics
- **PeriodSelector**: Responsive time period selector with proper spacing

## Files to Change
1. `lib/features/dashboard/dashboard_state.dart` - Extend DashboardStats model
2. `lib/features/dashboard/dashboard_screen.dart` - Add analytics section with loading states
3. `lib/features/dashboard/widgets/sales_chart.dart` - Ensure 320dp compliance
4. `lib/features/dashboard/widgets/summary_card.dart` - Add analytics metric cards
5. `lib/features/dashboard/widgets/top_items_list.dart` - Verify existing implementation
5. `lib/features/dashboard/widgets/peak_hours_bar.dart` - Verify existing implementation

## Data Model Changes
Extend `DashboardStats` with:
- `peakHours`: Hour-by-hour activity breakdown
- `avgPrepTime`: Average preparation time in minutes
- `topItems`: Detailed top items with revenue/orders data
- `revenueChangePct`: Percentage change vs previous period
- `orderCountChangePct`: Percentage change vs previous period

## Edge Cases
- Handle empty data gracefully with skeleton loaders
- Ensure error states show retry button with proper context
- Maintain 320dp compliance at text scale 2.0
- Ensure "vs previous" comparisons work for all time periods

## Tests to Add
- 320dp width compliance tests for all screens
- Text scale 2.0 overflow tests
- Empty state and error state rendering tests
- Period selector functionality tests

## Implementation Notes
- Use existing shimmer package for loading states
- Maintain consistent spacing and typography system
- Ensure all metrics are accessible with proper contrast ratios
- Keep loading states consistent across all dashboard components