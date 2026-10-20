// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bookshelf_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookshelfState {
  /// Rust 返回的书籍列表（已排序，UI 层不做排序）
  List<Book> get books;

  /// 是否正在加载
  bool get isLoading;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// 展示层：网格/列表视图模式
  bool get isGridView;

  /// 展示层：网格列数
  int get gridColumns;

  /// 展示层：分组显示模式
  GroupMode get groupMode;

  /// 书籍分组列表（对标原版 BookGroup，顶栏 Tab 数据源）
  List<BookGroup> get groups;

  /// 当前选中的分组 Tab 索引（对标原版 AppConfig.saveTabPosition）
  int get selectedGroupIndex;

  /// [UI_SYNC_REFACTOR T3] 批量选择模式（对齐参考 SelectionBottomBar 态）
  bool get isBatchMode;

  /// 批量选中的书籍 URL 集合
  Set<String> get selectedUrls;

  /// Create a copy of BookshelfState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BookshelfStateCopyWith<BookshelfState> get copyWith =>
      _$BookshelfStateCopyWithImpl<BookshelfState>(
        this as BookshelfState,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as BookshelfState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BookshelfState &&
            const DeepCollectionEquality().equals(other.books, _this.books) &&
            (identical(other.isLoading, _this.isLoading) ||
                other.isLoading == _this.isLoading) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.isGridView, _this.isGridView) ||
                other.isGridView == _this.isGridView) &&
            (identical(other.gridColumns, _this.gridColumns) ||
                other.gridColumns == _this.gridColumns) &&
            (identical(other.groupMode, _this.groupMode) ||
                other.groupMode == _this.groupMode) &&
            const DeepCollectionEquality().equals(other.groups, _this.groups) &&
            (identical(other.selectedGroupIndex, _this.selectedGroupIndex) ||
                other.selectedGroupIndex == _this.selectedGroupIndex) &&
            (identical(other.isBatchMode, _this.isBatchMode) ||
                other.isBatchMode == _this.isBatchMode) &&
            const DeepCollectionEquality().equals(
              other.selectedUrls,
              _this.selectedUrls,
            ));
  }

  @override
  int get hashCode {
    final _this = this as BookshelfState;
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_this.books),
      _this.isLoading,
      _this.error,
      _this.isGridView,
      _this.gridColumns,
      _this.groupMode,
      const DeepCollectionEquality().hash(_this.groups),
      _this.selectedGroupIndex,
      _this.isBatchMode,
      const DeepCollectionEquality().hash(_this.selectedUrls),
    );
  }

  @override
  String toString() {
    final _this = this as BookshelfState;
    return 'BookshelfState(books: ${_this.books}, isLoading: ${_this.isLoading}, error: ${_this.error}, isGridView: ${_this.isGridView}, gridColumns: ${_this.gridColumns}, groupMode: ${_this.groupMode}, groups: ${_this.groups}, selectedGroupIndex: ${_this.selectedGroupIndex}, isBatchMode: ${_this.isBatchMode}, selectedUrls: ${_this.selectedUrls})';
  }
}

/// @nodoc
abstract mixin class $BookshelfStateCopyWith<$Res> {
  factory $BookshelfStateCopyWith(
    BookshelfState value,
    $Res Function(BookshelfState) _then,
  ) = _$BookshelfStateCopyWithImpl;
  @useResult
  $Res call({
    List<Book> books,
    bool isLoading,
    String? error,
    bool isGridView,
    int gridColumns,
    GroupMode groupMode,
    List<BookGroup> groups,
    int selectedGroupIndex,
    bool isBatchMode,
    Set<String> selectedUrls,
  });
}

