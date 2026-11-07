import '../../data/models/canteen.dart';
import '../../data/models/stall.dart';
import '../../data/models/vendor.dart';
import '../../data/models/menu_item.dart';
import '../../data/models/inventory_item.dart';
import '../../data/models/order.dart';
import '../../data/models/order_item.dart';
import '../../data/models/order_status.dart';
import '../../data/models/dashboard_stats.dart';
import '../../data/models/dashboard_period.dart';
import '../../core/utils/date_formatter.dart';

class MockData {
  MockData._();

  static const mockToken = 'mock_token_v001';

  static final mockVendor = Vendor(
    id: 'v_001', name: 'Demo Vendor', phone: '9999999999', canteenId: 'main_canteen',
  );

  static final canteens = [
    const Canteen(id: 'main_canteen', name: 'Main Canteen'),
    const Canteen(id: 'advance_block', name: 'Advance Block Canteen'),
  ];

  static final stalls = [
    const Stall(id: 'stall_001', canteenId: 'main_canteen',  name: 'Burger Point',  iconEmoji: '🍔'),
    const Stall(id: 'stall_002', canteenId: 'main_canteen',  name: 'Rolls Corner',  iconEmoji: '🌯'),
    const Stall(id: 'stall_003', canteenId: 'main_canteen',  name: 'South Spice',   iconEmoji: '🍚'),
    const Stall(id: 'stall_004', canteenId: 'main_canteen',  name: 'Juice Bar',     iconEmoji: '🥤'),
    const Stall(id: 'stall_005', canteenId: 'main_canteen',  name: 'Chai & Snacks', iconEmoji: '☕'),
    const Stall(id: 'stall_006', canteenId: 'advance_block', name: 'Quick Bites',   iconEmoji: '🍟'),
    const Stall(id: 'stall_007', canteenId: 'advance_block', name: 'Pasta Point',   iconEmoji: '🍝'),
  ];

  static List<MenuItem> buildMenuItems() => [
    const MenuItem(id: 'item_001', stallId: 'stall_001', name: 'Veg Burger',     price: 60,  isAvailable: true,  category: 'Burgers', isVeg: true,  stock: 22),
    const MenuItem(id: 'item_002', stallId: 'stall_001', name: 'Chicken Burger', price: 90,  isAvailable: true,  category: 'Burgers', isVeg: false, stock: 17),
    const MenuItem(id: 'item_003', stallId: 'stall_001', name: 'Paneer Burger',  price: 80,  isAvailable: true,  category: 'Burgers', isVeg: true,  stock: 15),
    const MenuItem(id: 'item_004', stallId: 'stall_001', name: 'French Fries',   price: 40,  isAvailable: true,  category: 'Sides',   isVeg: true,  stock: 38),
    const MenuItem(id: 'item_005', stallId: 'stall_001', name: 'Onion Rings',    price: 45,  isAvailable: true,  category: 'Sides',   isVeg: true,  stock: 27),
    const MenuItem(id: 'item_006', stallId: 'stall_001', name: 'Veg Roll',       price: 55,  isAvailable: true,  category: 'Rolls',   isVeg: true,  stock: 14),
    const MenuItem(id: 'item_007', stallId: 'stall_001', name: 'Chicken Roll',   price: 75,  isAvailable: true,  category: 'Rolls',   isVeg: false, stock: 3),  // Low stock (3 <= 5)
    const MenuItem(id: 'item_008', stallId: 'stall_001', name: 'Cold Coffee',    price: 50,  isAvailable: true,  category: 'Drinks',  isVeg: true,  stock: 19),
    const MenuItem(id: 'item_009', stallId: 'stall_001', name: 'Mango Shake',    price: 60,  isAvailable: false, category: 'Drinks',  isVeg: true,  stock: 0),  // Sold out
    const MenuItem(id: 'item_010', stallId: 'stall_001', name: 'Water Bottle',   price: 20,  isAvailable: true,  category: 'Drinks',  isVeg: true,  stock: 32),
  ];

