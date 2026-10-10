// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SyncState {
  /// 同步状态
  SyncStatus get status;

  /// 上次同步时间（null 表示从未同步）
  DateTime? get lastSyncTime;

  /// 错误信息（null 表示无错误）
  String? get error;

  /// 是否自动同步
  bool get autoSync;

  /// WebDAV 服务器地址
  String get webDavUrl;

  /// WebDAV 账号
  String get webDavUsername;

  /// WebDAV 密码
  String get webDavPassword;

  /// 远端子目录
  String get remoteDir;

  /// 设备名
  String get deviceName;

  /// 同步书籍进度
  bool get syncBookProgress;

  /// 同步书籍进度增强
  bool get syncBookProgressPlus;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncStateCopyWith<SyncState> get copyWith =>
      _$SyncStateCopyWithImpl<SyncState>(this as SyncState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as SyncState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncState &&
            (identical(other.status, _this.status) ||
                other.status == _this.status) &&
            (identical(other.lastSyncTime, _this.lastSyncTime) ||
                other.lastSyncTime == _this.lastSyncTime) &&
            (identical(other.error, _this.error) ||
                other.error == _this.error) &&
            (identical(other.autoSync, _this.autoSync) ||
                other.autoSync == _this.autoSync) &&
            (identical(other.webDavUrl, _this.webDavUrl) ||
                other.webDavUrl == _this.webDavUrl) &&
            (identical(other.webDavUsername, _this.webDavUsername) ||
                other.webDavUsername == _this.webDavUsername) &&
            (identical(other.webDavPassword, _this.webDavPassword) ||
                other.webDavPassword == _this.webDavPassword) &&
            (identical(other.remoteDir, _this.remoteDir) ||
                other.remoteDir == _this.remoteDir) &&
            (identical(other.deviceName, _this.deviceName) ||
                other.deviceName == _this.deviceName) &&
            (identical(other.syncBookProgress, _this.syncBookProgress) ||
                other.syncBookProgress == _this.syncBookProgress) &&
            (identical(
                  other.syncBookProgressPlus,
                  _this.syncBookProgressPlus,
                ) ||
                other.syncBookProgressPlus == _this.syncBookProgressPlus));
  }

  @override
  int get hashCode {
    final _this = this as SyncState;
    return Object.hash(
      runtimeType,
      _this.status,
      _this.lastSyncTime,
      _this.error,
      _this.autoSync,
      _this.webDavUrl,
      _this.webDavUsername,
      _this.webDavPassword,
      _this.remoteDir,
      _this.deviceName,
      _this.syncBookProgress,
      _this.syncBookProgressPlus,
    );
  }

  @override
  String toString() {
    final _this = this as SyncState;
    return 'SyncState(status: ${_this.status}, lastSyncTime: ${_this.lastSyncTime}, error: ${_this.error}, autoSync: ${_this.autoSync}, webDavUrl: ${_this.webDavUrl}, webDavUsername: ${_this.webDavUsername}, webDavPassword: ${_this.webDavPassword}, remoteDir: ${_this.remoteDir}, deviceName: ${_this.deviceName}, syncBookProgress: ${_this.syncBookProgress}, syncBookProgressPlus: ${_this.syncBookProgressPlus})';
  }
}

/// @nodoc
abstract mixin class $SyncStateCopyWith<$Res> {
  factory $SyncStateCopyWith(SyncState value, $Res Function(SyncState) _then) =
      _$SyncStateCopyWithImpl;
  @useResult
  $Res call({
    SyncStatus status,
    DateTime? lastSyncTime,
    String? error,
    bool autoSync,
    String webDavUrl,
    String webDavUsername,
    String webDavPassword,
    String remoteDir,
    String deviceName,
    bool syncBookProgress,
    bool syncBookProgressPlus,
  });
}

/// @nodoc
class _$SyncStateCopyWithImpl<$Res> implements $SyncStateCopyWith<$Res> {
  _$SyncStateCopyWithImpl(this._self, this._then);

