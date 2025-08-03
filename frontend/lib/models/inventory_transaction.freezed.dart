// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inventory_transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

InventoryTransaction _$InventoryTransactionFromJson(Map<String, dynamic> json) {
  return _InventoryTransaction.fromJson(json);
}

/// @nodoc
mixin _$InventoryTransaction {
  String get id => throw _privateConstructorUsedError;
  Product get product => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  String get reference => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this InventoryTransaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InventoryTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InventoryTransactionCopyWith<InventoryTransaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InventoryTransactionCopyWith<$Res> {
  factory $InventoryTransactionCopyWith(InventoryTransaction value,
          $Res Function(InventoryTransaction) then) =
      _$InventoryTransactionCopyWithImpl<$Res, InventoryTransaction>;
  @useResult
  $Res call(
      {String id,
      Product product,
      String type,
      int quantity,
      String reference,
      String? notes,
      DateTime? createdAt,
      DateTime? updatedAt});

  $ProductCopyWith<$Res> get product;
}

/// @nodoc
class _$InventoryTransactionCopyWithImpl<$Res,
        $Val extends InventoryTransaction>
    implements $InventoryTransactionCopyWith<$Res> {
  _$InventoryTransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InventoryTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? product = null,
    Object? type = null,
    Object? quantity = null,
    Object? reference = null,
    Object? notes = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      product: null == product
          ? _value.product
          : product // ignore: cast_nullable_to_non_nullable
              as Product,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      reference: null == reference
          ? _value.reference
          : reference // ignore: cast_nullable_to_non_nullable
              as String,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
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

  /// Create a copy of InventoryTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProductCopyWith<$Res> get product {
    return $ProductCopyWith<$Res>(_value.product, (value) {
      return _then(_value.copyWith(product: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$InventoryTransactionImplCopyWith<$Res>
    implements $InventoryTransactionCopyWith<$Res> {
  factory _$$InventoryTransactionImplCopyWith(_$InventoryTransactionImpl value,
          $Res Function(_$InventoryTransactionImpl) then) =
      __$$InventoryTransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      Product product,
      String type,
      int quantity,
      String reference,
      String? notes,
      DateTime? createdAt,
      DateTime? updatedAt});

  @override
  $ProductCopyWith<$Res> get product;
}

/// @nodoc
class __$$InventoryTransactionImplCopyWithImpl<$Res>
    extends _$InventoryTransactionCopyWithImpl<$Res, _$InventoryTransactionImpl>
    implements _$$InventoryTransactionImplCopyWith<$Res> {
  __$$InventoryTransactionImplCopyWithImpl(_$InventoryTransactionImpl _value,
      $Res Function(_$InventoryTransactionImpl) _then)
      : super(_value, _then);

  /// Create a copy of InventoryTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? product = null,
    Object? type = null,
    Object? quantity = null,
    Object? reference = null,
    Object? notes = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$InventoryTransactionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      product: null == product
          ? _value.product
          : product // ignore: cast_nullable_to_non_nullable
              as Product,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      reference: null == reference
          ? _value.reference
          : reference // ignore: cast_nullable_to_non_nullable
              as String,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
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
class _$InventoryTransactionImpl implements _InventoryTransaction {
  const _$InventoryTransactionImpl(
      {required this.id,
      required this.product,
      required this.type,
      required this.quantity,
      required this.reference,
      this.notes,
      this.createdAt,
      this.updatedAt});

  factory _$InventoryTransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$InventoryTransactionImplFromJson(json);

  @override
  final String id;
  @override
  final Product product;
  @override
  final String type;
  @override
  final int quantity;
  @override
  final String reference;
  @override
  final String? notes;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'InventoryTransaction(id: $id, product: $product, type: $type, quantity: $quantity, reference: $reference, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InventoryTransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.product, product) || other.product == product) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.reference, reference) ||
                other.reference == reference) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, product, type, quantity,
      reference, notes, createdAt, updatedAt);

  /// Create a copy of InventoryTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InventoryTransactionImplCopyWith<_$InventoryTransactionImpl>
      get copyWith =>
          __$$InventoryTransactionImplCopyWithImpl<_$InventoryTransactionImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InventoryTransactionImplToJson(
      this,
    );
  }
}

abstract class _InventoryTransaction implements InventoryTransaction {
  const factory _InventoryTransaction(
      {required final String id,
      required final Product product,
      required final String type,
      required final int quantity,
      required final String reference,
      final String? notes,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$InventoryTransactionImpl;

  factory _InventoryTransaction.fromJson(Map<String, dynamic> json) =
      _$InventoryTransactionImpl.fromJson;

  @override
  String get id;
  @override
  Product get product;
  @override
  String get type;
  @override
  int get quantity;
  @override
  String get reference;
  @override
  String? get notes;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of InventoryTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InventoryTransactionImplCopyWith<_$InventoryTransactionImpl>
      get copyWith => throw _privateConstructorUsedError;
}