/// @nodoc
class _$BookshelfStateCopyWithImpl<$Res>
    implements $BookshelfStateCopyWith<$Res> {
  _$BookshelfStateCopyWithImpl(this._self, this._then);

  final BookshelfState _self;
  final $Res Function(BookshelfState) _then;

  /// Create a copy of BookshelfState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? books = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? isGridView = null,
    Object? gridColumns = null,
    Object? groupMode = null,
    Object? groups = null,
    Object? selectedGroupIndex = null,
    Object? isBatchMode = null,
    Object? selectedUrls = null,
  }) {
    return _then(
      BookshelfState(
        books: null == books
            ? _self.books
            : books // ignore: cast_nullable_to_non_nullable
                  as List<Book>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        isGridView: null == isGridView
            ? _self.isGridView
            : isGridView // ignore: cast_nullable_to_non_nullable
                  as bool,
        gridColumns: null == gridColumns
            ? _self.gridColumns
            : gridColumns // ignore: cast_nullable_to_non_nullable
                  as int,
        groupMode: null == groupMode
            ? _self.groupMode
            : groupMode // ignore: cast_nullable_to_non_nullable
                  as GroupMode,
        groups: null == groups
            ? _self.groups
            : groups // ignore: cast_nullable_to_non_nullable
                  as List<BookGroup>,
        selectedGroupIndex: null == selectedGroupIndex
            ? _self.selectedGroupIndex
            : selectedGroupIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        isBatchMode: null == isBatchMode
            ? _self.isBatchMode
            : isBatchMode // ignore: cast_nullable_to_non_nullable
                  as bool,
        selectedUrls: null == selectedUrls
            ? _self.selectedUrls
            : selectedUrls // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [BookshelfState].
extension BookshelfStatePatterns on BookshelfState {
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
    TResult Function(_BookshelfState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookshelfState() when $default != null:
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
    TResult Function(_BookshelfState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookshelfState():
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
    TResult? Function(_BookshelfState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookshelfState() when $default != null:
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
      List<Book> books,
      bool isLoading,
      String? error,
      bool isGridView,
      int gridColumns,
      GroupMode groupMode,
      List<BookGroup> groups,
      int selectedGroupIndex,
      bool isBatchMode,
      Set<String> selectedUrls,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BookshelfState() when $default != null:
        return $default(
          _that.books,
          _that.isLoading,
          _that.error,
          _that.isGridView,
          _that.gridColumns,
          _that.groupMode,
          _that.groups,
          _that.selectedGroupIndex,
          _that.isBatchMode,
          _that.selectedUrls,
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
      List<Book> books,
      bool isLoading,
      String? error,
      bool isGridView,
      int gridColumns,
      GroupMode groupMode,
      List<BookGroup> groups,
      int selectedGroupIndex,
      bool isBatchMode,
      Set<String> selectedUrls,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookshelfState():
        return $default(
          _that.books,
          _that.isLoading,
          _that.error,
          _that.isGridView,
          _that.gridColumns,
          _that.groupMode,
          _that.groups,
          _that.selectedGroupIndex,
          _that.isBatchMode,
          _that.selectedUrls,
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
      List<Book> books,
      bool isLoading,
      String? error,
      bool isGridView,
      int gridColumns,
      GroupMode groupMode,
      List<BookGroup> groups,
      int selectedGroupIndex,
      bool isBatchMode,
      Set<String> selectedUrls,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BookshelfState() when $default != null:
        return $default(
          _that.books,
          _that.isLoading,
          _that.error,
          _that.isGridView,
          _that.gridColumns,
          _that.groupMode,
          _that.groups,
          _that.selectedGroupIndex,
          _that.isBatchMode,
          _that.selectedUrls,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _BookshelfState implements BookshelfState {
  const _BookshelfState({
    List<Book> books = const [],
    this.isLoading = false,
    this.error,
    this.isGridView = false,
    this.gridColumns = 3,
    this.groupMode = GroupMode.none,
    List<BookGroup> groups = const [],
    this.selectedGroupIndex = 0,
    this.isBatchMode = false,
    Set<String> selectedUrls = const {},
  }) : _books = books,
       _groups = groups,
       _selectedUrls = selectedUrls;

  /// Rust 返回的书籍列表（已排序，UI 层不做排序）
  final List<Book> _books;

  /// Rust 返回的书籍列表（已排序，UI 层不做排序）
  @override
  @JsonKey()
  List<Book> get books {
    if (_books is EqualUnmodifiableListView) return _books;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_books);
  }

  /// 是否正在加载
  @override
  @JsonKey()
  final bool isLoading;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// 展示层：网格/列表视图模式
  @override
  @JsonKey()
  final bool isGridView;

  /// 展示层：网格列数
  @override
  @JsonKey()
  final int gridColumns;

  /// 展示层：分组显示模式
  @override
  @JsonKey()
  final GroupMode groupMode;

  /// 书籍分组列表（对标原版 BookGroup，顶栏 Tab 数据源）
  final List<BookGroup> _groups;

  /// 书籍分组列表（对标原版 BookGroup，顶栏 Tab 数据源）
  @override
  @JsonKey()
  List<BookGroup> get groups {
    if (_groups is EqualUnmodifiableListView) return _groups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_groups);
  }

  /// 当前选中的分组 Tab 索引（对标原版 AppConfig.saveTabPosition）
  @override
  @JsonKey()
  final int selectedGroupIndex;

  /// [UI_SYNC_REFACTOR T3] 批量选择模式（对齐参考 SelectionBottomBar 态）
  @override
  @JsonKey()
  final bool isBatchMode;

  /// 批量选中的书籍 URL 集合
  final Set<String> _selectedUrls;

  /// 批量选中的书籍 URL 集合
  @override
  @JsonKey()
  Set<String> get selectedUrls {
    if (_selectedUrls is EqualUnmodifiableSetView) return _selectedUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedUrls);
  }

  /// Create a copy of BookshelfState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BookshelfStateCopyWith<_BookshelfState> get copyWith =>
      __$BookshelfStateCopyWithImpl<_BookshelfState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BookshelfState &&
            const DeepCollectionEquality().equals(other.books, _books) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.isGridView, isGridView) ||
                other.isGridView == isGridView) &&
            (identical(other.gridColumns, gridColumns) ||
                other.gridColumns == gridColumns) &&
            (identical(other.groupMode, groupMode) ||
                other.groupMode == groupMode) &&
            const DeepCollectionEquality().equals(other.groups, _groups) &&
            (identical(other.selectedGroupIndex, selectedGroupIndex) ||
                other.selectedGroupIndex == selectedGroupIndex) &&
            (identical(other.isBatchMode, isBatchMode) ||
                other.isBatchMode == isBatchMode) &&
            const DeepCollectionEquality().equals(
              other.selectedUrls,
              _selectedUrls,
            ));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_books),
      isLoading,
      error,
      isGridView,
      gridColumns,
      groupMode,
      const DeepCollectionEquality().hash(_groups),
      selectedGroupIndex,
      isBatchMode,
      const DeepCollectionEquality().hash(_selectedUrls),
    );
  }

  @override
  String toString() {
    return 'BookshelfState(books: $books, isLoading: $isLoading, error: $error, isGridView: $isGridView, gridColumns: $gridColumns, groupMode: $groupMode, groups: $groups, selectedGroupIndex: $selectedGroupIndex, isBatchMode: $isBatchMode, selectedUrls: $selectedUrls)';
  }
}

/// @nodoc
abstract mixin class _$BookshelfStateCopyWith<$Res>
    implements $BookshelfStateCopyWith<$Res> {
  factory _$BookshelfStateCopyWith(
    _BookshelfState value,
    $Res Function(_BookshelfState) _then,
  ) = __$BookshelfStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    List<Book> books,
    bool isLoading,
    String? error,
    bool isGridView,
    int gridColumns,
    GroupMode groupMode,
    List<BookGroup> groups,
    int selectedGroupIndex,
    bool isBatchMode,
    Set<String> selectedUrls,
  });
}

