// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'change_source_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChangeSourceState {
  /// 匹配到的候选书源列表（Rust 已按评分降序排序，UI 直接渲染）
  List<SourceMatch> get results;

  /// 是否正在搜索
  bool get isLoading;

  /// 错误信息
  String? get error;

  /// 正在应用切换的书源 URL（null 表示无切换进行中）
  String? get applyingUrl;

  /// 本轮搜索的书源数量（仅 isLoading 时非 null；体检 U1 等待反馈，
  /// T6 流式 API 落地前暂以「源数量+时长」替代逐源 x/y 进度）
  int? get searchingCount;

  /// 已完成书源数（T6 流式：批次 finished_count，搜索中非 null）
  int? get progressFinished;

  /// 参与搜索的书源总数（T6 流式：批次 total_count，权威值来自 Rust）
  int? get progressTotal;

  /// 最后完成的书源名（2026-09-24 换源感知等待：批次 source_name，
  /// 对齐上游 changeSourceProgress 进度串「结果 N，当前进度 M/K: 源名」，
  /// upstream values-zh/strings.xml:1457）
  String? get progressLastSourceName;

  /// Create a copy of ChangeSourceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChangeSourceStateCopyWith<ChangeSourceState> get copyWith =>
      _$ChangeSourceStateCopyWithImpl<ChangeSourceState>(
        this as ChangeSourceState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as ChangeSourceState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChangeSourceState &&
            const DeepCollectionEquality().equals(
              other.results,
              _this.results,
            ) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.applyingUrl, _this.applyingUrl) ||
                other.applyingUrl == _this.applyingUrl) &&
            (identical(other.searchingCount, _this.searchingCount) ||
                other.searchingCount == _this.searchingCount) &&
            (identical(other.progressFinished, _this.progressFinished) ||
                other.progressFinished == _this.progressFinished) &&
            (identical(other.progressTotal, _this.progressTotal) ||
                other.progressTotal == _this.progressTotal) &&
            (identical(
                  other.progressLastSourceName,
                  _this.progressLastSourceName,
                ) ||
                other.progressLastSourceName == _this.progressLastSourceName));
  }

  @override
  int get hashCode {
    final _this = this as ChangeSourceState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.results),
      _this.isLoading,
      _this.error,
      _this.applyingUrl,
      _this.searchingCount,
      _this.progressFinished,
      _this.progressTotal,
      _this.progressLastSourceName,
    );
  }

  @override
  String toString() {
    final _this = this as ChangeSourceState;
    return 'ChangeSourceState(results: ${_this.results}, isLoading: ${_this.isLoading}, error: ${_this.error}, applyingUrl: ${_this.applyingUrl}, searchingCount: ${_this.searchingCount}, progressFinished: ${_this.progressFinished}, progressTotal: ${_this.progressTotal}, progressLastSourceName: ${_this.progressLastSourceName})';
  }
}

/// @nodoc
abstract mixin class $ChangeSourceStateCopyWith<$Res> {
  factory $ChangeSourceStateCopyWith(
    ChangeSourceState value,
    $Res Function(ChangeSourceState) _then,
  ) = _$ChangeSourceStateCopyWithImpl;
  @useResult
  $Res call({
    List<SourceMatch> results,
    bool isLoading,
    String? error,
    String? applyingUrl,
    int? searchingCount,
    int? progressFinished,
    int? progressTotal,
    String? progressLastSourceName,
  });
}

