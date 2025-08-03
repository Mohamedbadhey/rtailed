import 'package:freezed_annotation/freezed_annotation.dart';

part 'damaged_product.freezed.dart';
part 'damaged_product.g.dart';

enum DamageType {
  @JsonValue('broken')
  broken,
  @JsonValue('expired')
  expired,
  @JsonValue('defective')
  defective,
  @JsonValue('damaged_package')
  damagedPackage,
  @JsonValue('other')
  other,
}

@freezed
class DamagedProduct with _$DamagedProduct {
  const factory DamagedProduct({
    required int id,
    @JsonKey(name: 'product_id')
    required int productId,
    required int quantity,
    @JsonKey(name: 'damage_type')
    required DamageType damageType,
    @JsonKey(name: 'damage_date')
    required DateTime damageDate,
    @JsonKey(name: 'damage_reason')
    String? damageReason,
    @JsonKey(name: 'estimated_loss', fromJson: _stringToDouble, toJson: _doubleToStringNullable)
    double? estimatedLoss,
    @JsonKey(name: 'reported_by')
    required int reportedBy,
    @JsonKey(name: 'created_at')
    required DateTime createdAt,
    @JsonKey(name: 'product_name')
    String? productName,
    @JsonKey(name: 'product_sku')
    String? productSku,
    @JsonKey(name: 'product_cost', fromJson: _stringToDoubleNullable, toJson: _doubleToStringNullable)
    double? productCost,
    @JsonKey(name: 'product_price', fromJson: _stringToDoubleNullable, toJson: _doubleToStringNullable)
    double? productPrice,
    @JsonKey(name: 'category_name')
    String? categoryName,
    @JsonKey(name: 'reported_by_name')
    String? reportedByName,
  }) = _DamagedProduct;

  factory DamagedProduct.fromJson(Map<String, dynamic> json) => _$DamagedProductFromJson(json);
}

double _stringToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? _stringToDoubleNullable(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _doubleToString(double value) => value.toString();
String? _doubleToStringNullable(double? value) => value?.toString(); 