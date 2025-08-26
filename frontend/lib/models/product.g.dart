// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductImpl _$$ProductImplFromJson(Map<String, dynamic> json) =>
    _$ProductImpl(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: json['category_name'] as String?,
      price: _stringToDouble(json['price']),
      wholesalePrice: _stringToDouble(json['wholesalePrice']),
      costPrice: _stringToDouble(json['cost_price']),
      stockQuantity: _stringToInt(json['stock_quantity']),
      damagedQuantity: _stringToInt(json['damaged_quantity']),
      lowStockThreshold: _stringToInt(json['low_stock_threshold']),
      imageUrl: json['image_url'] as String?,
      isDeleted:
          json['is_deleted'] == null ? 0 : _stringToInt(json['is_deleted']),
      businessId: (json['businessId'] as num?)?.toInt() ?? 1,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ProductImplToJson(_$ProductImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'sku': instance.sku,
      'barcode': instance.barcode,
      'category_id': instance.categoryId,
      'category_name': instance.categoryName,
      'price': _doubleToString(instance.price),
      'wholesalePrice': _doubleToStringNullable(instance.wholesalePrice),
      'cost_price': _doubleToString(instance.costPrice),
      'stock_quantity': _intToString(instance.stockQuantity),
      'damaged_quantity': _intToString(instance.damagedQuantity),
      'low_stock_threshold': _intToString(instance.lowStockThreshold),
      'image_url': instance.imageUrl,
      'is_deleted': _intToString(instance.isDeleted),
      'businessId': instance.businessId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
