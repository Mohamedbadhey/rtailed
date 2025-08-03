// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'damaged_product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DamagedProduct _$DamagedProductFromJson(Map<String, dynamic> json) {
  return _DamagedProduct.fromJson(json);
}

/// @nodoc
mixin _$DamagedProduct {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'product_id')
  int get productId => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  @JsonKey(name: 'damage_type')
  DamageType get damageType => throw _privateConstructorUsedError;
  @JsonKey(name: 'damage_date')
  DateTime get damageDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'damage_reason')
  String? get damageReason => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'estimated_loss',
      fromJson: _stringToDouble,
      toJson: _doubleToStringNullable)
  double? get estimatedLoss => throw _privateConstructorUsedError;
  @JsonKey(name: 'reported_by')
  int get reportedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'product_name')
  String? get productName => throw _privateConstructorUsedError;
  @JsonKey(name: 'product_sku')
  String? get productSku => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'product_cost',
      fromJson: _stringToDoubleNullable,
      toJson: _doubleToStringNullable)
  double? get productCost => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'product_price',
      fromJson: _stringToDoubleNullable,
      toJson: _doubleToStringNullable)
  double? get productPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'category_name')
  String? get categoryName => throw _privateConstructorUsedError;
  @JsonKey(name: 'reported_by_name')
  String? get reportedByName => throw _privateConstructorUsedError;

  /// Serializes this DamagedProduct to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DamagedProduct
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DamagedProductCopyWith<DamagedProduct> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DamagedProductCopyWith<$Res> {
  factory $DamagedProductCopyWith(
          DamagedProduct value, $Res Function(DamagedProduct) then) =
      _$DamagedProductCopyWithImpl<$Res, DamagedProduct>;
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'product_id') int productId,
      int quantity,
      @JsonKey(name: 'damage_type') DamageType damageType,
      @JsonKey(name: 'damage_date') DateTime damageDate,
      @JsonKey(name: 'damage_reason') String? damageReason,
      @JsonKey(
          name: 'estimated_loss',
          fromJson: _stringToDouble,
          toJson: _doubleToStringNullable)
      double? estimatedLoss,
      @JsonKey(name: 'reported_by') int reportedBy,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'product_name') String? productName,
      @JsonKey(name: 'product_sku') String? productSku,
      @JsonKey(
          name: 'product_cost',
          fromJson: _stringToDoubleNullable,
          toJson: _doubleToStringNullable)
      double? productCost,
      @JsonKey(
          name: 'product_price',
          fromJson: _stringToDoubleNullable,
          toJson: _doubleToStringNullable)
      double? productPrice,
      @JsonKey(name: 'category_name') String? categoryName,
      @JsonKey(name: 'reported_by_name') String? reportedByName});
}

/// @nodoc
class _$DamagedProductCopyWithImpl<$Res, $Val extends DamagedProduct>
    implements $DamagedProductCopyWith<$Res> {
  _$DamagedProductCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DamagedProduct
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? quantity = null,
    Object? damageType = null,
    Object? damageDate = null,
    Object? damageReason = freezed,
    Object? estimatedLoss = freezed,
    Object? reportedBy = null,
    Object? createdAt = null,
    Object? productName = freezed,
    Object? productSku = freezed,
    Object? productCost = freezed,
    Object? productPrice = freezed,
    Object? categoryName = freezed,
    Object? reportedByName = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      productId: null == productId
          ? _value.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as int,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      damageType: null == damageType
          ? _value.damageType
          : damageType // ignore: cast_nullable_to_non_nullable
              as DamageType,
      damageDate: null == damageDate
          ? _value.damageDate
          : damageDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      damageReason: freezed == damageReason
          ? _value.damageReason
          : damageReason // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedLoss: freezed == estimatedLoss
          ? _value.estimatedLoss
          : estimatedLoss // ignore: cast_nullable_to_non_nullable
              as double?,
      reportedBy: null == reportedBy
          ? _value.reportedBy
          : reportedBy // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      productName: freezed == productName
          ? _value.productName
          : productName // ignore: cast_nullable_to_non_nullable
              as String?,
      productSku: freezed == productSku
          ? _value.productSku
          : productSku // ignore: cast_nullable_to_non_nullable
              as String?,
      productCost: freezed == productCost
          ? _value.productCost
          : productCost // ignore: cast_nullable_to_non_nullable
              as double?,
      productPrice: freezed == productPrice
          ? _value.productPrice
          : productPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      categoryName: freezed == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      reportedByName: freezed == reportedByName
          ? _value.reportedByName
          : reportedByName // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DamagedProductImplCopyWith<$Res>
    implements $DamagedProductCopyWith<$Res> {
  factory _$$DamagedProductImplCopyWith(_$DamagedProductImpl value,
          $Res Function(_$DamagedProductImpl) then) =
      __$$DamagedProductImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'product_id') int productId,
      int quantity,
      @JsonKey(name: 'damage_type') DamageType damageType,
      @JsonKey(name: 'damage_date') DateTime damageDate,
      @JsonKey(name: 'damage_reason') String? damageReason,
      @JsonKey(
          name: 'estimated_loss',
          fromJson: _stringToDouble,
          toJson: _doubleToStringNullable)
      double? estimatedLoss,
      @JsonKey(name: 'reported_by') int reportedBy,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'product_name') String? productName,
      @JsonKey(name: 'product_sku') String? productSku,
      @JsonKey(
          name: 'product_cost',
          fromJson: _stringToDoubleNullable,
          toJson: _doubleToStringNullable)
      double? productCost,
      @JsonKey(
          name: 'product_price',
          fromJson: _stringToDoubleNullable,
          toJson: _doubleToStringNullable)
      double? productPrice,
      @JsonKey(name: 'category_name') String? categoryName,
      @JsonKey(name: 'reported_by_name') String? reportedByName});
}

