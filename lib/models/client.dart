class Client {
  final String id;
  String name;
  String company;
  String email;
  String phone;
  String address;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.name,
    this.company = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'company': company,
        'email': email,
        'phone': phone,
        'address': address,
        'created_at': createdAt.toIso8601String(),
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as String,
        name: map['name'] as String,
        company: map['company'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        address: map['address'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
