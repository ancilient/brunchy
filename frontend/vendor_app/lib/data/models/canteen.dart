class Canteen {
  final String id;
  final String name;

  const Canteen({required this.id, required this.name});

  factory Canteen.fromJson(Map<String, dynamic> json) =>
      Canteen(id: json['id'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