/// @nodoc
class __$$DamagedProductImplCopyWithImpl<$Res>
    extends _$DamagedProductCopyWithImpl<$Res, _$DamagedProductImpl>
    implements _$$DamagedProductImplCopyWith<$Res> {
  __$$DamagedProductImplCopyWithImpl(
      _$DamagedProductImpl _value, $Res Function(_$DamagedProductImpl) _then)
      : super(_value, _then);

  /// Create a copy of DamagedProduct
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? quantity = null,
    Object? damageType = null,
    Object? damageDate = null,
    Object? damageReason = freezed,
    Object? estimatedLoss = freezed,
    Object? reportedBy = null,
    Object? createdAt = null,
    Object? productName = freezed,
    Object? productSku = freezed,
    Object? productCost = freezed,
    Object? productPrice = freezed,
    Object? categoryName = freezed,
    Object? reportedByName = freezed,
  }) {
    return _then(_$DamagedProductImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      productId: null == productId
          ? _value.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as int,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      damageType: null == damageType
          ? _value.damageType
          : damageType // ignore: cast_nullable_to_non_nullable
              as DamageType,
      damageDate: null == damageDate
          ? _value.damageDate
          : damageDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      damageReason: freezed == damageReason
          ? _value.damageReason
          : damageReason // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedLoss: freezed == estimatedLoss
          ? _value.estimatedLoss
          : estimatedLoss // ignore: cast_nullable_to_non_nullable
              as double?,
      reportedBy: null == reportedBy
          ? _value.reportedBy
          : reportedBy // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      productName: freezed == productName
          ? _value.productName
          : productName // ignore: cast_nullable_to_non_nullable
              as String?,
      productSku: freezed == productSku
          ? _value.productSku
          : productSku // ignore: cast_nullable_to_non_nullable
              as String?,
      productCost: freezed == productCost
          ? _value.productCost
          : productCost // ignore: cast_nullable_to_non_nullable
              as double?,
      productPrice: freezed == productPrice
          ? _value.productPrice
          : productPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      categoryName: freezed == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      reportedByName: freezed == reportedByName
          ? _value.reportedByName
          : reportedByName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DamagedProductImpl implements _DamagedProduct {
  const _$DamagedProductImpl(
      {required this.id,
      @JsonKey(name: 'product_id') required this.productId,
      required this.quantity,
      @JsonKey(name: 'damage_type') required this.damageType,
      @JsonKey(name: 'damage_date') required this.damageDate,
      @JsonKey(name: 'damage_reason') this.damageReason,
      @JsonKey(
          name: 'estimated_loss',
          fromJson: _stringToDouble,
          toJson: _doubleToStringNullable)
      this.estimatedLoss,
      @JsonKey(name: 'reported_by') required this.reportedBy,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'product_name') this.productName,
      @JsonKey(name: 'product_sku') this.productSku,
      @JsonKey(
          name: 'product_cost',
          fromJson: _stringToDoubleNullable,
          toJson: _doubleToStringNullable)
      this.productCost,
      @JsonKey(
          name: 'product_price',
          fromJson: _stringToDoubleNullable,
          toJson: _doubleToStringNullable)
      this.productPrice,
      @JsonKey(name: 'category_name') this.categoryName,
      @JsonKey(name: 'reported_by_name') this.reportedByName});

  factory _$DamagedProductImpl.fromJson(Map<String, dynamic> json) =>
      _$$DamagedProductImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'product_id')
  final int productId;
  @override
  final int quantity;
  @override
  @JsonKey(name: 'damage_type')
  final DamageType damageType;
  @override
  @JsonKey(name: 'damage_date')
  final DateTime damageDate;
  @override
  @JsonKey(name: 'damage_reason')
  final String? damageReason;
  @override
  @JsonKey(
      name: 'estimated_loss',
      fromJson: _stringToDouble,
      toJson: _doubleToStringNullable)
  final double? estimatedLoss;
  @override
  @JsonKey(name: 'reported_by')
  final int reportedBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'product_name')
  final String? productName;
  @override
  @JsonKey(name: 'product_sku')
  final String? productSku;
  @override
  @JsonKey(
      name: 'product_cost',
      fromJson: _stringToDoubleNullable,
      toJson: _doubleToStringNullable)
  final double? productCost;
  @override
  @JsonKey(
      name: 'product_price',
      fromJson: _stringToDoubleNullable,
      toJson: _doubleToStringNullable)
  final double? productPrice;
  @override
  @JsonKey(name: 'category_name')
  final String? categoryName;
  @override
  @JsonKey(name: 'reported_by_name')
  final String? reportedByName;

  @override
  String toString() {
    return 'DamagedProduct(id: $id, productId: $productId, quantity: $quantity, damageType: $damageType, damageDate: $damageDate, damageReason: $damageReason, estimatedLoss: $estimatedLoss, reportedBy: $reportedBy, createdAt: $createdAt, productName: $productName, productSku: $productSku, productCost: $productCost, productPrice: $productPrice, categoryName: $categoryName, reportedByName: $reportedByName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DamagedProductImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.damageType, damageType) ||
                other.damageType == damageType) &&
            (identical(other.damageDate, damageDate) ||
                other.damageDate == damageDate) &&
            (identical(other.damageReason, damageReason) ||
                other.damageReason == damageReason) &&
            (identical(other.estimatedLoss, estimatedLoss) ||
                other.estimatedLoss == estimatedLoss) &&
            (identical(other.reportedBy, reportedBy) ||
                other.reportedBy == reportedBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.productName, productName) ||
                other.productName == productName) &&
            (identical(other.productSku, productSku) ||
                other.productSku == productSku) &&
            (identical(other.productCost, productCost) ||
                other.productCost == productCost) &&
            (identical(other.productPrice, productPrice) ||
                other.productPrice == productPrice) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.reportedByName, reportedByName) ||
                other.reportedByName == reportedByName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      productId,
      quantity,
      damageType,
      damageDate,
      damageReason,
      estimatedLoss,
      reportedBy,
      createdAt,
      productName,
      productSku,
      productCost,
      productPrice,
      categoryName,
      reportedByName);

  /// Create a copy of DamagedProduct
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DamagedProductImplCopyWith<_$DamagedProductImpl> get copyWith =>
      __$$DamagedProductImplCopyWithImpl<_$DamagedProductImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DamagedProductImplToJson(
      this,
    );
  }
}

