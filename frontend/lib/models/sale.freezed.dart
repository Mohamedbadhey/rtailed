// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sale.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SaleItem _$SaleItemFromJson(Map<String, dynamic> json) {
  return _SaleItem.fromJson(json);
}

/// @nodoc
mixin _$SaleItem {
  int get id => throw _privateConstructorUsedError;
  int get saleId => throw _privateConstructorUsedError;
  int get productId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  int get quantity => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  double get unitPrice => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  double get totalPrice => throw _privateConstructorUsedError;

  /// Serializes this SaleItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SaleItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SaleItemCopyWith<SaleItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SaleItemCopyWith<$Res> {
  factory $SaleItemCopyWith(SaleItem value, $Res Function(SaleItem) then) =
      _$SaleItemCopyWithImpl<$Res, SaleItem>;
  @useResult
  $Res call(
      {int id,
      int saleId,
      int productId,
      @JsonKey(fromJson: _stringToInt, toJson: _intToString) int quantity,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      double unitPrice,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      double totalPrice});
}

/// @nodoc
class _$SaleItemCopyWithImpl<$Res, $Val extends SaleItem>
    implements $SaleItemCopyWith<$Res> {
  _$SaleItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SaleItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? saleId = null,
    Object? productId = null,
    Object? quantity = null,
    Object? unitPrice = null,
    Object? totalPrice = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      saleId: null == saleId
          ? _value.saleId
          : saleId // ignore: cast_nullable_to_non_nullable
              as int,
      productId: null == productId
          ? _value.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as int,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      unitPrice: null == unitPrice
          ? _value.unitPrice
          : unitPrice // ignore: cast_nullable_to_non_nullable
              as double,
      totalPrice: null == totalPrice
          ? _value.totalPrice
          : totalPrice // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SaleItemImplCopyWith<$Res>
    implements $SaleItemCopyWith<$Res> {
  factory _$$SaleItemImplCopyWith(
          _$SaleItemImpl value, $Res Function(_$SaleItemImpl) then) =
      __$$SaleItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      int saleId,
      int productId,
      @JsonKey(fromJson: _stringToInt, toJson: _intToString) int quantity,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      double unitPrice,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      double totalPrice});
}

/// @nodoc
class __$$SaleItemImplCopyWithImpl<$Res>
    extends _$SaleItemCopyWithImpl<$Res, _$SaleItemImpl>
    implements _$$SaleItemImplCopyWith<$Res> {
  __$$SaleItemImplCopyWithImpl(
      _$SaleItemImpl _value, $Res Function(_$SaleItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of SaleItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? saleId = null,
    Object? productId = null,
    Object? quantity = null,
    Object? unitPrice = null,
    Object? totalPrice = null,
  }) {
    return _then(_$SaleItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      saleId: null == saleId
          ? _value.saleId
          : saleId // ignore: cast_nullable_to_non_nullable
              as int,
      productId: null == productId
          ? _value.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as int,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      unitPrice: null == unitPrice
          ? _value.unitPrice
          : unitPrice // ignore: cast_nullable_to_non_nullable
              as double,
      totalPrice: null == totalPrice
          ? _value.totalPrice
          : totalPrice // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SaleItemImpl implements _SaleItem {
  const _$SaleItemImpl(
      {required this.id,
      required this.saleId,
      required this.productId,
      @JsonKey(fromJson: _stringToInt, toJson: _intToString)
      required this.quantity,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      required this.unitPrice,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      required this.totalPrice});

  factory _$SaleItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$SaleItemImplFromJson(json);

  @override
  final int id;
  @override
  final int saleId;
  @override
  final int productId;
  @override
  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int quantity;
  @override
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  final double unitPrice;
  @override
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  final double totalPrice;

  @override
  String toString() {
    return 'SaleItem(id: $id, saleId: $saleId, productId: $productId, quantity: $quantity, unitPrice: $unitPrice, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SaleItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.saleId, saleId) || other.saleId == saleId) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.unitPrice, unitPrice) ||
                other.unitPrice == unitPrice) &&
            (identical(other.totalPrice, totalPrice) ||
                other.totalPrice == totalPrice));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, saleId, productId, quantity, unitPrice, totalPrice);

  /// Create a copy of SaleItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SaleItemImplCopyWith<_$SaleItemImpl> get copyWith =>
      __$$SaleItemImplCopyWithImpl<_$SaleItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SaleItemImplToJson(
      this,
    );
  }
}

