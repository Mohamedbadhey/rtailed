// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'damaged_product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DamagedProductImpl _$$DamagedProductImplFromJson(Map<String, dynamic> json) =>
    _$DamagedProductImpl(
      id: (json['id'] as num).toInt(),
      productId: (json['product_id'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      damageType: $enumDecode(_$DamageTypeEnumMap, json['damage_type']),
      damageDate: DateTime.parse(json['damage_date'] as String),
      damageReason: json['damage_reason'] as String?,
      estimatedLoss: _stringToDouble(json['estimated_loss']),
      reportedBy: (json['reported_by'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      productName: json['product_name'] as String?,
      productSku: json['product_sku'] as String?,
      productCost: _stringToDoubleNullable(json['product_cost']),
      productPrice: _stringToDoubleNullable(json['product_price']),
      categoryName: json['category_name'] as String?,
      reportedByName: json['reported_by_name'] as String?,
    );

Map<String, dynamic> _$$DamagedProductImplToJson(
        _$DamagedProductImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'product_id': instance.productId,
      'quantity': instance.quantity,
      'damage_type': _$DamageTypeEnumMap[instance.damageType]!,
      'damage_date': instance.damageDate.toIso8601String(),
      'damage_reason': instance.damageReason,
      'estimated_loss': _doubleToStringNullable(instance.estimatedLoss),
      'reported_by': instance.reportedBy,
      'created_at': instance.createdAt.toIso8601String(),
      'product_name': instance.productName,
      'product_sku': instance.productSku,
      'product_cost': _doubleToStringNullable(instance.productCost),
      'product_price': _doubleToStringNullable(instance.productPrice),
      'category_name': instance.categoryName,
      'reported_by_name': instance.reportedByName,
    };

const _$DamageTypeEnumMap = {
  DamageType.broken: 'broken',
  DamageType.expired: 'expired',
  DamageType.defective: 'defective',
  DamageType.damagedPackage: 'damaged_package',
  DamageType.other: 'other',
};
