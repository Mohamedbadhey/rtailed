// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InventoryTransactionImpl _$$InventoryTransactionImplFromJson(
        Map<String, dynamic> json) =>
    _$InventoryTransactionImpl(
      id: json['id'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      type: json['type'] as String,
      quantity: (json['quantity'] as num).toInt(),
      reference: json['reference'] as String,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$InventoryTransactionImplToJson(
        _$InventoryTransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'product': instance.product,
      'type': instance.type,
      'quantity': instance.quantity,
      'reference': instance.reference,
      'notes': instance.notes,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
