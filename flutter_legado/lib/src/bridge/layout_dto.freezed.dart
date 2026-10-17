// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'layout_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LayoutBlockDto {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is LayoutBlockDto);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'LayoutBlockDto()';
  }
}

/// @nodoc
class $LayoutBlockDtoCopyWith<$Res> {
  $LayoutBlockDtoCopyWith(LayoutBlockDto _, $Res Function(LayoutBlockDto) __);
}

/// Adds pattern-matching-related methods to [LayoutBlockDto].
extension LayoutBlockDtoPatterns on LayoutBlockDto {
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
    TResult Function(LayoutBlockDto_Paragraph value)? paragraph,
    TResult Function(LayoutBlockDto_InlineParagraph value)? inlineParagraph,
    TResult Function(LayoutBlockDto_Image value)? image,
    TResult Function(LayoutBlockDto_BlankLine value)? blankLine,
    TResult Function(LayoutBlockDto_Rule value)? rule,
    TResult Function(LayoutBlockDto_PageBreak value)? pageBreak,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case LayoutBlockDto_Paragraph() when paragraph != null:
        return paragraph(_that);
      case LayoutBlockDto_InlineParagraph() when inlineParagraph != null:
        return inlineParagraph(_that);
      case LayoutBlockDto_Image() when image != null:
        return image(_that);
      case LayoutBlockDto_BlankLine() when blankLine != null:
        return blankLine(_that);
      case LayoutBlockDto_Rule() when rule != null:
        return rule(_that);
      case LayoutBlockDto_PageBreak() when pageBreak != null:
        return pageBreak(_that);
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
    required TResult Function(LayoutBlockDto_Paragraph value) paragraph,
    required TResult Function(LayoutBlockDto_InlineParagraph value)
    inlineParagraph,
    required TResult Function(LayoutBlockDto_Image value) image,
    required TResult Function(LayoutBlockDto_BlankLine value) blankLine,
    required TResult Function(LayoutBlockDto_Rule value) rule,
    required TResult Function(LayoutBlockDto_PageBreak value) pageBreak,
  }) {
    final _that = this;
    switch (_that) {
      case LayoutBlockDto_Paragraph():
        return paragraph(_that);
      case LayoutBlockDto_InlineParagraph():
        return inlineParagraph(_that);
      case LayoutBlockDto_Image():
        return image(_that);
      case LayoutBlockDto_BlankLine():
        return blankLine(_that);
      case LayoutBlockDto_Rule():
        return rule(_that);
      case LayoutBlockDto_PageBreak():
        return pageBreak(_that);
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
    TResult? Function(LayoutBlockDto_Paragraph value)? paragraph,
    TResult? Function(LayoutBlockDto_InlineParagraph value)? inlineParagraph,
    TResult? Function(LayoutBlockDto_Image value)? image,
    TResult? Function(LayoutBlockDto_BlankLine value)? blankLine,
    TResult? Function(LayoutBlockDto_Rule value)? rule,
    TResult? Function(LayoutBlockDto_PageBreak value)? pageBreak,
  }) {
    final _that = this;
    switch (_that) {
      case LayoutBlockDto_Paragraph() when paragraph != null:
        return paragraph(_that);
      case LayoutBlockDto_InlineParagraph() when inlineParagraph != null:
        return inlineParagraph(_that);
      case LayoutBlockDto_Image() when image != null:
        return image(_that);
      case LayoutBlockDto_BlankLine() when blankLine != null:
        return blankLine(_that);
      case LayoutBlockDto_Rule() when rule != null:
        return rule(_that);
      case LayoutBlockDto_PageBreak() when pageBreak != null:
        return pageBreak(_that);
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
    TResult Function(LayoutParagraphDto value)? paragraph,
    TResult Function(LayoutInlineParagraphDto field0)? inlineParagraph,
    TResult Function(
      String source,
      double intrinsicWidthPx,
      double intrinsicHeightPx,
      int chapterPosition,
      String? action,
      LayoutAlignmentDto horizontalAlignment,
      LayoutImageScaleDto scaleMode,
      bool pageBreakBefore,
      bool pageBreakAfter,
    )?
    image,
    TResult Function(
      int chapterPosition,
      double lineHeightPx,
      double lineSpacingMultiplier,
    )?
    blankLine,
    TResult Function(
      int colorArgb,
      double widthPx,
      double verticalPaddingPx,
      bool dashed,
    )?
    rule,
    TResult Function()? pageBreak,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case LayoutBlockDto_Paragraph() when paragraph != null:
        return paragraph(_that.value);
      case LayoutBlockDto_InlineParagraph() when inlineParagraph != null:
        return inlineParagraph(_that.field0);
      case LayoutBlockDto_Image() when image != null:
        return image(
          _that.source,
          _that.intrinsicWidthPx,
          _that.intrinsicHeightPx,
          _that.chapterPosition,
          _that.action,
          _that.horizontalAlignment,
          _that.scaleMode,
          _that.pageBreakBefore,
          _that.pageBreakAfter,
        );
      case LayoutBlockDto_BlankLine() when blankLine != null:
        return blankLine(
          _that.chapterPosition,
          _that.lineHeightPx,
          _that.lineSpacingMultiplier,
        );
      case LayoutBlockDto_Rule() when rule != null:
        return rule(
          _that.colorArgb,
          _that.widthPx,
          _that.verticalPaddingPx,
          _that.dashed,
        );
      case LayoutBlockDto_PageBreak() when pageBreak != null:
        return pageBreak();
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
    required TResult Function(LayoutParagraphDto value) paragraph,
    required TResult Function(LayoutInlineParagraphDto field0) inlineParagraph,
    required TResult Function(
      String source,
      double intrinsicWidthPx,
      double intrinsicHeightPx,
      int chapterPosition,
      String? action,
      LayoutAlignmentDto horizontalAlignment,
      LayoutImageScaleDto scaleMode,
      bool pageBreakBefore,
      bool pageBreakAfter,
    )
    image,
    required TResult Function(
      int chapterPosition,
      double lineHeightPx,
      double lineSpacingMultiplier,
    )
    blankLine,
    required TResult Function(
      int colorArgb,
      double widthPx,
      double verticalPaddingPx,
      bool dashed,
    )
    rule,
    required TResult Function() pageBreak,
  }) {
    final _that = this;
    switch (_that) {
      case LayoutBlockDto_Paragraph():
        return paragraph(_that.value);
      case LayoutBlockDto_InlineParagraph():
        return inlineParagraph(_that.field0);
      case LayoutBlockDto_Image():
        return image(
          _that.source,
          _that.intrinsicWidthPx,
          _that.intrinsicHeightPx,
          _that.chapterPosition,
          _that.action,
          _that.horizontalAlignment,
          _that.scaleMode,
          _that.pageBreakBefore,
          _that.pageBreakAfter,
        );
      case LayoutBlockDto_BlankLine():
        return blankLine(
          _that.chapterPosition,
          _that.lineHeightPx,
          _that.lineSpacingMultiplier,
        );
      case LayoutBlockDto_Rule():
        return rule(
          _that.colorArgb,
          _that.widthPx,
          _that.verticalPaddingPx,
          _that.dashed,
        );
      case LayoutBlockDto_PageBreak():
        return pageBreak();
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
    TResult? Function(LayoutParagraphDto value)? paragraph,
    TResult? Function(LayoutInlineParagraphDto field0)? inlineParagraph,
    TResult? Function(
      String source,
      double intrinsicWidthPx,
      double intrinsicHeightPx,
      int chapterPosition,
      String? action,
      LayoutAlignmentDto horizontalAlignment,
      LayoutImageScaleDto scaleMode,
      bool pageBreakBefore,
      bool pageBreakAfter,
    )?
    image,
    TResult? Function(
      int chapterPosition,
      double lineHeightPx,
      double lineSpacingMultiplier,
    )?
    blankLine,
    TResult? Function(
      int colorArgb,
      double widthPx,
      double verticalPaddingPx,
      bool dashed,
    )?
    rule,
    TResult? Function()? pageBreak,
  }) {
    final _that = this;
    switch (_that) {
      case LayoutBlockDto_Paragraph() when paragraph != null:
        return paragraph(_that.value);
      case LayoutBlockDto_InlineParagraph() when inlineParagraph != null:
        return inlineParagraph(_that.field0);
      case LayoutBlockDto_Image() when image != null:
        return image(
          _that.source,
          _that.intrinsicWidthPx,
          _that.intrinsicHeightPx,
          _that.chapterPosition,
          _that.action,
          _that.horizontalAlignment,
          _that.scaleMode,
          _that.pageBreakBefore,
          _that.pageBreakAfter,
        );
      case LayoutBlockDto_BlankLine() when blankLine != null:
        return blankLine(
          _that.chapterPosition,
          _that.lineHeightPx,
          _that.lineSpacingMultiplier,
        );
      case LayoutBlockDto_Rule() when rule != null:
        return rule(
          _that.colorArgb,
          _that.widthPx,
          _that.verticalPaddingPx,
          _that.dashed,
        );
      case LayoutBlockDto_PageBreak() when pageBreak != null:
        return pageBreak();
      case _:
        return null;
    }
  }
}