/// @nodoc
class _$ChangeSourceStateCopyWithImpl<$Res>
    implements $ChangeSourceStateCopyWith<$Res> {
  _$ChangeSourceStateCopyWithImpl(this._self, this._then);

  final ChangeSourceState _self;
  final $Res Function(ChangeSourceState) _then;

  /// Create a copy of ChangeSourceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? results = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? applyingUrl = freezed,
    Object? searchingCount = freezed,
    Object? progressFinished = freezed,
    Object? progressTotal = freezed,
    Object? progressLastSourceName = freezed,
  }) {
    return _then(
      ChangeSourceState(
        results: null == results
            ? _self.results
            : results // ignore: cast_nullable_to_non_nullable
                  as List<SourceMatch>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        applyingUrl: freezed == applyingUrl
            ? _self.applyingUrl
            : applyingUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        searchingCount: freezed == searchingCount
            ? _self.searchingCount
            : searchingCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        progressFinished: freezed == progressFinished
            ? _self.progressFinished
            : progressFinished // ignore: cast_nullable_to_non_nullable
                  as int?,
        progressTotal: freezed == progressTotal
            ? _self.progressTotal
            : progressTotal // ignore: cast_nullable_to_non_nullable
                  as int?,
        progressLastSourceName: freezed == progressLastSourceName
            ? _self.progressLastSourceName
            : progressLastSourceName // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [ChangeSourceState].
extension ChangeSourceStatePatterns on ChangeSourceState {
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
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ChangeSourceState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChangeSourceState() when $default != null:
        return $default(_that);
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
  TResult map<TResult extends Object?>(
    TResult Function(_ChangeSourceState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeSourceState():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
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
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ChangeSourceState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeSourceState() when $default != null:
        return $default(_that);
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
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
      List<SourceMatch> results,
      bool isLoading,
      String? error,
      String? applyingUrl,
      int? searchingCount,
      int? progressFinished,
      int? progressTotal,
      String? progressLastSourceName,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChangeSourceState() when $default != null:
        return $default(
          _that.results,
          _that.isLoading,
          _that.error,
          _that.applyingUrl,
          _that.searchingCount,
          _that.progressFinished,
          _that.progressTotal,
          _that.progressLastSourceName,
        );
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
  TResult when<TResult extends Object?>(
    TResult Function(
      List<SourceMatch> results,
      bool isLoading,
      String? error,
      String? applyingUrl,
      int? searchingCount,
      int? progressFinished,
      int? progressTotal,
      String? progressLastSourceName,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeSourceState():
        return $default(
          _that.results,
          _that.isLoading,
          _that.error,
          _that.applyingUrl,
          _that.searchingCount,
          _that.progressFinished,
          _that.progressTotal,
          _that.progressLastSourceName,
        );
      case _:
        throw StateError('Unexpected subclass');
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
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
      List<SourceMatch> results,
      bool isLoading,
      String? error,
      String? applyingUrl,
      int? searchingCount,
      int? progressFinished,
      int? progressTotal,
      String? progressLastSourceName,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeSourceState() when $default != null:
        return $default(
          _that.results,
          _that.isLoading,
          _that.error,
          _that.applyingUrl,
          _that.searchingCount,
          _that.progressFinished,
          _that.progressTotal,
          _that.progressLastSourceName,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ChangeSourceState implements ChangeSourceState {
  const _ChangeSourceState({
    List<SourceMatch> results = const [],
    this.isLoading = false,
    this.error,
    this.applyingUrl,
    this.searchingCount,
    this.progressFinished,
    this.progressTotal,
    this.progressLastSourceName,
  }) : _results = results;

  /// 匹配到的候选书源列表（Rust 已按评分降序排序，UI 直接渲染）
  final List<SourceMatch> _results;

  /// 匹配到的候选书源列表（Rust 已按评分降序排序，UI 直接渲染）
  @override
  @JsonKey()
  List<SourceMatch> get results {
    if (_results is EqualUnmodifiableListView) return _results;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_results);
  }

  /// 是否正在搜索
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误信息
  @override
  final String? error;

  /// 正在应用切换的书源 URL（null 表示无切换进行中）
  @override
  final String? applyingUrl;

  /// 本轮搜索的书源数量（仅 isLoading 时非 null；体检 U1 等待反馈，
  /// T6 流式 API 落地前暂以「源数量+时长」替代逐源 x/y 进度）
  @override
  final int? searchingCount;

  /// 已完成书源数（T6 流式：批次 finished_count，搜索中非 null）
  @override
  final int? progressFinished;

  /// 参与搜索的书源总数（T6 流式：批次 total_count，权威值来自 Rust）
  @override
  final int? progressTotal;

  /// 最后完成的书源名（2026-09-24 换源感知等待：批次 source_name，
  /// 对齐上游 changeSourceProgress 进度串「结果 N，当前进度 M/K: 源名」，
  /// upstream values-zh/strings.xml:1457）
  @override
  final String? progressLastSourceName;

  /// Create a copy of ChangeSourceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChangeSourceStateCopyWith<_ChangeSourceState> get copyWith =>
      __$ChangeSourceStateCopyWithImpl<_ChangeSourceState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChangeSourceState &&
            const DeepCollectionEquality().equals(other.results, _results) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.applyingUrl, applyingUrl) ||
                other.applyingUrl == applyingUrl) &&
            (identical(other.searchingCount, searchingCount) ||
                other.searchingCount == searchingCount) &&
            (identical(other.progressFinished, progressFinished) ||
                other.progressFinished == progressFinished) &&
            (identical(other.progressTotal, progressTotal) ||
                other.progressTotal == progressTotal) &&
            (identical(other.progressLastSourceName, progressLastSourceName) ||
                other.progressLastSourceName == progressLastSourceName));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_results),
      isLoading,
      error,
      applyingUrl,
      searchingCount,
      progressFinished,
      progressTotal,
      progressLastSourceName,
    );
  }

  @override
  String toString() {
    return 'ChangeSourceState(results: $results, isLoading: $isLoading, error: $error, applyingUrl: $applyingUrl, searchingCount: $searchingCount, progressFinished: $progressFinished, progressTotal: $progressTotal, progressLastSourceName: $progressLastSourceName)';
  }
}

/// @nodoc
abstract mixin class _$ChangeSourceStateCopyWith<$Res>
    implements $ChangeSourceStateCopyWith<$Res> {
  factory _$ChangeSourceStateCopyWith(
    _ChangeSourceState value,
    $Res Function(_ChangeSourceState) _then,
  ) = __$ChangeSourceStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<SourceMatch> results,
    bool isLoading,
    String? error,
    String? applyingUrl,
    int? searchingCount,
    int? progressFinished,
    int? progressTotal,
    String? progressLastSourceName,
  });
}