abstract class _SaleItem implements SaleItem {
  const factory _SaleItem(
      {required final int id,
      required final int saleId,
      required final int productId,
      @JsonKey(fromJson: _stringToInt, toJson: _intToString)
      required final int quantity,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      required final double unitPrice,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      required final double totalPrice}) = _$SaleItemImpl;

  factory _SaleItem.fromJson(Map<String, dynamic> json) =
      _$SaleItemImpl.fromJson;

  @override
  int get id;
  @override
  int get saleId;
  @override
  int get productId;
  @override
  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  int get quantity;
  @override
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  double get unitPrice;
  @override
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  double get totalPrice;

  /// Create a copy of SaleItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SaleItemImplCopyWith<_$SaleItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Sale _$SaleFromJson(Map<String, dynamic> json) {
  return _Sale.fromJson(json);
}

/// @nodoc
mixin _$Sale {
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(
      fromJson: _stringToInt, toJson: _intToStringNullable, name: 'customer_id')
  int? get customerId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _stringToInt, toJson: _intToString, name: 'user_id')
  int get userId => throw _privateConstructorUsedError;
  @JsonKey(
      fromJson: _stringToDouble, toJson: _doubleToString, name: 'total_amount')
  double get totalAmount => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullToString, name: 'payment_method')
  String? get paymentMethod => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullToString, name: 'status')
  String? get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'customerName')
  String? get customerName => throw _privateConstructorUsedError;
  @JsonKey(name: 'cashierName')
  String? get cashierName => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      fromJson: _stringToIntNullable,
      toJson: _intToStringNullable,
      name: 'parent_sale_id')
  int? get parentSaleId => throw _privateConstructorUsedError;
  @JsonKey(name: 'sale_mode')
  String? get saleMode => throw _privateConstructorUsedError;
  int get businessId =>
      throw _privateConstructorUsedError; // Cancellation fields
  @JsonKey(name: 'cancelled_at')
  DateTime? get cancelledAt => throw _privateConstructorUsedError;
  @JsonKey(
      fromJson: _stringToIntNullable,
      toJson: _intToStringNullable,
      name: 'cancelled_by')
  int? get cancelledBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'cancellation_reason')
  String? get cancellationReason => throw _privateConstructorUsedError;
  @JsonKey(name: 'cancelled_by_name')
  String? get cancelledByName => throw _privateConstructorUsedError;
  @JsonKey(name: 'notes')
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this Sale to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Sale
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SaleCopyWith<Sale> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SaleCopyWith<$Res> {
  factory $SaleCopyWith(Sale value, $Res Function(Sale) then) =
      _$SaleCopyWithImpl<$Res, Sale>;
  @useResult
  $Res call(
      {int? id,
      @JsonKey(
          fromJson: _stringToInt,
          toJson: _intToStringNullable,
          name: 'customer_id')
      int? customerId,
      @JsonKey(fromJson: _stringToInt, toJson: _intToString, name: 'user_id')
      int userId,
      @JsonKey(
          fromJson: _stringToDouble,
          toJson: _doubleToString,
          name: 'total_amount')
      double totalAmount,
      @JsonKey(fromJson: _nullToString, name: 'payment_method')
      String? paymentMethod,
      @JsonKey(fromJson: _nullToString, name: 'status') String? status,
      @JsonKey(name: 'customerName') String? customerName,
      @JsonKey(name: 'cashierName') String? cashierName,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(
          fromJson: _stringToIntNullable,
          toJson: _intToStringNullable,
          name: 'parent_sale_id')
      int? parentSaleId,
      @JsonKey(name: 'sale_mode') String? saleMode,
      int businessId,
      @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
      @JsonKey(
          fromJson: _stringToIntNullable,
          toJson: _intToStringNullable,
          name: 'cancelled_by')
      int? cancelledBy,
      @JsonKey(name: 'cancellation_reason') String? cancellationReason,
      @JsonKey(name: 'cancelled_by_name') String? cancelledByName,
      @JsonKey(name: 'notes') String? notes});
}