/// @nodoc

class LayoutBlockDto_Paragraph extends LayoutBlockDto {
  const LayoutBlockDto_Paragraph({required this.value}) : super._();

  final LayoutParagraphDto value;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutBlockDto_ParagraphCopyWith<LayoutBlockDto_Paragraph> get copyWith =>
      _$LayoutBlockDto_ParagraphCopyWithImpl<LayoutBlockDto_Paragraph>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutBlockDto_Paragraph &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, value);
  }

  @override
  String toString() {
    return 'LayoutBlockDto.paragraph(value: $value)';
  }
}

/// @nodoc
abstract mixin class $LayoutBlockDto_ParagraphCopyWith<$Res>
    implements $LayoutBlockDtoCopyWith<$Res> {
  factory $LayoutBlockDto_ParagraphCopyWith(
    LayoutBlockDto_Paragraph value,
    $Res Function(LayoutBlockDto_Paragraph) _then,
  ) = _$LayoutBlockDto_ParagraphCopyWithImpl;
  @useResult
  $Res call({LayoutParagraphDto value});
}

/// @nodoc
class _$LayoutBlockDto_ParagraphCopyWithImpl<$Res>
    implements $LayoutBlockDto_ParagraphCopyWith<$Res> {
  _$LayoutBlockDto_ParagraphCopyWithImpl(this._self, this._then);

  final LayoutBlockDto_Paragraph _self;
  final $Res Function(LayoutBlockDto_Paragraph) _then;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({Object? value = null}) {
    return _then(
      LayoutBlockDto_Paragraph(
        value: null == value
            ? _self.value
            : value // ignore: cast_nullable_to_non_nullable
                  as LayoutParagraphDto,
      ),
    );
  }
}

/// @nodoc

class LayoutBlockDto_InlineParagraph extends LayoutBlockDto {
  const LayoutBlockDto_InlineParagraph(this.field0) : super._();

  final LayoutInlineParagraphDto field0;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutBlockDto_InlineParagraphCopyWith<LayoutBlockDto_InlineParagraph>
  get copyWith =>
      _$LayoutBlockDto_InlineParagraphCopyWithImpl<
        LayoutBlockDto_InlineParagraph
      >(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutBlockDto_InlineParagraph &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, field0);
  }

  @override
  String toString() {
    return 'LayoutBlockDto.inlineParagraph(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $LayoutBlockDto_InlineParagraphCopyWith<$Res>
    implements $LayoutBlockDtoCopyWith<$Res> {
  factory $LayoutBlockDto_InlineParagraphCopyWith(
    LayoutBlockDto_InlineParagraph value,
    $Res Function(LayoutBlockDto_InlineParagraph) _then,
  ) = _$LayoutBlockDto_InlineParagraphCopyWithImpl;
  @useResult
  $Res call({LayoutInlineParagraphDto field0});
}

/// @nodoc
class _$LayoutBlockDto_InlineParagraphCopyWithImpl<$Res>
    implements $LayoutBlockDto_InlineParagraphCopyWith<$Res> {
  _$LayoutBlockDto_InlineParagraphCopyWithImpl(this._self, this._then);

  final LayoutBlockDto_InlineParagraph _self;
  final $Res Function(LayoutBlockDto_InlineParagraph) _then;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({Object? field0 = null}) {
    return _then(
      LayoutBlockDto_InlineParagraph(
        null == field0
            ? _self.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as LayoutInlineParagraphDto,
      ),
    );
  }
}

/// @nodoc

class LayoutBlockDto_Image extends LayoutBlockDto {
  const LayoutBlockDto_Image({
    required this.source,
    required this.intrinsicWidthPx,
    required this.intrinsicHeightPx,
    required this.chapterPosition,
    this.action,
    required this.horizontalAlignment,
    required this.scaleMode,
    required this.pageBreakBefore,
    required this.pageBreakAfter,
  }) : super._();

  final String source;
  final double intrinsicWidthPx;
  final double intrinsicHeightPx;
  final int chapterPosition;
  final String? action;
  final LayoutAlignmentDto horizontalAlignment;
  final LayoutImageScaleDto scaleMode;
  final bool pageBreakBefore;
  final bool pageBreakAfter;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutBlockDto_ImageCopyWith<LayoutBlockDto_Image> get copyWith =>
      _$LayoutBlockDto_ImageCopyWithImpl<LayoutBlockDto_Image>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutBlockDto_Image &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.intrinsicWidthPx, intrinsicWidthPx) ||
                other.intrinsicWidthPx == intrinsicWidthPx) &&
            (identical(other.intrinsicHeightPx, intrinsicHeightPx) ||
                other.intrinsicHeightPx == intrinsicHeightPx) &&
            (identical(other.chapterPosition, chapterPosition) ||
                other.chapterPosition == chapterPosition) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.horizontalAlignment, horizontalAlignment) ||
                other.horizontalAlignment == horizontalAlignment) &&
            (identical(other.scaleMode, scaleMode) ||
                other.scaleMode == scaleMode) &&
            (identical(other.pageBreakBefore, pageBreakBefore) ||
                other.pageBreakBefore == pageBreakBefore) &&
            (identical(other.pageBreakAfter, pageBreakAfter) ||
                other.pageBreakAfter == pageBreakAfter));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      source,
      intrinsicWidthPx,
      intrinsicHeightPx,
      chapterPosition,
      action,
      horizontalAlignment,
      scaleMode,
      pageBreakBefore,
      pageBreakAfter,
    );
  }

  @override
  String toString() {
    return 'LayoutBlockDto.image(source: $source, intrinsicWidthPx: $intrinsicWidthPx, intrinsicHeightPx: $intrinsicHeightPx, chapterPosition: $chapterPosition, action: $action, horizontalAlignment: $horizontalAlignment, scaleMode: $scaleMode, pageBreakBefore: $pageBreakBefore, pageBreakAfter: $pageBreakAfter)';
  }
}