/// @nodoc
class __$ChangeSourceStateCopyWithImpl<$Res>
    implements _$ChangeSourceStateCopyWith<$Res> {
  __$ChangeSourceStateCopyWithImpl(this._self, this._then);

  final _ChangeSourceState _self;
  final $Res Function(_ChangeSourceState) _then;

  /// Create a copy of ChangeSourceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? results = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? applyingUrl = freezed,
    Object? searchingCount = freezed,
    Object? progressFinished = freezed,
    Object? progressTotal = freezed,
    Object? progressLastSourceName = freezed,
  }) {
    return _then(
      _ChangeSourceState(
        results: null == results
            ? _self._results
            : results // ignore: cast_nullable_to_non_nullable
                  as List<SourceMatch>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        applyingUrl: freezed == applyingUrl
            ? _self.applyingUrl
            : applyingUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        searchingCount: freezed == searchingCount
            ? _self.searchingCount
            : searchingCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        progressFinished: freezed == progressFinished
            ? _self.progressFinished
            : progressFinished // ignore: cast_nullable_to_non_nullable
                  as int?,
        progressTotal: freezed == progressTotal
            ? _self.progressTotal
            : progressTotal // ignore: cast_nullable_to_non_nullable
                  as int?,
        progressLastSourceName: freezed == progressLastSourceName
            ? _self.progressLastSourceName
            : progressLastSourceName // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}
