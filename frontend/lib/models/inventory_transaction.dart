import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:retail_management/models/product.dart';

part 'inventory_transaction.freezed.dart';
part 'inventory_transaction.g.dart';

@freezed
class InventoryTransaction with _$InventoryTransaction {
  const factory InventoryTransaction({
    required String id,
    required Product product,
    required String type,
    required int quantity,
    required String reference,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _InventoryTransaction;

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) =>
      _$InventoryTransactionFromJson(json);
} 