/// @nodoc
abstract mixin class $LayoutBlockDto_ImageCopyWith<$Res>
    implements $LayoutBlockDtoCopyWith<$Res> {
  factory $LayoutBlockDto_ImageCopyWith(
    LayoutBlockDto_Image value,
    $Res Function(LayoutBlockDto_Image) _then,
  ) = _$LayoutBlockDto_ImageCopyWithImpl;
  @useResult
  $Res call({
    String source,
    double intrinsicWidthPx,
    double intrinsicHeightPx,
    int chapterPosition,
    String? action,
    LayoutAlignmentDto horizontalAlignment,
    LayoutImageScaleDto scaleMode,
    bool pageBreakBefore,
    bool pageBreakAfter,
  });
}

/// @nodoc
class _$LayoutBlockDto_ImageCopyWithImpl<$Res>
    implements $LayoutBlockDto_ImageCopyWith<$Res> {
  _$LayoutBlockDto_ImageCopyWithImpl(this._self, this._then);

  final LayoutBlockDto_Image _self;
  final $Res Function(LayoutBlockDto_Image) _then;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? source = null,
    Object? intrinsicWidthPx = null,
    Object? intrinsicHeightPx = null,
    Object? chapterPosition = null,
    Object? action = freezed,
    Object? horizontalAlignment = null,
    Object? scaleMode = null,
    Object? pageBreakBefore = null,
    Object? pageBreakAfter = null,
  }) {
    return _then(
      LayoutBlockDto_Image(
        source: null == source
            ? _self.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        intrinsicWidthPx: null == intrinsicWidthPx
            ? _self.intrinsicWidthPx
            : intrinsicWidthPx // ignore: cast_nullable_to_non_nullable
                  as double,
        intrinsicHeightPx: null == intrinsicHeightPx
            ? _self.intrinsicHeightPx
            : intrinsicHeightPx // ignore: cast_nullable_to_non_nullable
                  as double,
        chapterPosition: null == chapterPosition
            ? _self.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int,
        action: freezed == action
            ? _self.action
            : action // ignore: cast_nullable_to_non_nullable
                  as String?,
        horizontalAlignment: null == horizontalAlignment
            ? _self.horizontalAlignment
            : horizontalAlignment // ignore: cast_nullable_to_non_nullable
                  as LayoutAlignmentDto,
        scaleMode: null == scaleMode
            ? _self.scaleMode
            : scaleMode // ignore: cast_nullable_to_non_nullable
                  as LayoutImageScaleDto,
        pageBreakBefore: null == pageBreakBefore
            ? _self.pageBreakBefore
            : pageBreakBefore // ignore: cast_nullable_to_non_nullable
                  as bool,
        pageBreakAfter: null == pageBreakAfter
            ? _self.pageBreakAfter
            : pageBreakAfter // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class LayoutBlockDto_BlankLine extends LayoutBlockDto {
  const LayoutBlockDto_BlankLine({
    required this.chapterPosition,
    required this.lineHeightPx,
    required this.lineSpacingMultiplier,
  }) : super._();

  final int chapterPosition;
  final double lineHeightPx;
  final double lineSpacingMultiplier;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutBlockDto_BlankLineCopyWith<LayoutBlockDto_BlankLine> get copyWith =>
      _$LayoutBlockDto_BlankLineCopyWithImpl<LayoutBlockDto_BlankLine>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutBlockDto_BlankLine &&
            (identical(other.chapterPosition, chapterPosition) ||
                other.chapterPosition == chapterPosition) &&
            (identical(other.lineHeightPx, lineHeightPx) ||
                other.lineHeightPx == lineHeightPx) &&
            (identical(other.lineSpacingMultiplier, lineSpacingMultiplier) ||
                other.lineSpacingMultiplier == lineSpacingMultiplier));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      chapterPosition,
      lineHeightPx,
      lineSpacingMultiplier,
    );
  }

  @override
  String toString() {
    return 'LayoutBlockDto.blankLine(chapterPosition: $chapterPosition, lineHeightPx: $lineHeightPx, lineSpacingMultiplier: $lineSpacingMultiplier)';
  }
}

/// @nodoc
abstract mixin class $LayoutBlockDto_BlankLineCopyWith<$Res>
    implements $LayoutBlockDtoCopyWith<$Res> {
  factory $LayoutBlockDto_BlankLineCopyWith(
    LayoutBlockDto_BlankLine value,
    $Res Function(LayoutBlockDto_BlankLine) _then,
  ) = _$LayoutBlockDto_BlankLineCopyWithImpl;
  @useResult
  $Res call({
    int chapterPosition,
    double lineHeightPx,
    double lineSpacingMultiplier,
  });
}

/// @nodoc
class _$LayoutBlockDto_BlankLineCopyWithImpl<$Res>
    implements $LayoutBlockDto_BlankLineCopyWith<$Res> {
  _$LayoutBlockDto_BlankLineCopyWithImpl(this._self, this._then);

  final LayoutBlockDto_BlankLine _self;
  final $Res Function(LayoutBlockDto_BlankLine) _then;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? chapterPosition = null,
    Object? lineHeightPx = null,
    Object? lineSpacingMultiplier = null,
  }) {
    return _then(
      LayoutBlockDto_BlankLine(
        chapterPosition: null == chapterPosition
            ? _self.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int,
        lineHeightPx: null == lineHeightPx
            ? _self.lineHeightPx
            : lineHeightPx // ignore: cast_nullable_to_non_nullable
                  as double,
        lineSpacingMultiplier: null == lineSpacingMultiplier
            ? _self.lineSpacingMultiplier
            : lineSpacingMultiplier // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class LayoutBlockDto_Rule extends LayoutBlockDto {
  const LayoutBlockDto_Rule({
    required this.colorArgb,
    required this.widthPx,
    required this.verticalPaddingPx,
    required this.dashed,
  }) : super._();

  final int colorArgb;
  final double widthPx;
  final double verticalPaddingPx;
  final bool dashed;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutBlockDto_RuleCopyWith<LayoutBlockDto_Rule> get copyWith =>
      _$LayoutBlockDto_RuleCopyWithImpl<LayoutBlockDto_Rule>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutBlockDto_Rule &&
            (identical(other.colorArgb, colorArgb) ||
                other.colorArgb == colorArgb) &&
            (identical(other.widthPx, widthPx) || other.widthPx == widthPx) &&
            (identical(other.verticalPaddingPx, verticalPaddingPx) ||
                other.verticalPaddingPx == verticalPaddingPx) &&
            (identical(other.dashed, dashed) || other.dashed == dashed));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      colorArgb,
      widthPx,
      verticalPaddingPx,
      dashed,
    );
  }

  @override
  String toString() {
    return 'LayoutBlockDto.rule(colorArgb: $colorArgb, widthPx: $widthPx, verticalPaddingPx: $verticalPaddingPx, dashed: $dashed)';
  }
}

