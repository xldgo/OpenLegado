// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SourceState {
  /// 全部书源列表
  List<BookSource> get sources;

  /// 是否正在加载
  bool get loading;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// 搜索过滤关键词
  String get filterKeyword;

  /// 选中分组（null = 全部）
  String? get selectedGroup;

  /// 排序方式
  SourceSort get sort;

  /// 是否升序
  bool get sortAscending;

  /// 是否处于批量选择模式
  bool get batchMode;

  /// 批量选中的书源 URL 集合
  Set<String> get selectedUrls;

  /// 最近一次导入结果
  ImportResult? get lastImportResult;

  /// Create a copy of SourceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SourceStateCopyWith<SourceState> get copyWith =>
      _$SourceStateCopyWithImpl<SourceState>(this as SourceState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as SourceState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SourceState &&
            const DeepCollectionEquality().equals(
              other.sources,
              _this.sources,
            ) &&
            (identical(other.loading, _this.loading) ||
                other.loading == _this.loading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.filterKeyword, _this.filterKeyword) ||
                other.filterKeyword == _this.filterKeyword) &&
            (identical(other.selectedGroup, _this.selectedGroup) ||
                other.selectedGroup == _this.selectedGroup) &&
            (identical(other.sort, _this.sort) || other.sort == _this.sort) &&
            (identical(other.sortAscending, _this.sortAscending) ||
                other.sortAscending == _this.sortAscending) &&
            (identical(other.batchMode, _this.batchMode) ||
                other.batchMode == _this.batchMode) &&
            const DeepCollectionEquality().equals(
              other.selectedUrls,
              _this.selectedUrls,
            ) &&
            (identical(other.lastImportResult, _this.lastImportResult) ||
                other.lastImportResult == _this.lastImportResult));
  }

  @override
  int get hashCode {
    final _this = this as SourceState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.sources),
      _this.loading,
      _this.error,
      _this.filterKeyword,
      _this.selectedGroup,
      _this.sort,
      _this.sortAscending,
      _this.batchMode,
      const DeepCollectionEquality().hash(_this.selectedUrls),
      _this.lastImportResult,
    );
  }

  @override
  String toString() {
    final _this = this as SourceState;
    return 'SourceState(sources: ${_this.sources}, loading: ${_this.loading}, error: ${_this.error}, filterKeyword: ${_this.filterKeyword}, selectedGroup: ${_this.selectedGroup}, sort: ${_this.sort}, sortAscending: ${_this.sortAscending}, batchMode: ${_this.batchMode}, selectedUrls: ${_this.selectedUrls}, lastImportResult: ${_this.lastImportResult})';
  }
}

/// @nodoc
abstract mixin class $SourceStateCopyWith<$Res> {
  factory $SourceStateCopyWith(
    SourceState value,
    $Res Function(SourceState) _then,
  ) = _$SourceStateCopyWithImpl;
  @useResult
  $Res call({
    List<BookSource> sources,
    bool loading,
    String? error,
    String filterKeyword,
    String? selectedGroup,
    SourceSort sort,
    bool sortAscending,
    bool batchMode,
    Set<String> selectedUrls,
    ImportResult? lastImportResult,
  });
}

/// @nodoc
class _$SourceStateCopyWithImpl<$Res> implements $SourceStateCopyWith<$Res> {
  _$SourceStateCopyWithImpl(this._self, this._then);

  final SourceState _self;
  final $Res Function(SourceState) _then;

