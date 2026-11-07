class Stall {
  final String id;
  final String canteenId;
  final String name;
  final String iconEmoji;

  const Stall({
    required this.id,
    required this.canteenId,
    required this.name,
    required this.iconEmoji,
  });

  factory Stall.fromJson(Map<String, dynamic> json) => Stall(
        id: json['id'] as String,
        canteenId: json['canteenId'] as String,
        name: json['name'] as String,
        iconEmoji: (json['iconEmoji'] as String?) ?? '🍽️',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'canteenId': canteenId,
        'name': name,
        'iconEmoji': iconEmoji,
      };
}