/// @nodoc
abstract mixin class $LayoutBlockDto_RuleCopyWith<$Res>
    implements $LayoutBlockDtoCopyWith<$Res> {
  factory $LayoutBlockDto_RuleCopyWith(
    LayoutBlockDto_Rule value,
    $Res Function(LayoutBlockDto_Rule) _then,
  ) = _$LayoutBlockDto_RuleCopyWithImpl;
  @useResult
  $Res call({
    int colorArgb,
    double widthPx,
    double verticalPaddingPx,
    bool dashed,
  });
}

/// @nodoc
class _$LayoutBlockDto_RuleCopyWithImpl<$Res>
    implements $LayoutBlockDto_RuleCopyWith<$Res> {
  _$LayoutBlockDto_RuleCopyWithImpl(this._self, this._then);

  final LayoutBlockDto_Rule _self;
  final $Res Function(LayoutBlockDto_Rule) _then;

  /// Create a copy of LayoutBlockDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? colorArgb = null,
    Object? widthPx = null,
    Object? verticalPaddingPx = null,
    Object? dashed = null,
  }) {
    return _then(
      LayoutBlockDto_Rule(
        colorArgb: null == colorArgb
            ? _self.colorArgb
            : colorArgb // ignore: cast_nullable_to_non_nullable
                  as int,
        widthPx: null == widthPx
            ? _self.widthPx
            : widthPx // ignore: cast_nullable_to_non_nullable
                  as double,
        verticalPaddingPx: null == verticalPaddingPx
            ? _self.verticalPaddingPx
            : verticalPaddingPx // ignore: cast_nullable_to_non_nullable
                  as double,
        dashed: null == dashed
            ? _self.dashed
            : dashed // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class LayoutBlockDto_PageBreak extends LayoutBlockDto {
  const LayoutBlockDto_PageBreak() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is LayoutBlockDto_PageBreak);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'LayoutBlockDto.pageBreak()';
  }
}

/// @nodoc
mixin _$LayoutInlineItemDto {
  double get widthPx;
  int get chapterPosition;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutInlineItemDtoCopyWith<LayoutInlineItemDto> get copyWith =>
      _$LayoutInlineItemDtoCopyWithImpl<LayoutInlineItemDto>(
        this as LayoutInlineItemDto,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    final _this = this as LayoutInlineItemDto;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutInlineItemDto &&
            (identical(other.widthPx, _this.widthPx) ||
                other.widthPx == _this.widthPx) &&
            (identical(other.chapterPosition, _this.chapterPosition) ||
                other.chapterPosition == _this.chapterPosition));
  }

  @override
  int get hashCode {
    final _this = this as LayoutInlineItemDto;
    return Object.hash(runtimeType, _this.widthPx, _this.chapterPosition);
  }

  @override
  String toString() {
    final _this = this as LayoutInlineItemDto;
    return 'LayoutInlineItemDto(widthPx: ${_this.widthPx}, chapterPosition: ${_this.chapterPosition})';
  }
}

/// @nodoc
abstract mixin class $LayoutInlineItemDtoCopyWith<$Res> {
  factory $LayoutInlineItemDtoCopyWith(
    LayoutInlineItemDto value,
    $Res Function(LayoutInlineItemDto) _then,
  ) = _$LayoutInlineItemDtoCopyWithImpl;
  @useResult
  $Res call({double widthPx, int chapterPosition});
}