/// @nodoc
class _$SaleCopyWithImpl<$Res, $Val extends Sale>
    implements $SaleCopyWith<$Res> {
  _$SaleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Sale
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? customerId = freezed,
    Object? userId = null,
    Object? totalAmount = null,
    Object? paymentMethod = freezed,
    Object? status = freezed,
    Object? customerName = freezed,
    Object? cashierName = freezed,
    Object? createdAt = freezed,
    Object? parentSaleId = freezed,
    Object? saleMode = freezed,
    Object? businessId = null,
    Object? cancelledAt = freezed,
    Object? cancelledBy = freezed,
    Object? cancellationReason = freezed,
    Object? cancelledByName = freezed,
    Object? notes = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      customerId: freezed == customerId
          ? _value.customerId
          : customerId // ignore: cast_nullable_to_non_nullable
              as int?,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int,
      totalAmount: null == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      customerName: freezed == customerName
          ? _value.customerName
          : customerName // ignore: cast_nullable_to_non_nullable
              as String?,
      cashierName: freezed == cashierName
          ? _value.cashierName
          : cashierName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      parentSaleId: freezed == parentSaleId
          ? _value.parentSaleId
          : parentSaleId // ignore: cast_nullable_to_non_nullable
              as int?,
      saleMode: freezed == saleMode
          ? _value.saleMode
          : saleMode // ignore: cast_nullable_to_non_nullable
              as String?,
      businessId: null == businessId
          ? _value.businessId
          : businessId // ignore: cast_nullable_to_non_nullable
              as int,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledBy: freezed == cancelledBy
          ? _value.cancelledBy
          : cancelledBy // ignore: cast_nullable_to_non_nullable
              as int?,
      cancellationReason: freezed == cancellationReason
          ? _value.cancellationReason
          : cancellationReason // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelledByName: freezed == cancelledByName
          ? _value.cancelledByName
          : cancelledByName // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SaleImplCopyWith<$Res> implements $SaleCopyWith<$Res> {
  factory _$$SaleImplCopyWith(
          _$SaleImpl value, $Res Function(_$SaleImpl) then) =
      __$$SaleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? id,
      @JsonKey(
          fromJson: _stringToInt,
          toJson: _intToStringNullable,
          name: 'customer_id')
      int? customerId,
      @JsonKey(fromJson: _stringToInt, toJson: _intToString, name: 'user_id')
      int userId,
      @JsonKey(
          fromJson: _stringToDouble,
          toJson: _doubleToString,
          name: 'total_amount')
      double totalAmount,
      @JsonKey(fromJson: _nullToString, name: 'payment_method')
      String? paymentMethod,
      @JsonKey(fromJson: _nullToString, name: 'status') String? status,
      @JsonKey(name: 'customerName') String? customerName,
      @JsonKey(name: 'cashierName') String? cashierName,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(
          fromJson: _stringToIntNullable,
          toJson: _intToStringNullable,
          name: 'parent_sale_id')
      int? parentSaleId,
      @JsonKey(name: 'sale_mode') String? saleMode,
      int businessId,
      @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
      @JsonKey(
          fromJson: _stringToIntNullable,
          toJson: _intToStringNullable,
          name: 'cancelled_by')
      int? cancelledBy,
      @JsonKey(name: 'cancellation_reason') String? cancellationReason,
      @JsonKey(name: 'cancelled_by_name') String? cancelledByName,
      @JsonKey(name: 'notes') String? notes});
}

