class Vendor {
  final String id;
  final String name;
  final String phone;
  final String canteenId;

  const Vendor({
    required this.id,
    required this.name,
    required this.phone,
    required this.canteenId,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) => Vendor(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        canteenId: json['canteenId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'canteenId': canteenId,
      };

  Vendor copyWith({String? id, String? name, String? phone, String? canteenId}) => Vendor(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        canteenId: canteenId ?? this.canteenId,
      );
}