/// @nodoc
class _$LayoutInlineItemDtoCopyWithImpl<$Res>
    implements $LayoutInlineItemDtoCopyWith<$Res> {
  _$LayoutInlineItemDtoCopyWithImpl(this._self, this._then);

  final LayoutInlineItemDto _self;
  final $Res Function(LayoutInlineItemDto) _then;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? widthPx = null, Object? chapterPosition = null}) {
    return _then(
      _self.copyWith(
        widthPx: null == widthPx
            ? _self.widthPx
            : widthPx // ignore: cast_nullable_to_non_nullable
                  as double,
        chapterPosition: null == chapterPosition
            ? _self.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [LayoutInlineItemDto].
extension LayoutInlineItemDtoPatterns on LayoutInlineItemDto {
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
    TResult Function(LayoutInlineItemDto_Text value)? text,
    TResult Function(LayoutInlineItemDto_Image value)? image,
    TResult Function(LayoutInlineItemDto_RoleCast value)? roleCast,
    TResult Function(LayoutInlineItemDto_BgmScene value)? bgmScene,
    TResult Function(LayoutInlineItemDto_Review value)? review,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case LayoutInlineItemDto_Text() when text != null:
        return text(_that);
      case LayoutInlineItemDto_Image() when image != null:
        return image(_that);
      case LayoutInlineItemDto_RoleCast() when roleCast != null:
        return roleCast(_that);
      case LayoutInlineItemDto_BgmScene() when bgmScene != null:
        return bgmScene(_that);
      case LayoutInlineItemDto_Review() when review != null:
        return review(_that);
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
    required TResult Function(LayoutInlineItemDto_Text value) text,
    required TResult Function(LayoutInlineItemDto_Image value) image,
    required TResult Function(LayoutInlineItemDto_RoleCast value) roleCast,
    required TResult Function(LayoutInlineItemDto_BgmScene value) bgmScene,
    required TResult Function(LayoutInlineItemDto_Review value) review,
  }) {
    final _that = this;
    switch (_that) {
      case LayoutInlineItemDto_Text():
        return text(_that);
      case LayoutInlineItemDto_Image():
        return image(_that);
      case LayoutInlineItemDto_RoleCast():
        return roleCast(_that);
      case LayoutInlineItemDto_BgmScene():
        return bgmScene(_that);
      case LayoutInlineItemDto_Review():
        return review(_that);
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
    TResult? Function(LayoutInlineItemDto_Text value)? text,
    TResult? Function(LayoutInlineItemDto_Image value)? image,
    TResult? Function(LayoutInlineItemDto_RoleCast value)? roleCast,
    TResult? Function(LayoutInlineItemDto_BgmScene value)? bgmScene,
    TResult? Function(LayoutInlineItemDto_Review value)? review,
  }) {
    final _that = this;
    switch (_that) {
      case LayoutInlineItemDto_Text() when text != null:
        return text(_that);
      case LayoutInlineItemDto_Image() when image != null:
        return image(_that);
      case LayoutInlineItemDto_RoleCast() when roleCast != null:
        return roleCast(_that);
      case LayoutInlineItemDto_BgmScene() when bgmScene != null:
        return bgmScene(_that);
      case LayoutInlineItemDto_Review() when review != null:
        return review(_that);
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
    TResult Function(
      String value,
      double widthPx,
      LayoutTextStyleDto style,
      int chapterPosition,
      String? link,
      String? markingId,
      double? lineHeightPx,
      double? baselineOffsetPx,
      double baselineShiftPx,
    )?
    text,
    TResult Function(
      String source,
      double widthPx,
      double heightPx,
      int chapterPosition,
      String? action,
      double? lineFinalWidthPx,
    )?
    image,
    TResult Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      String raw,
      String name,
      String voicePoolLabel,
      int quoteOrdinal,
      bool voiceEffectMark,
    )?
    roleCast,
    TResult Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      int paragraphIndex,
      String poolName,
      String trackName,
    )?
    bgmScene,
    TResult Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      int paragraphIndex,
      String reviewKey,
      int count,
      double baselineOffsetPx,
      double? compactWidthPx,
      double? compactHeightPx,
    )?
    review,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case LayoutInlineItemDto_Text() when text != null:
        return text(
          _that.value,
          _that.widthPx,
          _that.style,
          _that.chapterPosition,
          _that.link,
          _that.markingId,
          _that.lineHeightPx,
          _that.baselineOffsetPx,
          _that.baselineShiftPx,
        );
      case LayoutInlineItemDto_Image() when image != null:
        return image(
          _that.source,
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.action,
          _that.lineFinalWidthPx,
        );
      case LayoutInlineItemDto_RoleCast() when roleCast != null:
        return roleCast(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.raw,
          _that.name,
          _that.voicePoolLabel,
          _that.quoteOrdinal,
          _that.voiceEffectMark,
        );
      case LayoutInlineItemDto_BgmScene() when bgmScene != null:
        return bgmScene(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.paragraphIndex,
          _that.poolName,
          _that.trackName,
        );
      case LayoutInlineItemDto_Review() when review != null:
        return review(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.paragraphIndex,
          _that.reviewKey,
          _that.count,
          _that.baselineOffsetPx,
          _that.compactWidthPx,
          _that.compactHeightPx,
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
  TResult when<TResult extends Object?>({
    required TResult Function(
      String value,
      double widthPx,
      LayoutTextStyleDto style,
      int chapterPosition,
      String? link,
      String? markingId,
      double? lineHeightPx,
      double? baselineOffsetPx,
      double baselineShiftPx,
    )
    text,
    required TResult Function(
      String source,
      double widthPx,
      double heightPx,
      int chapterPosition,
      String? action,
      double? lineFinalWidthPx,
    )
    image,
    required TResult Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      String raw,
      String name,
      String voicePoolLabel,
      int quoteOrdinal,
      bool voiceEffectMark,
    )
    roleCast,
    required TResult Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      int paragraphIndex,
      String poolName,
      String trackName,
    )
    bgmScene,
    required TResult Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      int paragraphIndex,
      String reviewKey,
      int count,
      double baselineOffsetPx,
      double? compactWidthPx,
      double? compactHeightPx,
    )
    review,
  }) {
    final _that = this;
    switch (_that) {
      case LayoutInlineItemDto_Text():
        return text(
          _that.value,
          _that.widthPx,
          _that.style,
          _that.chapterPosition,
          _that.link,
          _that.markingId,
          _that.lineHeightPx,
          _that.baselineOffsetPx,
          _that.baselineShiftPx,
        );
      case LayoutInlineItemDto_Image():
        return image(
          _that.source,
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.action,
          _that.lineFinalWidthPx,
        );
      case LayoutInlineItemDto_RoleCast():
        return roleCast(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.raw,
          _that.name,
          _that.voicePoolLabel,
          _that.quoteOrdinal,
          _that.voiceEffectMark,
        );
      case LayoutInlineItemDto_BgmScene():
        return bgmScene(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.paragraphIndex,
          _that.poolName,
          _that.trackName,
        );
      case LayoutInlineItemDto_Review():
        return review(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.paragraphIndex,
          _that.reviewKey,
          _that.count,
          _that.baselineOffsetPx,
          _that.compactWidthPx,
          _that.compactHeightPx,
        );
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
    TResult? Function(
      String value,
      double widthPx,
      LayoutTextStyleDto style,
      int chapterPosition,
      String? link,
      String? markingId,
      double? lineHeightPx,
      double? baselineOffsetPx,
      double baselineShiftPx,
    )?
    text,
    TResult? Function(
      String source,
      double widthPx,
      double heightPx,
      int chapterPosition,
      String? action,
      double? lineFinalWidthPx,
    )?
    image,
    TResult? Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      String raw,
      String name,
      String voicePoolLabel,
      int quoteOrdinal,
      bool voiceEffectMark,
    )?
    roleCast,
    TResult? Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      int paragraphIndex,
      String poolName,
      String trackName,
    )?
    bgmScene,
    TResult? Function(
      double widthPx,
      double heightPx,
      int chapterPosition,
      int paragraphIndex,
      String reviewKey,
      int count,
      double baselineOffsetPx,
      double? compactWidthPx,
      double? compactHeightPx,
    )?
    review,
  }) {
    final _that = this;
    switch (_that) {
      case LayoutInlineItemDto_Text() when text != null:
        return text(
          _that.value,
          _that.widthPx,
          _that.style,
          _that.chapterPosition,
          _that.link,
          _that.markingId,
          _that.lineHeightPx,
          _that.baselineOffsetPx,
          _that.baselineShiftPx,
        );
      case LayoutInlineItemDto_Image() when image != null:
        return image(
          _that.source,
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.action,
          _that.lineFinalWidthPx,
        );
      case LayoutInlineItemDto_RoleCast() when roleCast != null:
        return roleCast(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.raw,
          _that.name,
          _that.voicePoolLabel,
          _that.quoteOrdinal,
          _that.voiceEffectMark,
        );
      case LayoutInlineItemDto_BgmScene() when bgmScene != null:
        return bgmScene(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.paragraphIndex,
          _that.poolName,
          _that.trackName,
        );
      case LayoutInlineItemDto_Review() when review != null:
        return review(
          _that.widthPx,
          _that.heightPx,
          _that.chapterPosition,
          _that.paragraphIndex,
          _that.reviewKey,
          _that.count,
          _that.baselineOffsetPx,
          _that.compactWidthPx,
          _that.compactHeightPx,
        );
      case _:
        return null;
    }
  }
}

/// @nodoc

class LayoutInlineItemDto_Text extends LayoutInlineItemDto {
  const LayoutInlineItemDto_Text({
    required this.value,
    required this.widthPx,
    required this.style,
    required this.chapterPosition,
    this.link,
    this.markingId,
    this.lineHeightPx,
    this.baselineOffsetPx,
    required this.baselineShiftPx,
  }) : super._();