  final SyncState _self;
  final $Res Function(SyncState) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? lastSyncTime = freezed,
    Object? error = freezed,
    Object? autoSync = null,
    Object? webDavUrl = null,
    Object? webDavUsername = null,
    Object? webDavPassword = null,
    Object? remoteDir = null,
    Object? deviceName = null,
    Object? syncBookProgress = null,
    Object? syncBookProgressPlus = null,
  }) {
    return _then(
      SyncState(
        status: null == status
            ? _self.status
            : status // ignore: cast_nullable_to_non_nullable
                  as SyncStatus,
        lastSyncTime: freezed == lastSyncTime
            ? _self.lastSyncTime
            : lastSyncTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        autoSync: null == autoSync
            ? _self.autoSync
            : autoSync // ignore: cast_nullable_to_non_nullable
                  as bool,
        webDavUrl: null == webDavUrl
            ? _self.webDavUrl
            : webDavUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        webDavUsername: null == webDavUsername
            ? _self.webDavUsername
            : webDavUsername // ignore: cast_nullable_to_non_nullable
                  as String,
        webDavPassword: null == webDavPassword
            ? _self.webDavPassword
            : webDavPassword // ignore: cast_nullable_to_non_nullable
                  as String,
        remoteDir: null == remoteDir
            ? _self.remoteDir
            : remoteDir // ignore: cast_nullable_to_non_nullable
                  as String,
        deviceName: null == deviceName
            ? _self.deviceName
            : deviceName // ignore: cast_nullable_to_non_nullable
                  as String,
        syncBookProgress: null == syncBookProgress
            ? _self.syncBookProgress
            : syncBookProgress // ignore: cast_nullable_to_non_nullable
                  as bool,
        syncBookProgressPlus: null == syncBookProgressPlus
            ? _self.syncBookProgressPlus
            : syncBookProgressPlus // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [SyncState].
extension SyncStatePatterns on SyncState {
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
    TResult Function(_SyncState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SyncState() when $default != null:
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
    TResult Function(_SyncState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncState():
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
    TResult? Function(_SyncState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncState() when $default != null:
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
      SyncStatus status,
      DateTime? lastSyncTime,
      String? error,
      bool autoSync,
      String webDavUrl,
      String webDavUsername,
      String webDavPassword,
      String remoteDir,
      String deviceName,
      bool syncBookProgress,
      bool syncBookProgressPlus,
    )?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SyncState() when $default != null:
        return $default(
          _that.status,
          _that.lastSyncTime,
          _that.error,
          _that.autoSync,
          _that.webDavUrl,
          _that.webDavUsername,
          _that.webDavPassword,
          _that.remoteDir,
          _that.deviceName,
          _that.syncBookProgress,
          _that.syncBookProgressPlus,
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
      SyncStatus status,
      DateTime? lastSyncTime,
      String? error,
      bool autoSync,
      String webDavUrl,
      String webDavUsername,
      String webDavPassword,
      String remoteDir,
      String deviceName,
      bool syncBookProgress,
      bool syncBookProgressPlus,
    )
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncState():
        return $default(
          _that.status,
          _that.lastSyncTime,
          _that.error,
          _that.autoSync,
          _that.webDavUrl,
          _that.webDavUsername,
          _that.webDavPassword,
          _that.remoteDir,
          _that.deviceName,
          _that.syncBookProgress,
          _that.syncBookProgressPlus,
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
      SyncStatus status,
      DateTime? lastSyncTime,
      String? error,
      bool autoSync,
      String webDavUrl,
      String webDavUsername,
      String webDavPassword,
      String remoteDir,
      String deviceName,
      bool syncBookProgress,
      bool syncBookProgressPlus,
    )?
    $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncState() when $default != null:
        return $default(
          _that.status,
          _that.lastSyncTime,
          _that.error,
          _that.autoSync,
          _that.webDavUrl,
          _that.webDavUsername,
          _that.webDavPassword,
          _that.remoteDir,
          _that.deviceName,
          _that.syncBookProgress,
          _that.syncBookProgressPlus,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SyncState implements SyncState {
  const _SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncTime,
    this.error,
    this.autoSync = false,
    this.webDavUrl = '',
    this.webDavUsername = '',
    this.webDavPassword = '',
    this.remoteDir = '/legado/',
    this.deviceName = '',
    this.syncBookProgress = true,
    this.syncBookProgressPlus = false,
  });

  /// 同步状态
  @override
  @JsonKey()
  final SyncStatus status;

  /// 上次同步时间（null 表示从未同步）
  @override
  final DateTime? lastSyncTime;

  /// 错误信息（null 表示无错误）
  @override
  final String? error;

  /// 是否自动同步
  @override
  @JsonKey()
  final bool autoSync;

  /// WebDAV 服务器地址
  @override
  @JsonKey()
  final String webDavUrl;

  /// WebDAV 账号
  @override
  @JsonKey()
  final String webDavUsername;

  /// WebDAV 密码
  @override
  @JsonKey()
  final String webDavPassword;

  /// 远端子目录
  @override
  @JsonKey()
  final String remoteDir;

  /// 设备名
  @override
  @JsonKey()
  final String deviceName;

  /// 同步书籍进度
  @override
  @JsonKey()
  final bool syncBookProgress;

  /// 同步书籍进度增强
  @override
  @JsonKey()
  final bool syncBookProgressPlus;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SyncStateCopyWith<_SyncState> get copyWith =>
      __$SyncStateCopyWithImpl<_SyncState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SyncState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastSyncTime, lastSyncTime) ||
                other.lastSyncTime == lastSyncTime) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.autoSync, autoSync) ||
                other.autoSync == autoSync) &&
            (identical(other.webDavUrl, webDavUrl) ||
                other.webDavUrl == webDavUrl) &&
            (identical(other.webDavUsername, webDavUsername) ||
                other.webDavUsername == webDavUsername) &&
            (identical(other.webDavPassword, webDavPassword) ||
                other.webDavPassword == webDavPassword) &&
            (identical(other.remoteDir, remoteDir) ||
                other.remoteDir == remoteDir) &&
            (identical(other.deviceName, deviceName) ||
                other.deviceName == deviceName) &&
            (identical(other.syncBookProgress, syncBookProgress) ||
                other.syncBookProgress == syncBookProgress) &&
            (identical(other.syncBookProgressPlus, syncBookProgressPlus) ||
                other.syncBookProgressPlus == syncBookProgressPlus));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      status,
      lastSyncTime,
      error,
      autoSync,
      webDavUrl,
      webDavUsername,
      webDavPassword,
      remoteDir,
      deviceName,
      syncBookProgress,
      syncBookProgressPlus,
    );
  }

  @override
  String toString() {
    return 'SyncState(status: $status, lastSyncTime: $lastSyncTime, error: $error, autoSync: $autoSync, webDavUrl: $webDavUrl, webDavUsername: $webDavUsername, webDavPassword: $webDavPassword, remoteDir: $remoteDir, deviceName: $deviceName, syncBookProgress: $syncBookProgress, syncBookProgressPlus: $syncBookProgressPlus)';
  }
}