abstract class _DamagedProduct implements DamagedProduct {
  const factory _DamagedProduct(
          {required final int id,
          @JsonKey(name: 'product_id') required final int productId,
          required final int quantity,
          @JsonKey(name: 'damage_type') required final DamageType damageType,
          @JsonKey(name: 'damage_date') required final DateTime damageDate,
          @JsonKey(name: 'damage_reason') final String? damageReason,
          @JsonKey(
              name: 'estimated_loss',
              fromJson: _stringToDouble,
              toJson: _doubleToStringNullable)
          final double? estimatedLoss,
          @JsonKey(name: 'reported_by') required final int reportedBy,
          @JsonKey(name: 'created_at') required final DateTime createdAt,
          @JsonKey(name: 'product_name') final String? productName,
          @JsonKey(name: 'product_sku') final String? productSku,
          @JsonKey(
              name: 'product_cost',
              fromJson: _stringToDoubleNullable,
              toJson: _doubleToStringNullable)
          final double? productCost,
          @JsonKey(
              name: 'product_price',
              fromJson: _stringToDoubleNullable,
              toJson: _doubleToStringNullable)
          final double? productPrice,
          @JsonKey(name: 'category_name') final String? categoryName,
          @JsonKey(name: 'reported_by_name') final String? reportedByName}) =
      _$DamagedProductImpl;

  factory _DamagedProduct.fromJson(Map<String, dynamic> json) =
      _$DamagedProductImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'product_id')
  int get productId;
  @override
  int get quantity;
  @override
  @JsonKey(name: 'damage_type')
  DamageType get damageType;
  @override
  @JsonKey(name: 'damage_date')
  DateTime get damageDate;
  @override
  @JsonKey(name: 'damage_reason')
  String? get damageReason;
  @override
  @JsonKey(
      name: 'estimated_loss',
      fromJson: _stringToDouble,
      toJson: _doubleToStringNullable)
  double? get estimatedLoss;
  @override
  @JsonKey(name: 'reported_by')
  int get reportedBy;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'product_name')
  String? get productName;
  @override
  @JsonKey(name: 'product_sku')
  String? get productSku;
  @override
  @JsonKey(
      name: 'product_cost',
      fromJson: _stringToDoubleNullable,
      toJson: _doubleToStringNullable)
  double? get productCost;
  @override
  @JsonKey(
      name: 'product_price',
      fromJson: _stringToDoubleNullable,
      toJson: _doubleToStringNullable)
  double? get productPrice;
  @override
  @JsonKey(name: 'category_name')
  String? get categoryName;
  @override
  @JsonKey(name: 'reported_by_name')
  String? get reportedByName;

  /// Create a copy of DamagedProduct
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DamagedProductImplCopyWith<_$DamagedProductImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