  final String value;
  @override
  final double widthPx;
  final LayoutTextStyleDto style;
  @override
  final int chapterPosition;
  final String? link;
  final String? markingId;
  final double? lineHeightPx;
  final double? baselineOffsetPx;
  final double baselineShiftPx;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutInlineItemDto_TextCopyWith<LayoutInlineItemDto_Text> get copyWith =>
      _$LayoutInlineItemDto_TextCopyWithImpl<LayoutInlineItemDto_Text>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutInlineItemDto_Text &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.widthPx, widthPx) || other.widthPx == widthPx) &&
            (identical(other.style, style) || other.style == style) &&
            (identical(other.chapterPosition, chapterPosition) ||
                other.chapterPosition == chapterPosition) &&
            (identical(other.link, link) || other.link == link) &&
            (identical(other.markingId, markingId) ||
                other.markingId == markingId) &&
            (identical(other.lineHeightPx, lineHeightPx) ||
                other.lineHeightPx == lineHeightPx) &&
            (identical(other.baselineOffsetPx, baselineOffsetPx) ||
                other.baselineOffsetPx == baselineOffsetPx) &&
            (identical(other.baselineShiftPx, baselineShiftPx) ||
                other.baselineShiftPx == baselineShiftPx));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      value,
      widthPx,
      style,
      chapterPosition,
      link,
      markingId,
      lineHeightPx,
      baselineOffsetPx,
      baselineShiftPx,
    );
  }

  @override
  String toString() {
    return 'LayoutInlineItemDto.text(value: $value, widthPx: $widthPx, style: $style, chapterPosition: $chapterPosition, link: $link, markingId: $markingId, lineHeightPx: $lineHeightPx, baselineOffsetPx: $baselineOffsetPx, baselineShiftPx: $baselineShiftPx)';
  }
}

/// @nodoc
abstract mixin class $LayoutInlineItemDto_TextCopyWith<$Res>
    implements $LayoutInlineItemDtoCopyWith<$Res> {
  factory $LayoutInlineItemDto_TextCopyWith(
    LayoutInlineItemDto_Text value,
    $Res Function(LayoutInlineItemDto_Text) _then,
  ) = _$LayoutInlineItemDto_TextCopyWithImpl;
  @override
  @useResult
  $Res call({
    String value,
    double widthPx,
    LayoutTextStyleDto style,
    int chapterPosition,
    String? link,
    String? markingId,
    double? lineHeightPx,
    double? baselineOffsetPx,
    double baselineShiftPx,
  });
}

/// @nodoc
class _$LayoutInlineItemDto_TextCopyWithImpl<$Res>
    implements $LayoutInlineItemDto_TextCopyWith<$Res> {
  _$LayoutInlineItemDto_TextCopyWithImpl(this._self, this._then);

  final LayoutInlineItemDto_Text _self;
  final $Res Function(LayoutInlineItemDto_Text) _then;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? value = null,
    Object? widthPx = null,
    Object? style = null,
    Object? chapterPosition = null,
    Object? link = freezed,
    Object? markingId = freezed,
    Object? lineHeightPx = freezed,
    Object? baselineOffsetPx = freezed,
    Object? baselineShiftPx = null,
  }) {
    return _then(
      LayoutInlineItemDto_Text(
        value: null == value
            ? _self.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
        widthPx: null == widthPx
            ? _self.widthPx
            : widthPx // ignore: cast_nullable_to_non_nullable
                  as double,
        style: null == style
            ? _self.style
            : style // ignore: cast_nullable_to_non_nullable
                  as LayoutTextStyleDto,
        chapterPosition: null == chapterPosition
            ? _self.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int,
        link: freezed == link
            ? _self.link
            : link // ignore: cast_nullable_to_non_nullable
                  as String?,
        markingId: freezed == markingId
            ? _self.markingId
            : markingId // ignore: cast_nullable_to_non_nullable
                  as String?,
        lineHeightPx: freezed == lineHeightPx
            ? _self.lineHeightPx
            : lineHeightPx // ignore: cast_nullable_to_non_nullable
                  as double?,
        baselineOffsetPx: freezed == baselineOffsetPx
            ? _self.baselineOffsetPx
            : baselineOffsetPx // ignore: cast_nullable_to_non_nullable
                  as double?,
        baselineShiftPx: null == baselineShiftPx
            ? _self.baselineShiftPx
            : baselineShiftPx // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class LayoutInlineItemDto_Image extends LayoutInlineItemDto {
  const LayoutInlineItemDto_Image({
    required this.source,
    required this.widthPx,
    required this.heightPx,
    required this.chapterPosition,
    this.action,
    this.lineFinalWidthPx,
  }) : super._();

  final String source;
  @override
  final double widthPx;
  final double heightPx;
  @override
  final int chapterPosition;
  final String? action;
  final double? lineFinalWidthPx;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutInlineItemDto_ImageCopyWith<LayoutInlineItemDto_Image> get copyWith =>
      _$LayoutInlineItemDto_ImageCopyWithImpl<LayoutInlineItemDto_Image>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutInlineItemDto_Image &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.widthPx, widthPx) || other.widthPx == widthPx) &&
            (identical(other.heightPx, heightPx) ||
                other.heightPx == heightPx) &&
            (identical(other.chapterPosition, chapterPosition) ||
                other.chapterPosition == chapterPosition) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.lineFinalWidthPx, lineFinalWidthPx) ||
                other.lineFinalWidthPx == lineFinalWidthPx));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      source,
      widthPx,
      heightPx,
      chapterPosition,
      action,
      lineFinalWidthPx,
    );
  }

  @override
  String toString() {
    return 'LayoutInlineItemDto.image(source: $source, widthPx: $widthPx, heightPx: $heightPx, chapterPosition: $chapterPosition, action: $action, lineFinalWidthPx: $lineFinalWidthPx)';
  }
}

/// @nodoc
abstract mixin class $LayoutInlineItemDto_ImageCopyWith<$Res>
    implements $LayoutInlineItemDtoCopyWith<$Res> {
  factory $LayoutInlineItemDto_ImageCopyWith(
    LayoutInlineItemDto_Image value,
    $Res Function(LayoutInlineItemDto_Image) _then,
  ) = _$LayoutInlineItemDto_ImageCopyWithImpl;
  @override
  @useResult
  $Res call({
    String source,
    double widthPx,
    double heightPx,
    int chapterPosition,
    String? action,
    double? lineFinalWidthPx,
  });
}