/// @nodoc
class __$$SaleImplCopyWithImpl<$Res>
    extends _$SaleCopyWithImpl<$Res, _$SaleImpl>
    implements _$$SaleImplCopyWith<$Res> {
  __$$SaleImplCopyWithImpl(_$SaleImpl _value, $Res Function(_$SaleImpl) _then)
      : super(_value, _then);

  /// Create a copy of Sale
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? customerId = freezed,
    Object? userId = null,
    Object? totalAmount = null,
    Object? paymentMethod = freezed,
    Object? status = freezed,
    Object? customerName = freezed,
    Object? cashierName = freezed,
    Object? createdAt = freezed,
    Object? parentSaleId = freezed,
    Object? saleMode = freezed,
    Object? businessId = null,
    Object? cancelledAt = freezed,
    Object? cancelledBy = freezed,
    Object? cancellationReason = freezed,
    Object? cancelledByName = freezed,
    Object? notes = freezed,
  }) {
    return _then(_$SaleImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      customerId: freezed == customerId
          ? _value.customerId
          : customerId // ignore: cast_nullable_to_non_nullable
              as int?,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int,
      totalAmount: null == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      customerName: freezed == customerName
          ? _value.customerName
          : customerName // ignore: cast_nullable_to_non_nullable
              as String?,
      cashierName: freezed == cashierName
          ? _value.cashierName
          : cashierName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      parentSaleId: freezed == parentSaleId
          ? _value.parentSaleId
          : parentSaleId // ignore: cast_nullable_to_non_nullable
              as int?,
      saleMode: freezed == saleMode
          ? _value.saleMode
          : saleMode // ignore: cast_nullable_to_non_nullable
              as String?,
      businessId: null == businessId
          ? _value.businessId
          : businessId // ignore: cast_nullable_to_non_nullable
              as int,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledBy: freezed == cancelledBy
          ? _value.cancelledBy
          : cancelledBy // ignore: cast_nullable_to_non_nullable
              as int?,
      cancellationReason: freezed == cancellationReason
          ? _value.cancellationReason
          : cancellationReason // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelledByName: freezed == cancelledByName
          ? _value.cancelledByName
          : cancelledByName // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SaleImpl implements _Sale {
  const _$SaleImpl(
      {this.id,
      @JsonKey(
          fromJson: _stringToInt,
          toJson: _intToStringNullable,
          name: 'customer_id')
      this.customerId,
      @JsonKey(fromJson: _stringToInt, toJson: _intToString, name: 'user_id')
      required this.userId,
      @JsonKey(
          fromJson: _stringToDouble,
          toJson: _doubleToString,
          name: 'total_amount')
      required this.totalAmount,
      @JsonKey(fromJson: _nullToString, name: 'payment_method')
      this.paymentMethod,
      @JsonKey(fromJson: _nullToString, name: 'status') this.status,
      @JsonKey(name: 'customerName') this.customerName,
      @JsonKey(name: 'cashierName') this.cashierName,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(
          fromJson: _stringToIntNullable,
          toJson: _intToStringNullable,
          name: 'parent_sale_id')
      this.parentSaleId,
      @JsonKey(name: 'sale_mode') this.saleMode,
      this.businessId = 1,
      @JsonKey(name: 'cancelled_at') this.cancelledAt,
      @JsonKey(
          fromJson: _stringToIntNullable,
          toJson: _intToStringNullable,
          name: 'cancelled_by')
      this.cancelledBy,
      @JsonKey(name: 'cancellation_reason') this.cancellationReason,
      @JsonKey(name: 'cancelled_by_name') this.cancelledByName,
      @JsonKey(name: 'notes') this.notes});

  factory _$SaleImpl.fromJson(Map<String, dynamic> json) =>
      _$$SaleImplFromJson(json);

  @override
  final int? id;
  @override
  @JsonKey(
      fromJson: _stringToInt, toJson: _intToStringNullable, name: 'customer_id')
  final int? customerId;
  @override
  @JsonKey(fromJson: _stringToInt, toJson: _intToString, name: 'user_id')
  final int userId;
  @override
  @JsonKey(
      fromJson: _stringToDouble, toJson: _doubleToString, name: 'total_amount')
  final double totalAmount;
  @override
  @JsonKey(fromJson: _nullToString, name: 'payment_method')
  final String? paymentMethod;
  @override
  @JsonKey(fromJson: _nullToString, name: 'status')
  final String? status;
  @override
  @JsonKey(name: 'customerName')
  final String? customerName;
  @override
  @JsonKey(name: 'cashierName')
  final String? cashierName;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(
      fromJson: _stringToIntNullable,
      toJson: _intToStringNullable,
      name: 'parent_sale_id')
  final int? parentSaleId;
  @override
  @JsonKey(name: 'sale_mode')
  final String? saleMode;
  @override
  @JsonKey()
  final int businessId;
// Cancellation fields
  @override
  @JsonKey(name: 'cancelled_at')
  final DateTime? cancelledAt;
  @override
  @JsonKey(
      fromJson: _stringToIntNullable,
      toJson: _intToStringNullable,
      name: 'cancelled_by')
  final int? cancelledBy;
  @override
  @JsonKey(name: 'cancellation_reason')
  final String? cancellationReason;
  @override
  @JsonKey(name: 'cancelled_by_name')
  final String? cancelledByName;
  @override
  @JsonKey(name: 'notes')
  final String? notes;

  @override
  String toString() {
    return 'Sale(id: $id, customerId: $customerId, userId: $userId, totalAmount: $totalAmount, paymentMethod: $paymentMethod, status: $status, customerName: $customerName, cashierName: $cashierName, createdAt: $createdAt, parentSaleId: $parentSaleId, saleMode: $saleMode, businessId: $businessId, cancelledAt: $cancelledAt, cancelledBy: $cancelledBy, cancellationReason: $cancellationReason, cancelledByName: $cancelledByName, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SaleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.customerId, customerId) ||
                other.customerId == customerId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.customerName, customerName) ||
                other.customerName == customerName) &&
            (identical(other.cashierName, cashierName) ||
                other.cashierName == cashierName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.parentSaleId, parentSaleId) ||
                other.parentSaleId == parentSaleId) &&
            (identical(other.saleMode, saleMode) ||
                other.saleMode == saleMode) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.cancelledBy, cancelledBy) ||
                other.cancelledBy == cancelledBy) &&
            (identical(other.cancellationReason, cancellationReason) ||
                other.cancellationReason == cancellationReason) &&
            (identical(other.cancelledByName, cancelledByName) ||
                other.cancelledByName == cancelledByName) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      customerId,
      userId,
      totalAmount,
      paymentMethod,
      status,
      customerName,
      cashierName,
      createdAt,
      parentSaleId,
      saleMode,
      businessId,
      cancelledAt,
      cancelledBy,
      cancellationReason,
      cancelledByName,
      notes);

  /// Create a copy of Sale
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SaleImplCopyWith<_$SaleImpl> get copyWith =>
      __$$SaleImplCopyWithImpl<_$SaleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SaleImplToJson(
      this,
    );
  }
}

