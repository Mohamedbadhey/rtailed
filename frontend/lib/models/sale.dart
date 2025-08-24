import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:retail_management/models/customer.dart';
import 'package:retail_management/models/product.dart';

part 'sale.freezed.dart';
part 'sale.g.dart';

@freezed
class SaleItem with _$SaleItem {
  const factory SaleItem({
    required int id,
    required int saleId,
    required int productId,
    @JsonKey(fromJson: _stringToInt, toJson: _intToString)
    required int quantity,
    @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
    required double unitPrice,
    @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
    required double totalPrice,
  }) = _SaleItem;

  factory SaleItem.fromJson(Map<String, dynamic> json) => _$SaleItemFromJson(json);
}

// Add helper for nullable int
int? _stringToIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
String? _intToStringNullable(int? value) => value?.toString();

@freezed
class Sale with _$Sale {
  const factory Sale({
    int? id,
    @JsonKey(fromJson: _stringToInt, toJson: _intToStringNullable, name: 'customer_id')
    int? customerId,
    @JsonKey(fromJson: _stringToInt, toJson: _intToString, name: 'user_id')
    required int userId,
    @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString, name: 'total_amount')
    required double totalAmount,
    @JsonKey(fromJson: _nullToString, name: 'payment_method')
    String? paymentMethod,
    @JsonKey(fromJson: _nullToString, name: 'status')
    String? status,
    @JsonKey(name: 'customerName')
    String? customerName,
    @JsonKey(name: 'cashierName')
    String? cashierName,
    @JsonKey(name: 'created_at')
    DateTime? createdAt,
    @JsonKey(fromJson: _stringToIntNullable, toJson: _intToStringNullable, name: 'parent_sale_id')
    int? parentSaleId,
    @JsonKey(name: 'sale_mode')
    String? saleMode,
    @Default(1) int businessId,
    // Cancellation fields
    @JsonKey(name: 'cancelled_at')
    DateTime? cancelledAt,
    @JsonKey(fromJson: _stringToIntNullable, toJson: _intToStringNullable, name: 'cancelled_by')
    int? cancelledBy,
    @JsonKey(name: 'cancellation_reason')
    String? cancellationReason,
    @JsonKey(name: 'cancelled_by_name')
    String? cancelledByName,
    @JsonKey(name: 'notes')
    String? notes,
  }) = _Sale;

  factory Sale.fromJson(Map<String, dynamic> json) => _$SaleFromJson(json);
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
String _intToString(int value) => value.toString();
String? _nullToString(dynamic value) => value?.toString(); 