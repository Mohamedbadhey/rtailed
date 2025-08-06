import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:retail_management/utils/type_converter.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required int id,
    required String username,
    required String email,
    required String role,
    @JsonKey(name: 'business_id') int? businessId,
    @JsonKey(name: 'is_active', fromJson: TypeConverter.safeToBool) @Default(false) bool isActive,
    @JsonKey(name: 'last_login') DateTime? lastLogin,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'language') @Default('English') String language,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
} 