  /// Create a copy of SourceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sources = null,
    Object? loading = null,
    Object? error = freezed,
    Object? filterKeyword = null,
    Object? selectedGroup = freezed,
    Object? sort = null,
    Object? sortAscending = null,
    Object? batchMode = null,
    Object? selectedUrls = null,
    Object? lastImportResult = freezed,
  }) {
    return _then(
      SourceState(
        sources: null == sources
            ? _self.sources
            : sources // ignore: cast_nullable_to_non_nullable
                  as List<BookSource>,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        filterKeyword: null == filterKeyword
            ? _self.filterKeyword
            : filterKeyword // ignore: cast_nullable_to_non_nullable
                  as String,
        selectedGroup: freezed == selectedGroup
            ? _self.selectedGroup
            : selectedGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
        sort: null == sort
            ? _self.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as SourceSort,
        sortAscending: null == sortAscending
            ? _self.sortAscending
            : sortAscending // ignore: cast_nullable_to_non_nullable
                  as bool,
        batchMode: null == batchMode
            ? _self.batchMode
            : batchMode // ignore: cast_nullable_to_non_nullable
                  as bool,
        selectedUrls: null == selectedUrls
            ? _self.selectedUrls
            : selectedUrls // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        lastImportResult: freezed == lastImportResult
            ? _self.lastImportResult
            : lastImportResult // ignore: cast_nullable_to_non_nullable
                  as ImportResult?,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [SourceState].
extension SourceStatePatterns on SourceState {
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
    TResult Function(_SourceState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SourceState() when $default != null:
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
    TResult Function(_SourceState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceState():
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
    TResult? Function(_SourceState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceState() when $default != null:
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
      List<BookSource> sources,
      bool loading,
      String? error,
      String filterKeyword,
      String? selectedGroup,
      SourceSort sort,
      bool sortAscending,
      bool batchMode,
      Set<String> selectedUrls,
      ImportResult? lastImportResult,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SourceState() when $default != null:
        return $default(
          _that.sources,
          _that.loading,
          _that.error,
          _that.filterKeyword,
          _that.selectedGroup,
          _that.sort,
          _that.sortAscending,
          _that.batchMode,
          _that.selectedUrls,
          _that.lastImportResult,
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
      List<BookSource> sources,
      bool loading,
      String? error,
      String filterKeyword,
      String? selectedGroup,
      SourceSort sort,
      bool sortAscending,
      bool batchMode,
      Set<String> selectedUrls,
      ImportResult? lastImportResult,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceState():
        return $default(
          _that.sources,
          _that.loading,
          _that.error,
          _that.filterKeyword,
          _that.selectedGroup,
          _that.sort,
          _that.sortAscending,
          _that.batchMode,
          _that.selectedUrls,
          _that.lastImportResult,
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
      List<BookSource> sources,
      bool loading,
      String? error,
      String filterKeyword,
      String? selectedGroup,
      SourceSort sort,
      bool sortAscending,
      bool batchMode,
      Set<String> selectedUrls,
      ImportResult? lastImportResult,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SourceState() when $default != null:
        return $default(
          _that.sources,
          _that.loading,
          _that.error,
          _that.filterKeyword,
          _that.selectedGroup,
          _that.sort,
          _that.sortAscending,
          _that.batchMode,
          _that.selectedUrls,
          _that.lastImportResult,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SourceState implements SourceState {
  const _SourceState({
    List<BookSource> sources = const [],
    this.loading = false,
    this.error,
    this.filterKeyword = '',
    this.selectedGroup,
    this.sort = SourceSort.manual,
    this.sortAscending = true,
    this.batchMode = false,
    Set<String> selectedUrls = const <String>{},
    this.lastImportResult,
  }) : _sources = sources,
       _selectedUrls = selectedUrls;

  /// 全部书源列表
  final List<BookSource> _sources;

  /// 全部书源列表
  @override
  @JsonKey()
  List<BookSource> get sources {
    if (_sources is EqualUnmodifiableListView) return _sources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sources);
  }

  /// 是否正在加载
  @override
  @JsonKey()
  final bool loading;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// 搜索过滤关键词
  @override
  @JsonKey()
  final String filterKeyword;

  /// 选中分组（null = 全部）
  @override
  final String? selectedGroup;

  /// 排序方式
  @override
  @JsonKey()
  final SourceSort sort;

  /// 是否升序
  @override
  @JsonKey()
  final bool sortAscending;

  /// 是否处于批量选择模式
  @override
  @JsonKey()
  final bool batchMode;

  /// 批量选中的书源 URL 集合
  final Set<String> _selectedUrls;

  /// 批量选中的书源 URL 集合
  @override
  @JsonKey()
  Set<String> get selectedUrls {
    if (_selectedUrls is EqualUnmodifiableSetView) return _selectedUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedUrls);
  }

  /// 最近一次导入结果
  @override
  final ImportResult? lastImportResult;

  /// Create a copy of SourceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SourceStateCopyWith<_SourceState> get copyWith =>
      __$SourceStateCopyWithImpl<_SourceState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SourceState &&
            const DeepCollectionEquality().equals(other.sources, _sources) &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.filterKeyword, filterKeyword) ||
                other.filterKeyword == filterKeyword) &&
            (identical(other.selectedGroup, selectedGroup) ||
                other.selectedGroup == selectedGroup) &&
            (identical(other.sort, sort) || other.sort == sort) &&
            (identical(other.sortAscending, sortAscending) ||
                other.sortAscending == sortAscending) &&
            (identical(other.batchMode, batchMode) ||
                other.batchMode == batchMode) &&
            const DeepCollectionEquality().equals(
              other.selectedUrls,
              _selectedUrls,
            ) &&
            (identical(other.lastImportResult, lastImportResult) ||
                other.lastImportResult == lastImportResult));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_sources),
      loading,
      error,
      filterKeyword,
      selectedGroup,
      sort,
      sortAscending,
      batchMode,
      const DeepCollectionEquality().hash(_selectedUrls),
      lastImportResult,
    );
  }

  @override
  String toString() {
    return 'SourceState(sources: $sources, loading: $loading, error: $error, filterKeyword: $filterKeyword, selectedGroup: $selectedGroup, sort: $sort, sortAscending: $sortAscending, batchMode: $batchMode, selectedUrls: $selectedUrls, lastImportResult: $lastImportResult)';
  }
}

/// @nodoc
abstract mixin class _$SourceStateCopyWith<$Res>
    implements $SourceStateCopyWith<$Res> {
  factory _$SourceStateCopyWith(
    _SourceState value,
    $Res Function(_SourceState) _then,
  ) = __$SourceStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<BookSource> sources,
    bool loading,
    String? error,
    String filterKeyword,
    String? selectedGroup,
    SourceSort sort,
    bool sortAscending,
    bool batchMode,
    Set<String> selectedUrls,
    ImportResult? lastImportResult,
  });
}