  static List<Order> buildOrders() {
    final now = DateTime.now();
    return [
      Order(
        id: 'o_001',
        billNumber: 'B001',
        counterCode: '101',
        studentFirstName: 'Rahul',
        stallId: 'stall_001',
        items: [
          const OrderItem(menuItemId: 'item_001', name: 'Veg Burger', price: 60, quantity: 1),
          const OrderItem(menuItemId: 'item_004', name: 'French Fries', price: 40, quantity: 1),
          const OrderItem(menuItemId: 'item_010', name: 'Water Bottle', price: 20, quantity: 1),
        ],
        totalAmount: 120,
        status: OrderStatus.placed,
        placedAt: now.subtract(const Duration(seconds: 90)),
      ),
      Order(
        id: 'o_002',
        billNumber: 'B002',
        counterCode: '102',
        studentFirstName: 'Priya',
        stallId: 'stall_001',
        items: [
          const OrderItem(menuItemId: 'item_007', name: 'Chicken Roll', price: 75, quantity: 1),
          const OrderItem(menuItemId: 'item_008', name: 'Cold Coffee', price: 50, quantity: 1),
        ],
        totalAmount: 125,
        status: OrderStatus.placed,
        placedAt: now.subtract(const Duration(seconds: 45)),
      ),
      Order(
        id: 'o_003',
        billNumber: 'B003',
        counterCode: '103',
        studentFirstName: 'Amit',
        stallId: 'stall_001',
        items: [
          const OrderItem(menuItemId: 'item_002', name: 'Chicken Burger', price: 90, quantity: 2),
          const OrderItem(menuItemId: 'item_004', name: 'French Fries', price: 40, quantity: 1),
        ],
        totalAmount: 220,
        status: OrderStatus.accepted,
        placedAt: now.subtract(const Duration(minutes: 5)),
        acceptedAt: now.subtract(const Duration(minutes: 4)),
      ),
      Order(
        id: 'o_004',
        billNumber: 'B004',
        counterCode: '104',
        studentFirstName: 'Sneha',
        stallId: 'stall_001',
        items: [
          const OrderItem(menuItemId: 'item_003', name: 'Paneer Burger', price: 80, quantity: 1),
          const OrderItem(menuItemId: 'item_010', name: 'Water Bottle', price: 20, quantity: 1),
        ],
        totalAmount: 100,
        status: OrderStatus.ready,
        placedAt: now.subtract(const Duration(minutes: 10)),
        acceptedAt: now.subtract(const Duration(minutes: 9)),
        readyAt: now.subtract(const Duration(minutes: 2)),
      ),
      Order(
        id: 'o_005',
        billNumber: 'B005',
        counterCode: '105',
        studentFirstName: 'Vikram',
        stallId: 'stall_001',
        items: [
          const OrderItem(menuItemId: 'item_006', name: 'Veg Roll', price: 55, quantity: 2),
          const OrderItem(menuItemId: 'item_008', name: 'Cold Coffee', price: 50, quantity: 1),
        ],
        totalAmount: 160,
        status: OrderStatus.collected,
        placedAt: now.subtract(const Duration(minutes: 20)),
        acceptedAt: now.subtract(const Duration(minutes: 19)),
        readyAt: now.subtract(const Duration(minutes: 15)),
        collectedAt: now.subtract(const Duration(minutes: 12)),
        isCodeUsed: true,
      ),
      Order(
        id: 'o_006',
        billNumber: 'B006',
        counterCode: '106',
        studentFirstName: 'Ananya',
        stallId: 'stall_001',
        items: [
          const OrderItem(menuItemId: 'item_001', name: 'Veg Burger', price: 60, quantity: 1),
        ],
        totalAmount: 60,
        status: OrderStatus.cancelled,
        placedAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  static List<InventoryItem> buildInventory() => [
    InventoryItem(id: 'inv_001', stallId: 'stall_001', menuItemId: 'item_001', menuItemName: 'Veg Burger',     date: DateFormatter.todayKey(), openingStock: 30, currentStock: 22),
    InventoryItem(id: 'inv_002', stallId: 'stall_001', menuItemId: 'item_002', menuItemName: 'Chicken Burger', date: DateFormatter.todayKey(), openingStock: 25, currentStock: 17),
    InventoryItem(id: 'inv_003', stallId: 'stall_001', menuItemId: 'item_003', menuItemName: 'Paneer Burger',  date: DateFormatter.todayKey(), openingStock: 20, currentStock: 15),
    InventoryItem(id: 'inv_004', stallId: 'stall_001', menuItemId: 'item_004', menuItemName: 'French Fries',   date: DateFormatter.todayKey(), openingStock: 50, currentStock: 38),
    InventoryItem(id: 'inv_005', stallId: 'stall_001', menuItemId: 'item_005', menuItemName: 'Onion Rings',    date: DateFormatter.todayKey(), openingStock: 30, currentStock: 27),
    InventoryItem(id: 'inv_006', stallId: 'stall_001', menuItemId: 'item_006', menuItemName: 'Veg Roll',       date: DateFormatter.todayKey(), openingStock: 20, currentStock: 14),
    InventoryItem(id: 'inv_007', stallId: 'stall_001', menuItemId: 'item_007', menuItemName: 'Chicken Roll',   date: DateFormatter.todayKey(), openingStock: 15, currentStock: 11),
    InventoryItem(id: 'inv_008', stallId: 'stall_001', menuItemId: 'item_008', menuItemName: 'Cold Coffee',    date: DateFormatter.todayKey(), openingStock: 25, currentStock: 19),
    InventoryItem(id: 'inv_009', stallId: 'stall_001', menuItemId: 'item_009', menuItemName: 'Mango Shake',    date: DateFormatter.todayKey(), openingStock: 0,  currentStock: 0),
    InventoryItem(id: 'inv_010', stallId: 'stall_001', menuItemId: 'item_010', menuItemName: 'Water Bottle',   date: DateFormatter.todayKey(), openingStock: 40, currentStock: 32),
  ];

  static DashboardStats dashboardStats(DashboardPeriod period) {
    switch (period) {
      case DashboardPeriod.today:
        return DashboardStats(
          totalRevenue: 3240, orderCount: 18, avgOrderValue: 180,
          revenueChangePct: 12.5, orderCountChangePct: 8, aovChangePct: 2.0,
          revenueChangeIsNew: false, revenueChangeIsNone: false,
          orderChangeIsNew: false, orderChangeIsNone: false,
          aovChangeIsNew: false, aovChangeIsNone: false,
          chartData: _todayChart(), topItems: _topItems(), slowItems: _slowItems(),
          peakHours: _peakHours(), statusSplit: {'collected': 15, 'cancelled': 2, 'accepted': 1},
        );
      case DashboardPeriod.thisWeek:
        return DashboardStats(
          totalRevenue: 22860, orderCount: 127, avgOrderValue: 180,
          revenueChangePct: 5.2, orderCountChangePct: 4, aovChangePct: -1.5,
          revenueChangeIsNew: false, revenueChangeIsNone: false,
          orderChangeIsNew: false, orderChangeIsNone: false,
          aovChangeIsNew: false, aovChangeIsNone: false,
          chartData: _weekChart(), topItems: _topItems(), slowItems: _slowItems(),
          peakHours: _peakHours(), statusSplit: {'collected': 115, 'cancelled': 10, 'accepted': 2},
        );
      case DashboardPeriod.thisMonth:
        return DashboardStats(
          totalRevenue: 91440, orderCount: 508, avgOrderValue: 180,
          revenueChangePct: -3.1, orderCountChangePct: -4, aovChangePct: 0.5,
          revenueChangeIsNew: false, revenueChangeIsNone: false,
          orderChangeIsNew: false, orderChangeIsNone: false,
          aovChangeIsNew: false, aovChangeIsNone: false,
          chartData: _monthChart(), topItems: _topItems(), slowItems: _slowItems(),
          peakHours: _peakHours(), statusSplit: {'collected': 460, 'cancelled': 38, 'accepted': 10},
        );
    }
  }

  static List<ChartPoint> _todayChart() {
    final counts = [0,0,0,0,0,0,0,1,2,3,5,4,6,5,3,2,1,2,3,2,1,0,0,0];
    return List.generate(24, (h) => ChartPoint(label: '$h:00', revenue: counts[h]*180.0, orders: counts[h]));
  }

  static List<ChartPoint> _weekChart() {
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final counts = [15,18,20,22,25,18,9];
    return List.generate(7, (i) => ChartPoint(label: days[i], revenue: counts[i]*180.0, orders: counts[i]));
  }

  static List<ChartPoint> _monthChart() =>
    List.generate(30, (d) => ChartPoint(label: '${d+1}', revenue: 17*180.0, orders: 17));

  static List<TopItem> _topItems() => [
    const TopItem(name: 'Chicken Burger', qty: 42, orderCount: 38, revenue: 3780),
    const TopItem(name: 'Veg Burger',     qty: 38, orderCount: 34, revenue: 2280),
    const TopItem(name: 'French Fries',   qty: 35, orderCount: 30, revenue: 1400),
    const TopItem(name: 'Cold Coffee',    qty: 28, orderCount: 25, revenue: 1400),
    const TopItem(name: 'Veg Roll',       qty: 22, orderCount: 20, revenue: 1210),
  ];

  static List<TopItem> _slowItems() => [
    const TopItem(name: 'Mango Shake',  qty: 0, orderCount: 0, revenue: 0),
    const TopItem(name: 'Onion Rings',  qty: 5, orderCount: 4, revenue: 225),
    const TopItem(name: 'Water Bottle', qty: 8, orderCount: 7, revenue: 160),
  ];

  static List<HourCount> _peakHours() {
    final counts = [0,0,0,0,0,0,0,1,2,3,5,4,6,5,3,2,1,2,3,2,1,0,0,0];
    return List.generate(24, (h) => HourCount(hour: h, count: counts[h]));
  }
}
