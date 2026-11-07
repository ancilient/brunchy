class MenuItem {
  final String id;
  final String stallId;
  final String name;
  final double price;
  final bool isAvailable;
  final String? category;
  final bool isComplex;
  final String? station;
  final bool isVeg;
  final int stock;
  final String? imageUrl;
  final int prepMinutes;
  final bool isPendingApproval;
  final double? pendingPrice;

  const MenuItem({
    required this.id,
    required this.stallId,
    required this.name,
    required this.price,
    required this.isAvailable,
    this.category,
    this.isComplex = false,
    this.station,
    this.isVeg = true,
    this.stock = 20,
    this.imageUrl,
    this.prepMinutes = 5,
    this.isPendingApproval = false,
    this.pendingPrice,
  });

  bool get isLowStock => stock > 0 && stock <= 5;
  bool get isSoldOut => stock == 0 || !isAvailable;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        stallId: json['stallId'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        isAvailable: json['isAvailable'] as bool,
        category: json['category'] as String?,
        isComplex: (json['isComplex'] as bool?) ?? false,
        station: json['station'] as String?,
        isVeg: (json['isVeg'] as bool?) ?? true,
        stock: (json['stock'] as int?) ?? 20,
        imageUrl: json['imageUrl'] as String?,
        prepMinutes: (json['prepMinutes'] as int?) ?? 5,
        isPendingApproval: (json['isPendingApproval'] as bool?) ?? false,
        pendingPrice: json['pendingPrice'] != null ? (json['pendingPrice'] as num).toDouble() : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'stallId': stallId,
        'name': name,
        'price': price,
        'isAvailable': isAvailable,
        'category': category,
        'isComplex': isComplex,
        'station': station,
        'isVeg': isVeg,
        'stock': stock,
        'imageUrl': imageUrl,
        'prepMinutes': prepMinutes,
        'isPendingApproval': isPendingApproval,
        'pendingPrice': pendingPrice,
      };

  MenuItem copyWith({
    String? id,
    String? stallId,
    String? name,
    double? price,
    bool? isAvailable,
    String? category,
    bool? isComplex,
    String? station,
    bool? isVeg,
    int? stock,
    String? imageUrl,
    int? prepMinutes,
    bool? isPendingApproval,
    double? pendingPrice,
  }) =>
      MenuItem(
        id: id ?? this.id,
        stallId: stallId ?? this.stallId,
        name: name ?? this.name,
        price: price ?? this.price,
        isAvailable: isAvailable ?? this.isAvailable,
        category: category ?? this.category,
        isComplex: isComplex ?? this.isComplex,
        station: station ?? this.station,
        isVeg: isVeg ?? this.isVeg,
        stock: stock ?? this.stock,
        imageUrl: imageUrl ?? this.imageUrl,
        prepMinutes: prepMinutes ?? this.prepMinutes,
        isPendingApproval: isPendingApproval ?? this.isPendingApproval,
        pendingPrice: pendingPrice ?? this.pendingPrice,
      );
}
