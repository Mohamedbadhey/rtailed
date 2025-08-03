import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';
part 'customer.g.dart';

@freezed
class Customer with _$Customer {
  const factory Customer({
    String? id,
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

String _intToString(dynamic value) {
  if (value is String) return value;
  if (value is int) return value.toString();
  return '';
}

int _stringToInt(String value) => int.tryParse(value) ?? 0; 