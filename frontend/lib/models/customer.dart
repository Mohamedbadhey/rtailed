import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';
part 'customer.g.dart';

@freezed
class Customer with _$Customer {
  const factory Customer({
    @JsonKey(fromJson: _idFromJson, toJson: _idToJson) String? id,
    required String name,
    required String email,
    String? phone,
    String? address,
    @Default(0) int loyaltyPoints,
    @Default(false) bool isActive,
    @Default(1) int businessId,
    DateTime? lastPurchase,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);
}

String? _idFromJson(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is int) return value.toString();
  return value.toString();
}

dynamic _idToJson(String? value) {
  if (value == null) return null;
  return int.tryParse(value) ?? value;
}

String _intToString(dynamic value) {
  if (value is String) return value;
  if (value is int) return value.toString();
  return '';
}

int _stringToInt(String value) => int.tryParse(value) ?? 0; 