/// @nodoc
abstract mixin class _$SyncStateCopyWith<$Res>
    implements $SyncStateCopyWith<$Res> {
  factory _$SyncStateCopyWith(
    _SyncState value,
    $Res Function(_SyncState) _then,
  ) = __$SyncStateCopyWithImpl;
  @override
  @useResult
  $Res call({
    SyncStatus status,
    DateTime? lastSyncTime,
    String? error,
    bool autoSync,
    String webDavUrl,
    String webDavUsername,
    String webDavPassword,
    String remoteDir,
    String deviceName,
    bool syncBookProgress,
    bool syncBookProgressPlus,
  });
}

/// @nodoc
class __$SyncStateCopyWithImpl<$Res> implements _$SyncStateCopyWith<$Res> {
  __$SyncStateCopyWithImpl(this._self, this._then);

  final _SyncState _self;
  final $Res Function(_SyncState) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? lastSyncTime = freezed,
    Object? error = freezed,
    Object? autoSync = null,
    Object? webDavUrl = null,
    Object? webDavUsername = null,
    Object? webDavPassword = null,
    Object? remoteDir = null,
    Object? deviceName = null,
    Object? syncBookProgress = null,
    Object? syncBookProgressPlus = null,
  }) {
    return _then(
      _SyncState(
        status: null == status
            ? _self.status
            : status // ignore: cast_nullable_to_non_nullable
                  as SyncStatus,
        lastSyncTime: freezed == lastSyncTime
            ? _self.lastSyncTime
            : lastSyncTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        error: freezed == error
            ? _self.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        autoSync: null == autoSync
            ? _self.autoSync
            : autoSync // ignore: cast_nullable_to_non_nullable
                  as bool,
        webDavUrl: null == webDavUrl
            ? _self.webDavUrl
            : webDavUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        webDavUsername: null == webDavUsername
            ? _self.webDavUsername
            : webDavUsername // ignore: cast_nullable_to_non_nullable
                  as String,
        webDavPassword: null == webDavPassword
            ? _self.webDavPassword
            : webDavPassword // ignore: cast_nullable_to_non_nullable
                  as String,
        remoteDir: null == remoteDir
            ? _self.remoteDir
            : remoteDir // ignore: cast_nullable_to_non_nullable
                  as String,
        deviceName: null == deviceName
            ? _self.deviceName
            : deviceName // ignore: cast_nullable_to_non_nullable
                  as String,
        syncBookProgress: null == syncBookProgress
            ? _self.syncBookProgress
            : syncBookProgress // ignore: cast_nullable_to_non_nullable
                  as bool,
        syncBookProgressPlus: null == syncBookProgressPlus
            ? _self.syncBookProgressPlus
            : syncBookProgressPlus // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}