/// @nodoc
class _$LayoutInlineItemDto_ImageCopyWithImpl<$Res>
    implements $LayoutInlineItemDto_ImageCopyWith<$Res> {
  _$LayoutInlineItemDto_ImageCopyWithImpl(this._self, this._then);

  final LayoutInlineItemDto_Image _self;
  final $Res Function(LayoutInlineItemDto_Image) _then;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? source = null,
    Object? widthPx = null,
    Object? heightPx = null,
    Object? chapterPosition = null,
    Object? action = freezed,
    Object? lineFinalWidthPx = freezed,
  }) {
    return _then(
      LayoutInlineItemDto_Image(
        source: null == source
            ? _self.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        widthPx: null == widthPx
            ? _self.widthPx
            : widthPx // ignore: cast_nullable_to_non_nullable
                  as double,
        heightPx: null == heightPx
            ? _self.heightPx
            : heightPx // ignore: cast_nullable_to_non_nullable
                  as double,
        chapterPosition: null == chapterPosition
            ? _self.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int,
        action: freezed == action
            ? _self.action
            : action // ignore: cast_nullable_to_non_nullable
                  as String?,
        lineFinalWidthPx: freezed == lineFinalWidthPx
            ? _self.lineFinalWidthPx
            : lineFinalWidthPx // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc

class LayoutInlineItemDto_RoleCast extends LayoutInlineItemDto {
  const LayoutInlineItemDto_RoleCast({
    required this.widthPx,
    required this.heightPx,
    required this.chapterPosition,
    required this.raw,
    required this.name,
    required this.voicePoolLabel,
    required this.quoteOrdinal,
    required this.voiceEffectMark,
  }) : super._();

  @override
  final double widthPx;
  final double heightPx;
  @override
  final int chapterPosition;
  final String raw;
  final String name;
  final String voicePoolLabel;
  final int quoteOrdinal;
  final bool voiceEffectMark;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutInlineItemDto_RoleCastCopyWith<LayoutInlineItemDto_RoleCast>
  get copyWith =>
      _$LayoutInlineItemDto_RoleCastCopyWithImpl<LayoutInlineItemDto_RoleCast>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutInlineItemDto_RoleCast &&
            (identical(other.widthPx, widthPx) || other.widthPx == widthPx) &&
            (identical(other.heightPx, heightPx) ||
                other.heightPx == heightPx) &&
            (identical(other.chapterPosition, chapterPosition) ||
                other.chapterPosition == chapterPosition) &&
            (identical(other.raw, raw) || other.raw == raw) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.voicePoolLabel, voicePoolLabel) ||
                other.voicePoolLabel == voicePoolLabel) &&
            (identical(other.quoteOrdinal, quoteOrdinal) ||
                other.quoteOrdinal == quoteOrdinal) &&
            (identical(other.voiceEffectMark, voiceEffectMark) ||
                other.voiceEffectMark == voiceEffectMark));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      widthPx,
      heightPx,
      chapterPosition,
      raw,
      name,
      voicePoolLabel,
      quoteOrdinal,
      voiceEffectMark,
    );
  }

  @override
  String toString() {
    return 'LayoutInlineItemDto.roleCast(widthPx: $widthPx, heightPx: $heightPx, chapterPosition: $chapterPosition, raw: $raw, name: $name, voicePoolLabel: $voicePoolLabel, quoteOrdinal: $quoteOrdinal, voiceEffectMark: $voiceEffectMark)';
  }
}

/// @nodoc
abstract mixin class $LayoutInlineItemDto_RoleCastCopyWith<$Res>
    implements $LayoutInlineItemDtoCopyWith<$Res> {
  factory $LayoutInlineItemDto_RoleCastCopyWith(
    LayoutInlineItemDto_RoleCast value,
    $Res Function(LayoutInlineItemDto_RoleCast) _then,
  ) = _$LayoutInlineItemDto_RoleCastCopyWithImpl;
  @override
  @useResult
  $Res call({
    double widthPx,
    double heightPx,
    int chapterPosition,
    String raw,
    String name,
    String voicePoolLabel,
    int quoteOrdinal,
    bool voiceEffectMark,
  });
}

/// @nodoc
class _$LayoutInlineItemDto_RoleCastCopyWithImpl<$Res>
    implements $LayoutInlineItemDto_RoleCastCopyWith<$Res> {
  _$LayoutInlineItemDto_RoleCastCopyWithImpl(this._self, this._then);

  final LayoutInlineItemDto_RoleCast _self;
  final $Res Function(LayoutInlineItemDto_RoleCast) _then;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? widthPx = null,
    Object? heightPx = null,
    Object? chapterPosition = null,
    Object? raw = null,
    Object? name = null,
    Object? voicePoolLabel = null,
    Object? quoteOrdinal = null,
    Object? voiceEffectMark = null,
  }) {
    return _then(
      LayoutInlineItemDto_RoleCast(
        widthPx: null == widthPx
            ? _self.widthPx
            : widthPx // ignore: cast_nullable_to_non_nullable
                  as double,
        heightPx: null == heightPx
            ? _self.heightPx
            : heightPx // ignore: cast_nullable_to_non_nullable
                  as double,
        chapterPosition: null == chapterPosition
            ? _self.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int,
        raw: null == raw
            ? _self.raw
            : raw // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _self.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        voicePoolLabel: null == voicePoolLabel
            ? _self.voicePoolLabel
            : voicePoolLabel // ignore: cast_nullable_to_non_nullable
                  as String,
        quoteOrdinal: null == quoteOrdinal
            ? _self.quoteOrdinal
            : quoteOrdinal // ignore: cast_nullable_to_non_nullable
                  as int,
        voiceEffectMark: null == voiceEffectMark
            ? _self.voiceEffectMark
            : voiceEffectMark // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class LayoutInlineItemDto_BgmScene extends LayoutInlineItemDto {
  const LayoutInlineItemDto_BgmScene({
    required this.widthPx,
    required this.heightPx,
    required this.chapterPosition,
    required this.paragraphIndex,
    required this.poolName,
    required this.trackName,
  }) : super._();

  @override
  final double widthPx;
  final double heightPx;
  @override
  final int chapterPosition;
  final int paragraphIndex;
  final String poolName;
  final String trackName;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutInlineItemDto_BgmSceneCopyWith<LayoutInlineItemDto_BgmScene>
  get copyWith =>
      _$LayoutInlineItemDto_BgmSceneCopyWithImpl<LayoutInlineItemDto_BgmScene>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutInlineItemDto_BgmScene &&
            (identical(other.widthPx, widthPx) || other.widthPx == widthPx) &&
            (identical(other.heightPx, heightPx) ||
                other.heightPx == heightPx) &&
            (identical(other.chapterPosition, chapterPosition) ||
                other.chapterPosition == chapterPosition) &&
            (identical(other.paragraphIndex, paragraphIndex) ||
                other.paragraphIndex == paragraphIndex) &&
            (identical(other.poolName, poolName) ||
                other.poolName == poolName) &&
            (identical(other.trackName, trackName) ||
                other.trackName == trackName));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      widthPx,
      heightPx,
      chapterPosition,
      paragraphIndex,
      poolName,
      trackName,
    );
  }

  @override
  String toString() {
    return 'LayoutInlineItemDto.bgmScene(widthPx: $widthPx, heightPx: $heightPx, chapterPosition: $chapterPosition, paragraphIndex: $paragraphIndex, poolName: $poolName, trackName: $trackName)';
  }
}