/// @nodoc
class __$SourceStateCopyWithImpl<$Res> implements _$SourceStateCopyWith<$Res> {
  __$SourceStateCopyWithImpl(this._self, this._then);

  final _SourceState _self;
  final $Res Function(_SourceState) _then;

  /// Create a copy of SourceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sources = null,
    Object? loading = null,
    Object? error = freezed,
    Object? filterKeyword = null,
    Object? selectedGroup = freezed,
    Object? sort = null,
    Object? sortAscending = null,
    Object? batchMode = null,
    Object? selectedUrls = null,
    Object? lastImportResult = freezed,
  }) {
    return _then(
      _SourceState(
        sources: null == sources
            ? _self._sources
            : sources // ignore: cast_nullable_to_non_nullable
                  as List<BookSource>,
        loading: null == loading
            ? _self.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        filterKeyword: null == filterKeyword
            ? _self.filterKeyword
            : filterKeyword // ignore: cast_nullable_to_non_nullable
                  as String,
        selectedGroup: freezed == selectedGroup
            ? _self.selectedGroup
            : selectedGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
        sort: null == sort
            ? _self.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as SourceSort,
        sortAscending: null == sortAscending
            ? _self.sortAscending
            : sortAscending // ignore: cast_nullable_to_non_nullable
                  as bool,
        batchMode: null == batchMode
            ? _self.batchMode
            : batchMode // ignore: cast_nullable_to_non_nullable
                  as bool,
        selectedUrls: null == selectedUrls
            ? _self._selectedUrls
            : selectedUrls // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        lastImportResult: freezed == lastImportResult
            ? _self.lastImportResult
            : lastImportResult // ignore: cast_nullable_to_non_nullable
                  as ImportResult?,
      ),
    );
  }
}