/// @nodoc
class __$BookshelfStateCopyWithImpl<$Res>
    implements _$BookshelfStateCopyWith<$Res> {
  __$BookshelfStateCopyWithImpl(this._self, this._then);

  final _BookshelfState _self;
  final $Res Function(_BookshelfState) _then;

  /// Create a copy of BookshelfState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? books = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? isGridView = null,
    Object? gridColumns = null,
    Object? groupMode = null,
    Object? groups = null,
    Object? selectedGroupIndex = null,
    Object? isBatchMode = null,
    Object? selectedUrls = null,
  }) {
    return _then(
      _BookshelfState(
        books: null == books
            ? _self._books
            : books // ignore: cast_nullable_to_non_nullable
                  as List<Book>,
        isLoading: null == isLoading
            ? _self.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        isGridView: null == isGridView
            ? _self.isGridView
            : isGridView // ignore: cast_nullable_to_non_nullable
                  as bool,
        gridColumns: null == gridColumns
            ? _self.gridColumns
            : gridColumns // ignore: cast_nullable_to_non_nullable
                  as int,
        groupMode: null == groupMode
            ? _self.groupMode
            : groupMode // ignore: cast_nullable_to_non_nullable
                  as GroupMode,
        groups: null == groups
            ? _self._groups
            : groups // ignore: cast_nullable_to_non_nullable
                  as List<BookGroup>,
        selectedGroupIndex: null == selectedGroupIndex
            ? _self.selectedGroupIndex
            : selectedGroupIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        isBatchMode: null == isBatchMode
            ? _self.isBatchMode
            : isBatchMode // ignore: cast_nullable_to_non_nullable
                  as bool,
        selectedUrls: null == selectedUrls
            ? _self._selectedUrls
            : selectedUrls // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
      ),
    );
  }
}
