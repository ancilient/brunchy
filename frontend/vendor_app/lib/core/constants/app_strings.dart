class AppStrings {
  AppStrings._();

  // Auth
  static const String appName          = 'Brunchy Vendor';
  static const String loginTitle        = 'Welcome!';
  static const String loginSubtitle     = 'Tell us who you are';
  static const String nameHint          = 'Your full name';
  static const String phoneHint         = 'Phone number (10 digits)';
  static const String mainCanteen       = 'Main Canteen';
  static const String advanceBlock      = 'Advance Block Canteen';
  static const String startMyDay        = 'Start My Day →';
  static const String chooseStall       = 'Choose Your Stall';
  static const String switchStall       = 'Switch Stall';
  static const String goodMorning       = 'Good morning';

  // Orders
  static const String newOrders         = 'New';
  static const String preparing         = 'Preparing';
  static const String ready             = 'Ready';
  static const String all               = 'All';
  static const String accept            = 'Accept';
  static const String reject            = 'Reject';
  static const String markReady         = 'Mark Ready';
  static const String collectOtp        = 'Hand over — Enter code';
  static const String enterOtp          = 'Enter student\'s 3-digit code';
  static const String otpAlreadyCollected = 'This order has already been collected';
  static const String otpNotReady       = 'Mark food ready first';
  static const String markedReady       = 'Marked ready!';
  static const String undo              = 'Undo';
  static const String noOrders          = 'No orders yet';
  static const String noOrdersSubtitle  = 'New orders will appear here';

  // Menu
  static const String menuTab           = 'Menu';
  static const String addItem           = 'Add Item';
  static const String editItem          = 'Edit Item';
  static const String itemName          = 'Item name';
  static const String itemPrice         = 'Price (₹)';
  static const String itemCategory      = 'Category (optional)';
  static const String available         = 'Available';
  static const String noMenu            = 'No items yet';
  static const String noMenuSubtitle    = 'Add your first menu item';

  // Inventory
  static const String inventoryTab      = 'Inventory';
  static const String openingStock      = 'Was';
  static const String soldToday         = 'Sold';
  static const String inventoryNote     = '⚠ "Sold today" = stock reduction. May differ from dashboard order count.';

  // Dashboard
  static const String dashboardTab      = 'Dashboard';
  static const String today             = 'Today';
  static const String thisWeek         = 'This Week';
  static const String thisMonth        = 'This Month';
  static const String totalRevenue      = 'Total Revenue';
  static const String orderCount        = 'Orders';
  static const String avgOrderValue     = 'Avg Order';
  static const String topItems          = 'Top Items';
  static const String slowItems         = 'Needs Attention';
  static const String peakHours         = 'Peak Hours';
  static const String revenue           = 'Revenue';
  static const String orders            = 'Orders';

  // End Day
  static const String endDay            = 'End Day';
  static const String endDayConfirm     = 'End your day? This saves today\'s inventory as tomorrow\'s opening stock.';
  static const String endDayActiveOrders = 'You have {count} active orders. Ending your day will cancel them and refund the students. This cannot be undone.';
  static const String keepWorking       = 'Keep Working';
  static const String cancelAllEndDay   = 'Cancel All & End Day';

  // Settings
  static const String settingsTitle     = 'Settings';
  static const String pastOrders        = 'Past Orders';

  // Errors
  static const String cancel            = 'Cancel';
  static const String retry             = 'Retry';
  static const String networkError      = 'No connection. Check your internet.';
  static const String retryButton       = 'Retry';
  static const String sessionReset      = 'Session reset due to data error';
  static const String orderAutoCancelled = 'Order was auto-cancelled';
  static const String reconnecting      = 'Reconnecting to order stream…';
  static const String volumeWarning     = '⚠ Alert volume is off — tap to fix';
}

