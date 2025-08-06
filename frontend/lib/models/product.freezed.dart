// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Product _$ProductFromJson(Map<String, dynamic> json) {
  return _Product.fromJson(json);
}

/// @nodoc
mixin _$Product {
  int? get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get sku => throw _privateConstructorUsedError;
  String? get barcode => throw _privateConstructorUsedError;
  int? get categoryId => throw _privateConstructorUsedError;
  String? get categoryName => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  double get price => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToStringNullable)
  double? get wholesalePrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'cost_price', fromJson: _stringToDouble, toJson: _doubleToString)
  double get costPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'stock_quantity', fromJson: _stringToInt, toJson: _intToString)
  int get stockQuantity => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'damaged_quantity', fromJson: _stringToInt, toJson: _intToString)
  int get damagedQuantity => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'low_stock_threshold', fromJson: _stringToInt, toJson: _intToString)
  int get lowStockThreshold => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;
  int get businessId => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Product to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductCopyWith<Product> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductCopyWith<$Res> {
  factory $ProductCopyWith(Product value, $Res Function(Product) then) =
      _$ProductCopyWithImpl<$Res, Product>;
  @useResult
  $Res call(
      {int? id,
      String name,
      String? description,
      String? sku,
      String? barcode,
      int? categoryId,
      String? categoryName,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString) double price,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToStringNullable)
      double? wholesalePrice,
      @JsonKey(
          name: 'cost_price',
          fromJson: _stringToDouble,
          toJson: _doubleToString)
      double costPrice,
      @JsonKey(
          name: 'stock_quantity', fromJson: _stringToInt, toJson: _intToString)
      int stockQuantity,
      @JsonKey(
          name: 'damaged_quantity',
          fromJson: _stringToInt,
          toJson: _intToString)
      int damagedQuantity,
      @JsonKey(
          name: 'low_stock_threshold',
          fromJson: _stringToInt,
          toJson: _intToString)
      int lowStockThreshold,
      @JsonKey(name: 'image_url') String? imageUrl,
      int businessId,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$ProductCopyWithImpl<$Res, $Val extends Product>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? sku = freezed,
    Object? barcode = freezed,
    Object? categoryId = freezed,
    Object? categoryName = freezed,
    Object? price = null,
    Object? wholesalePrice = freezed,
    Object? costPrice = null,
    Object? stockQuantity = null,
    Object? damagedQuantity = null,
    Object? lowStockThreshold = null,
    Object? imageUrl = freezed,
    Object? businessId = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      sku: freezed == sku
          ? _value.sku
          : sku // ignore: cast_nullable_to_non_nullable
              as String?,
      barcode: freezed == barcode
          ? _value.barcode
          : barcode // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as int?,
      categoryName: freezed == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      wholesalePrice: freezed == wholesalePrice
          ? _value.wholesalePrice
          : wholesalePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      costPrice: null == costPrice
          ? _value.costPrice
          : costPrice // ignore: cast_nullable_to_non_nullable
              as double,
      stockQuantity: null == stockQuantity
          ? _value.stockQuantity
          : stockQuantity // ignore: cast_nullable_to_non_nullable
              as int,
      damagedQuantity: null == damagedQuantity
          ? _value.damagedQuantity
          : damagedQuantity // ignore: cast_nullable_to_non_nullable
              as int,
      lowStockThreshold: null == lowStockThreshold
          ? _value.lowStockThreshold
          : lowStockThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      businessId: null == businessId
          ? _value.businessId
          : businessId // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ProductImplCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$$ProductImplCopyWith(
          _$ProductImpl value, $Res Function(_$ProductImpl) then) =
      __$$ProductImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? id,
      String name,
      String? description,
      String? sku,
      String? barcode,
      int? categoryId,
      String? categoryName,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString) double price,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToStringNullable)
      double? wholesalePrice,
      @JsonKey(
          name: 'cost_price',
          fromJson: _stringToDouble,
          toJson: _doubleToString)
      double costPrice,
      @JsonKey(
          name: 'stock_quantity', fromJson: _stringToInt, toJson: _intToString)
      int stockQuantity,
      @JsonKey(
          name: 'damaged_quantity',
          fromJson: _stringToInt,
          toJson: _intToString)
      int damagedQuantity,
      @JsonKey(
          name: 'low_stock_threshold',
          fromJson: _stringToInt,
          toJson: _intToString)
      int lowStockThreshold,
      @JsonKey(name: 'image_url') String? imageUrl,
      int businessId,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$ProductImplCopyWithImpl<$Res>
    extends _$ProductCopyWithImpl<$Res, _$ProductImpl>
    implements _$$ProductImplCopyWith<$Res> {
  __$$ProductImplCopyWithImpl(
      _$ProductImpl _value, $Res Function(_$ProductImpl) _then)
      : super(_value, _then);

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? sku = freezed,
    Object? barcode = freezed,
    Object? categoryId = freezed,
    Object? categoryName = freezed,
    Object? price = null,
    Object? wholesalePrice = freezed,
    Object? costPrice = null,
    Object? stockQuantity = null,
    Object? damagedQuantity = null,
    Object? lowStockThreshold = null,
    Object? imageUrl = freezed,
    Object? businessId = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ProductImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      sku: freezed == sku
          ? _value.sku
          : sku // ignore: cast_nullable_to_non_nullable
              as String?,
      barcode: freezed == barcode
          ? _value.barcode
          : barcode // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as int?,
      categoryName: freezed == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      wholesalePrice: freezed == wholesalePrice
          ? _value.wholesalePrice
          : wholesalePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      costPrice: null == costPrice
          ? _value.costPrice
          : costPrice // ignore: cast_nullable_to_non_nullable
              as double,
      stockQuantity: null == stockQuantity
          ? _value.stockQuantity
          : stockQuantity // ignore: cast_nullable_to_non_nullable
              as int,
      damagedQuantity: null == damagedQuantity
          ? _value.damagedQuantity
          : damagedQuantity // ignore: cast_nullable_to_non_nullable
              as int,
      lowStockThreshold: null == lowStockThreshold
          ? _value.lowStockThreshold
          : lowStockThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      businessId: null == businessId
          ? _value.businessId
          : businessId // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductImpl implements _Product {
  const _$ProductImpl(
      {this.id,
      required this.name,
      this.description,
      this.sku,
      this.barcode,
      this.categoryId,
      this.categoryName,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      required this.price,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToStringNullable)
      this.wholesalePrice,
      @JsonKey(
          name: 'cost_price',
          fromJson: _stringToDouble,
          toJson: _doubleToString)
      required this.costPrice,
      @JsonKey(
          name: 'stock_quantity', fromJson: _stringToInt, toJson: _intToString)
      required this.stockQuantity,
      @JsonKey(
          name: 'damaged_quantity',
          fromJson: _stringToInt,
          toJson: _intToString)
      required this.damagedQuantity,
      @JsonKey(
          name: 'low_stock_threshold',
          fromJson: _stringToInt,
          toJson: _intToString)
      required this.lowStockThreshold,
      @JsonKey(name: 'image_url') this.imageUrl,
      this.businessId = 1,
      this.createdAt,
      this.updatedAt});

  factory _$ProductImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductImplFromJson(json);

  @override
  final int? id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final String? sku;
  @override
  final String? barcode;
  @override
  final int? categoryId;
  @override
  final String? categoryName;
  @override
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  final double price;
  @override
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToStringNullable)
  final double? wholesalePrice;
  @override
  @JsonKey(
      name: 'cost_price', fromJson: _stringToDouble, toJson: _doubleToString)
  final double costPrice;
  @override
  @JsonKey(name: 'stock_quantity', fromJson: _stringToInt, toJson: _intToString)
  final int stockQuantity;
  @override
  @JsonKey(
      name: 'damaged_quantity', fromJson: _stringToInt, toJson: _intToString)
  final int damagedQuantity;
  @override
  @JsonKey(
      name: 'low_stock_threshold', fromJson: _stringToInt, toJson: _intToString)
  final int lowStockThreshold;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @override
  @JsonKey()
  final int businessId;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Product(id: $id, name: $name, description: $description, sku: $sku, barcode: $barcode, categoryId: $categoryId, categoryName: $categoryName, price: $price, wholesalePrice: $wholesalePrice, costPrice: $costPrice, stockQuantity: $stockQuantity, damagedQuantity: $damagedQuantity, lowStockThreshold: $lowStockThreshold, imageUrl: $imageUrl, businessId: $businessId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.sku, sku) || other.sku == sku) &&
            (identical(other.barcode, barcode) || other.barcode == barcode) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.wholesalePrice, wholesalePrice) ||
                other.wholesalePrice == wholesalePrice) &&
            (identical(other.costPrice, costPrice) ||
                other.costPrice == costPrice) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            (identical(other.damagedQuantity, damagedQuantity) ||
                other.damagedQuantity == damagedQuantity) &&
            (identical(other.lowStockThreshold, lowStockThreshold) ||
                other.lowStockThreshold == lowStockThreshold) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      sku,
      barcode,
      categoryId,
      categoryName,
      price,
      wholesalePrice,
      costPrice,
      stockQuantity,
      damagedQuantity,
      lowStockThreshold,
      imageUrl,
      businessId,
      createdAt,
      updatedAt);

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductImplCopyWith<_$ProductImpl> get copyWith =>
      __$$ProductImplCopyWithImpl<_$ProductImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductImplToJson(
      this,
    );
  }
}