abstract class _Sale implements Sale {
  const factory _Sale(
      {final int? id,
      @JsonKey(
          fromJson: _stringToInt,
          toJson: _intToStringNullable,
          name: 'customer_id')
      final int? customerId,
      @JsonKey(fromJson: _stringToInt, toJson: _intToString, name: 'user_id')
      required final int userId,
      @JsonKey(
          fromJson: _stringToDouble,
          toJson: _doubleToString,
          name: 'total_amount')
      required final double totalAmount,
      @JsonKey(fromJson: _nullToString, name: 'payment_method')
      final String? paymentMethod,
      @JsonKey(fromJson: _nullToString, name: 'status') final String? status,
      @JsonKey(name: 'customerName') final String? customerName,
      @JsonKey(name: 'cashierName') final String? cashierName,
      @JsonKey(name: 'created_at') final DateTime? createdAt,
      @JsonKey(
          fromJson: _stringToIntNullable,
          toJson: _intToStringNullable,
          name: 'parent_sale_id')
      final int? parentSaleId,
      @JsonKey(name: 'sale_mode') final String? saleMode,
      final int businessId,
      @JsonKey(name: 'cancelled_at') final DateTime? cancelledAt,
      @JsonKey(
          fromJson: _stringToIntNullable,
          toJson: _intToStringNullable,
          name: 'cancelled_by')
      final int? cancelledBy,
      @JsonKey(name: 'cancellation_reason') final String? cancellationReason,
      @JsonKey(name: 'cancelled_by_name') final String? cancelledByName,
      @JsonKey(name: 'notes') final String? notes}) = _$SaleImpl;

  factory _Sale.fromJson(Map<String, dynamic> json) = _$SaleImpl.fromJson;

  @override
  int? get id;
  @override
  @JsonKey(
      fromJson: _stringToInt, toJson: _intToStringNullable, name: 'customer_id')
  int? get customerId;
  @override
  @JsonKey(fromJson: _stringToInt, toJson: _intToString, name: 'user_id')
  int get userId;
  @override
  @JsonKey(
      fromJson: _stringToDouble, toJson: _doubleToString, name: 'total_amount')
  double get totalAmount;
  @override
  @JsonKey(fromJson: _nullToString, name: 'payment_method')
  String? get paymentMethod;
  @override
  @JsonKey(fromJson: _nullToString, name: 'status')
  String? get status;
  @override
  @JsonKey(name: 'customerName')
  String? get customerName;
  @override
  @JsonKey(name: 'cashierName')
  String? get cashierName;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(
      fromJson: _stringToIntNullable,
      toJson: _intToStringNullable,
      name: 'parent_sale_id')
  int? get parentSaleId;
  @override
  @JsonKey(name: 'sale_mode')
  String? get saleMode;
  @override
  int get businessId; // Cancellation fields
  @override
  @JsonKey(name: 'cancelled_at')
  DateTime? get cancelledAt;
  @override
  @JsonKey(
      fromJson: _stringToIntNullable,
      toJson: _intToStringNullable,
      name: 'cancelled_by')
  int? get cancelledBy;
  @override
  @JsonKey(name: 'cancellation_reason')
  String? get cancellationReason;
  @override
  @JsonKey(name: 'cancelled_by_name')
  String? get cancelledByName;
  @override
  @JsonKey(name: 'notes')
  String? get notes;

  /// Create a copy of Sale
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SaleImplCopyWith<_$SaleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
