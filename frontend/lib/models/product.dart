import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
class Product with _$Product {
  const factory Product({
    int? id,
    required String name,
    String? description,
    String? sku,
    String? barcode,
    @JsonKey(name: 'category_id') int? categoryId,
    @JsonKey(name: 'category_name') String? categoryName,
    @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
    required double price,
    @JsonKey(fromJson: _stringToDouble, toJson: _doubleToStringNullable)
    double? wholesalePrice,
    @JsonKey(name: 'cost_price', fromJson: _stringToDouble, toJson: _doubleToString)
    required double costPrice,
    @JsonKey(name: 'stock_quantity', fromJson: _stringToInt, toJson: _intToString)
    required int stockQuantity,
    @JsonKey(name: 'damaged_quantity', fromJson: _stringToInt, toJson: _intToString)
    required int damagedQuantity,
    @JsonKey(name: 'low_stock_threshold', fromJson: _stringToInt, toJson: _intToString)
    required int lowStockThreshold,
    @JsonKey(name: 'image_url')
    String? imageUrl,
    @JsonKey(name: 'is_deleted', fromJson: _stringToInt, toJson: _intToString)
    @Default(0) int isDeleted,
    @Default(1) int businessId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
}

double _stringToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _stringToInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _doubleToString(double value) => value.toString();
String? _doubleToStringNullable(double? value) => value?.toString();
String _intToString(int value) => value.toString(); 