/// @nodoc
abstract mixin class $LayoutInlineItemDto_BgmSceneCopyWith<$Res>
    implements $LayoutInlineItemDtoCopyWith<$Res> {
  factory $LayoutInlineItemDto_BgmSceneCopyWith(
    LayoutInlineItemDto_BgmScene value,
    $Res Function(LayoutInlineItemDto_BgmScene) _then,
  ) = _$LayoutInlineItemDto_BgmSceneCopyWithImpl;
  @override
  @useResult
  $Res call({
    double widthPx,
    double heightPx,
    int chapterPosition,
    int paragraphIndex,
    String poolName,
    String trackName,
  });
}

/// @nodoc
class _$LayoutInlineItemDto_BgmSceneCopyWithImpl<$Res>
    implements $LayoutInlineItemDto_BgmSceneCopyWith<$Res> {
  _$LayoutInlineItemDto_BgmSceneCopyWithImpl(this._self, this._then);

  final LayoutInlineItemDto_BgmScene _self;
  final $Res Function(LayoutInlineItemDto_BgmScene) _then;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? widthPx = null,
    Object? heightPx = null,
    Object? chapterPosition = null,
    Object? paragraphIndex = null,
    Object? poolName = null,
    Object? trackName = null,
  }) {
    return _then(
      LayoutInlineItemDto_BgmScene(
        widthPx: null == widthPx
            ? _self.widthPx
            : widthPx // ignore: cast_nullable_to_non_nullable
                  as double,
        heightPx: null == heightPx
            ? _self.heightPx
            : heightPx // ignore: cast_nullable_to_non_nullable
                  as double,
        chapterPosition: null == chapterPosition
            ? _self.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int,
        paragraphIndex: null == paragraphIndex
            ? _self.paragraphIndex
            : paragraphIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        poolName: null == poolName
            ? _self.poolName
            : poolName // ignore: cast_nullable_to_non_nullable
                  as String,
        trackName: null == trackName
            ? _self.trackName
            : trackName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class LayoutInlineItemDto_Review extends LayoutInlineItemDto {
  const LayoutInlineItemDto_Review({
    required this.widthPx,
    required this.heightPx,
    required this.chapterPosition,
    required this.paragraphIndex,
    required this.reviewKey,
    required this.count,
    required this.baselineOffsetPx,
    this.compactWidthPx,
    this.compactHeightPx,
  }) : super._();

  @override
  final double widthPx;
  final double heightPx;
  @override
  final int chapterPosition;
  final int paragraphIndex;
  final String reviewKey;
  final int count;
  final double baselineOffsetPx;
  final double? compactWidthPx;
  final double? compactHeightPx;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LayoutInlineItemDto_ReviewCopyWith<LayoutInlineItemDto_Review>
  get copyWith =>
      _$LayoutInlineItemDto_ReviewCopyWithImpl<LayoutInlineItemDto_Review>(
        this,
        _$identity,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LayoutInlineItemDto_Review &&
            (identical(other.widthPx, widthPx) || other.widthPx == widthPx) &&
            (identical(other.heightPx, heightPx) ||
                other.heightPx == heightPx) &&
            (identical(other.chapterPosition, chapterPosition) ||
                other.chapterPosition == chapterPosition) &&
            (identical(other.paragraphIndex, paragraphIndex) ||
                other.paragraphIndex == paragraphIndex) &&
            (identical(other.reviewKey, reviewKey) ||
                other.reviewKey == reviewKey) &&
            (identical(other.count, count) || other.count == count) &&
            (identical(other.baselineOffsetPx, baselineOffsetPx) ||
                other.baselineOffsetPx == baselineOffsetPx) &&
            (identical(other.compactWidthPx, compactWidthPx) ||
                other.compactWidthPx == compactWidthPx) &&
            (identical(other.compactHeightPx, compactHeightPx) ||
                other.compactHeightPx == compactHeightPx));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      widthPx,
      heightPx,
      chapterPosition,
      paragraphIndex,
      reviewKey,
      count,
      baselineOffsetPx,
      compactWidthPx,
      compactHeightPx,
    );
  }

  @override
  String toString() {
    return 'LayoutInlineItemDto.review(widthPx: $widthPx, heightPx: $heightPx, chapterPosition: $chapterPosition, paragraphIndex: $paragraphIndex, reviewKey: $reviewKey, count: $count, baselineOffsetPx: $baselineOffsetPx, compactWidthPx: $compactWidthPx, compactHeightPx: $compactHeightPx)';
  }
}

/// @nodoc
abstract mixin class $LayoutInlineItemDto_ReviewCopyWith<$Res>
    implements $LayoutInlineItemDtoCopyWith<$Res> {
  factory $LayoutInlineItemDto_ReviewCopyWith(
    LayoutInlineItemDto_Review value,
    $Res Function(LayoutInlineItemDto_Review) _then,
  ) = _$LayoutInlineItemDto_ReviewCopyWithImpl;
  @override
  @useResult
  $Res call({
    double widthPx,
    double heightPx,
    int chapterPosition,
    int paragraphIndex,
    String reviewKey,
    int count,
    double baselineOffsetPx,
    double? compactWidthPx,
    double? compactHeightPx,
  });
}

/// @nodoc
class _$LayoutInlineItemDto_ReviewCopyWithImpl<$Res>
    implements $LayoutInlineItemDto_ReviewCopyWith<$Res> {
  _$LayoutInlineItemDto_ReviewCopyWithImpl(this._self, this._then);

  final LayoutInlineItemDto_Review _self;
  final $Res Function(LayoutInlineItemDto_Review) _then;

  /// Create a copy of LayoutInlineItemDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? widthPx = null,
    Object? heightPx = null,
    Object? chapterPosition = null,
    Object? paragraphIndex = null,
    Object? reviewKey = null,
    Object? count = null,
    Object? baselineOffsetPx = null,
    Object? compactWidthPx = freezed,
    Object? compactHeightPx = freezed,
  }) {
    return _then(
      LayoutInlineItemDto_Review(
        widthPx: null == widthPx
            ? _self.widthPx
            : widthPx // ignore: cast_nullable_to_non_nullable
                  as double,
        heightPx: null == heightPx
            ? _self.heightPx
            : heightPx // ignore: cast_nullable_to_non_nullable
                  as double,
        chapterPosition: null == chapterPosition
            ? _self.chapterPosition
            : chapterPosition // ignore: cast_nullable_to_non_nullable
                  as int,
        paragraphIndex: null == paragraphIndex
            ? _self.paragraphIndex
            : paragraphIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        reviewKey: null == reviewKey
            ? _self.reviewKey
            : reviewKey // ignore: cast_nullable_to_non_nullable
                  as String,
        count: null == count
            ? _self.count
            : count // ignore: cast_nullable_to_non_nullable
                  as int,
        baselineOffsetPx: null == baselineOffsetPx
            ? _self.baselineOffsetPx
            : baselineOffsetPx // ignore: cast_nullable_to_non_nullable
                  as double,
        compactWidthPx: freezed == compactWidthPx
            ? _self.compactWidthPx
            : compactWidthPx // ignore: cast_nullable_to_non_nullable
                  as double?,
        compactHeightPx: freezed == compactHeightPx
            ? _self.compactHeightPx
            : compactHeightPx // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}
