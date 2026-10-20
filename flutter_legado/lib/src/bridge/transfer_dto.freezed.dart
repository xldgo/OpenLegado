// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transfer_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TextResponseDto {
  Object get field0;

  @override
  bool operator ==(Object other) {
    final _this = this as TextResponseDto;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TextResponseDto &&
            const DeepCollectionEquality().equals(other.field0, _this.field0));
  }

  @override
  int get hashCode {
    final _this = this as TextResponseDto;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.field0),
    );
  }

  @override
  String toString() {
    final _this = this as TextResponseDto;
    return 'TextResponseDto(field0: ${_this.field0})';
  }
}

/// @nodoc
class $TextResponseDtoCopyWith<$Res> {
  $TextResponseDtoCopyWith(
    TextResponseDto _,
    $Res Function(TextResponseDto) __,
  );
}

/// Adds pattern-matching-related methods to [TextResponseDto].
extension TextResponseDtoPatterns on TextResponseDto {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextResponseDto_Text value)? text,
    TResult Function(TextResponseDto_PlatformAction value)? platformAction,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case TextResponseDto_Text() when text != null:
        return text(_that);
      case TextResponseDto_PlatformAction() when platformAction != null:
        return platformAction(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextResponseDto_Text value) text,
    required TResult Function(TextResponseDto_PlatformAction value)
    platformAction,
  }) {
    final _that = this;
    switch (_that) {
      case TextResponseDto_Text():
        return text(_that);
      case TextResponseDto_PlatformAction():
        return platformAction(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextResponseDto_Text value)? text,
    TResult? Function(TextResponseDto_PlatformAction value)? platformAction,
  }) {
    final _that = this;
    switch (_that) {
      case TextResponseDto_Text() when text != null:
        return text(_that);
      case TextResponseDto_PlatformAction() when platformAction != null:
        return platformAction(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String field0)? text,
    TResult Function(PlatformActionDto field0)? platformAction,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case TextResponseDto_Text() when text != null:
        return text(_that.field0);
      case TextResponseDto_PlatformAction() when platformAction != null:
        return platformAction(_that.field0);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String field0) text,
    required TResult Function(PlatformActionDto field0) platformAction,
  }) {
    final _that = this;
    switch (_that) {
      case TextResponseDto_Text():
        return text(_that.field0);
      case TextResponseDto_PlatformAction():
        return platformAction(_that.field0);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String field0)? text,
    TResult? Function(PlatformActionDto field0)? platformAction,
  }) {
    final _that = this;
    switch (_that) {
      case TextResponseDto_Text() when text != null:
        return text(_that.field0);
      case TextResponseDto_PlatformAction() when platformAction != null:
        return platformAction(_that.field0);
      case _:
        return null;
    }
  }
}

/// @nodoc

class TextResponseDto_Text extends TextResponseDto {
  const TextResponseDto_Text(this.field0) : super._();

  @override
  final String field0;

  /// Create a copy of TextResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TextResponseDto_TextCopyWith<TextResponseDto_Text> get copyWith =>
      _$TextResponseDto_TextCopyWithImpl<TextResponseDto_Text>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TextResponseDto_Text &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, field0);
  }

  @override
  String toString() {
    return 'TextResponseDto.text(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $TextResponseDto_TextCopyWith<$Res>
    implements $TextResponseDtoCopyWith<$Res> {
  factory $TextResponseDto_TextCopyWith(
    TextResponseDto_Text value,
    $Res Function(TextResponseDto_Text) _then,
  ) = _$TextResponseDto_TextCopyWithImpl;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class _$TextResponseDto_TextCopyWithImpl<$Res>
    implements $TextResponseDto_TextCopyWith<$Res> {
  _$TextResponseDto_TextCopyWithImpl(this._self, this._then);

  final TextResponseDto_Text _self;
  final $Res Function(TextResponseDto_Text) _then;

  /// Create a copy of TextResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({Object? field0 = null}) {
    return _then(
      TextResponseDto_Text(
        null == field0
            ? _self.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class TextResponseDto_PlatformAction extends TextResponseDto {
  const TextResponseDto_PlatformAction(this.field0) : super._();

  @override
  final PlatformActionDto field0;

  /// Create a copy of TextResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TextResponseDto_PlatformActionCopyWith<TextResponseDto_PlatformAction>
  get copyWith =>
      _$TextResponseDto_PlatformActionCopyWithImpl<
        TextResponseDto_PlatformAction
      >(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TextResponseDto_PlatformAction &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, field0);
  }

  @override
  String toString() {
    return 'TextResponseDto.platformAction(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $TextResponseDto_PlatformActionCopyWith<$Res>
    implements $TextResponseDtoCopyWith<$Res> {
  factory $TextResponseDto_PlatformActionCopyWith(
    TextResponseDto_PlatformAction value,
    $Res Function(TextResponseDto_PlatformAction) _then,
  ) = _$TextResponseDto_PlatformActionCopyWithImpl;
  @useResult
  $Res call({PlatformActionDto field0});
}

/// @nodoc
class _$TextResponseDto_PlatformActionCopyWithImpl<$Res>
    implements $TextResponseDto_PlatformActionCopyWith<$Res> {
  _$TextResponseDto_PlatformActionCopyWithImpl(this._self, this._then);

  final TextResponseDto_PlatformAction _self;
  final $Res Function(TextResponseDto_PlatformAction) _then;

  /// Create a copy of TextResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({Object? field0 = null}) {
    return _then(
      TextResponseDto_PlatformAction(
        null == field0
            ? _self.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as PlatformActionDto,
      ),
    );
  }
}
