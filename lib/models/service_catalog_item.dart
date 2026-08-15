class ServiceCatalogItem {
  final String id;
  String name;
  String description;
  String unit;
  double defaultRate;

  ServiceCatalogItem({
    required this.id,
    required this.name,
    this.description = '',
    this.unit = 'hour',
    this.defaultRate = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'unit': unit,
        'defaultRate': defaultRate,
      };

  factory ServiceCatalogItem.fromMap(Map<String, dynamic> map) =>
      ServiceCatalogItem(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        unit: map['unit'] as String? ?? 'hour',
        defaultRate: (map['defaultRate'] as num?)?.toDouble() ?? 0.0,
      );
}
