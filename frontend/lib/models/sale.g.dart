// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SaleItemImpl _$$SaleItemImplFromJson(Map<String, dynamic> json) =>
    _$SaleItemImpl(
      id: (json['id'] as num).toInt(),
      saleId: (json['saleId'] as num).toInt(),
      productId: (json['productId'] as num).toInt(),
      quantity: _stringToInt(json['quantity']),
      unitPrice: _stringToDouble(json['unitPrice']),
      totalPrice: _stringToDouble(json['totalPrice']),
    );

Map<String, dynamic> _$$SaleItemImplToJson(_$SaleItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'saleId': instance.saleId,
      'productId': instance.productId,
      'quantity': _intToString(instance.quantity),
      'unitPrice': _doubleToString(instance.unitPrice),
      'totalPrice': _doubleToString(instance.totalPrice),
    };

_$SaleImpl _$$SaleImplFromJson(Map<String, dynamic> json) => _$SaleImpl(
      id: (json['id'] as num?)?.toInt(),
      customerId: _stringToInt(json['customer_id']),
      userId: _stringToInt(json['user_id']),
      totalAmount: _stringToDouble(json['total_amount']),
      paymentMethod: _nullToString(json['payment_method']),
      status: _nullToString(json['status']),
      customerName: json['customerName'] as String?,
      cashierName: json['cashierName'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      parentSaleId: _stringToIntNullable(json['parent_sale_id']),
      saleMode: json['sale_mode'] as String?,
      businessId: (json['businessId'] as num?)?.toInt() ?? 1,
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String),
      cancelledBy: _stringToIntNullable(json['cancelled_by']),
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledByName: json['cancelled_by_name'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$SaleImplToJson(_$SaleImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'customer_id': _intToStringNullable(instance.customerId),
      'user_id': _intToString(instance.userId),
      'total_amount': _doubleToString(instance.totalAmount),
      'payment_method': instance.paymentMethod,
      'status': instance.status,
      'customerName': instance.customerName,
      'cashierName': instance.cashierName,
      'created_at': instance.createdAt?.toIso8601String(),
      'parent_sale_id': _intToStringNullable(instance.parentSaleId),
      'sale_mode': instance.saleMode,
      'businessId': instance.businessId,
      'cancelled_at': instance.cancelledAt?.toIso8601String(),
      'cancelled_by': _intToStringNullable(instance.cancelledBy),
      'cancellation_reason': instance.cancellationReason,
      'cancelled_by_name': instance.cancelledByName,
      'notes': instance.notes,
    };