abstract class _Product implements Product {
  const factory _Product(
      {final int? id,
      required final String name,
      final String? description,
      final String? sku,
      final String? barcode,
      final int? categoryId,
      final String? categoryName,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
      required final double price,
      @JsonKey(fromJson: _stringToDouble, toJson: _doubleToStringNullable)
      final double? wholesalePrice,
      @JsonKey(
          name: 'cost_price',
          fromJson: _stringToDouble,
          toJson: _doubleToString)
      required final double costPrice,
      @JsonKey(
          name: 'stock_quantity', fromJson: _stringToInt, toJson: _intToString)
      required final int stockQuantity,
      @JsonKey(
          name: 'damaged_quantity',
          fromJson: _stringToInt,
          toJson: _intToString)
      required final int damagedQuantity,
      @JsonKey(
          name: 'low_stock_threshold',
          fromJson: _stringToInt,
          toJson: _intToString)
      required final int lowStockThreshold,
      @JsonKey(name: 'image_url') final String? imageUrl,
      final int businessId,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$ProductImpl;

  factory _Product.fromJson(Map<String, dynamic> json) = _$ProductImpl.fromJson;

  @override
  int? get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  String? get sku;
  @override
  String? get barcode;
  @override
  int? get categoryId;
  @override
  String? get categoryName;
  @override
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToString)
  double get price;
  @override
  @JsonKey(fromJson: _stringToDouble, toJson: _doubleToStringNullable)
  double? get wholesalePrice;
  @override
  @JsonKey(
      name: 'cost_price', fromJson: _stringToDouble, toJson: _doubleToString)
  double get costPrice;
  @override
  @JsonKey(name: 'stock_quantity', fromJson: _stringToInt, toJson: _intToString)
  int get stockQuantity;
  @override
  @JsonKey(
      name: 'damaged_quantity', fromJson: _stringToInt, toJson: _intToString)
  int get damagedQuantity;
  @override
  @JsonKey(
      name: 'low_stock_threshold', fromJson: _stringToInt, toJson: _intToString)
  int get lowStockThreshold;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;
  @override
  int get businessId;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductImplCopyWith<_$ProductImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
