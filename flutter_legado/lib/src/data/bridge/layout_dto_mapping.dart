import 'dart:typed_data';

import '../../bridge/layout_dto.dart' as dto;

// 排版 DTO 适配只进行字段映射，不字符串序列化。— Codex + Bridge
void _keys(Map<String, dynamic> value, Set<String> keys) {
  if (value.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('阅读布局存在未知字段');
  }
}

dto.LayoutValueDto layoutValueToDto(Object? v) => dto.LayoutValueDto(
  kind: switch (v) {
    null => dto.LayoutValueKind.null_,
    bool() => dto.LayoutValueKind.boolean,
    int() => dto.LayoutValueKind.integer,
    num() => dto.LayoutValueKind.decimal,
    String() => dto.LayoutValueKind.text,
    List() => dto.LayoutValueKind.array,
    Map() => dto.LayoutValueKind.object,
    _ => throw const FormatException('阅读布局扩展值无效'),
  },
  boolean: v is bool ? v : null,
  integer: v is int ? v : null,
  positive: null,
  decimal: v is double ? v : null,
  text: v is String ? v : null,
  array: v is List ? v.map(layoutValueToDto).toList() : [],
  object: v is Map
      ? v.map((k, v) => MapEntry(k.toString(), layoutValueToDto(v)))
      : {},
);
Object? layoutValueFromDto(dto.LayoutValueDto v) => switch (v.kind) {
  dto.LayoutValueKind.null_ => null,
  dto.LayoutValueKind.boolean => v.boolean,
  dto.LayoutValueKind.integer => v.integer,
  dto.LayoutValueKind.positive => v.positive?.toInt(),
  dto.LayoutValueKind.decimal => v.decimal,
  dto.LayoutValueKind.text => v.text,
  dto.LayoutValueKind.array => v.array.map(layoutValueFromDto).toList(),
  dto.LayoutValueKind.object => v.object.map(
    (k, v) => MapEntry(k, layoutValueFromDto(v)),
  ),
};

dto.LayoutBackgroundImageDto backgroundImageToDto(Map<String, dynamic> m) {
  _keys(m, {
    'source',
    'fit',
    'scale',
    'ninePatchLeft',
    'ninePatchRight',
    'ninePatchTop',
    'ninePatchBottom',
    'lengthOffsetLeftPx',
    'lengthOffsetRightPx',
    'contentInsetLeftPx',
    'contentInsetRightPx',
    'contentInsetTopPx',
    'contentInsetBottomPx',
    'contentBandHeightPx',
  });
  return dto.LayoutBackgroundImageDto(
    source: m['source'] as String,
    fit: (m['fit'] as num).toInt(),
    scale: (m['scale'] as num).toDouble(),
    ninePatchLeft: ((m['ninePatchLeft'] ?? 0.1) as num).toDouble(),
    ninePatchRight: ((m['ninePatchRight'] ?? 0.1) as num).toDouble(),
    ninePatchTop: ((m['ninePatchTop'] ?? 0.1) as num).toDouble(),
    ninePatchBottom: ((m['ninePatchBottom'] ?? 0.1) as num).toDouble(),
    lengthOffsetLeftPx: ((m['lengthOffsetLeftPx'] ?? 0.0) as num).toDouble(),
    lengthOffsetRightPx: ((m['lengthOffsetRightPx'] ?? 0.0) as num).toDouble(),
    contentInsetLeftPx: ((m['contentInsetLeftPx'] ?? 0.0) as num).toDouble(),
    contentInsetRightPx: ((m['contentInsetRightPx'] ?? 0.0) as num).toDouble(),
    contentInsetTopPx: ((m['contentInsetTopPx'] ?? 0.0) as num).toDouble(),
    contentInsetBottomPx: ((m['contentInsetBottomPx'] ?? 0.0) as num)
        .toDouble(),
    contentBandHeightPx: ((m['contentBandHeightPx'] ?? 0.0) as num).toDouble(),
  );
}

Map<String, dynamic> backgroundImageFromDto(
  dto.LayoutBackgroundImageDto value,
) => {
  'source': value.source,
  'fit': value.fit,
  'scale': value.scale,
  'ninePatchLeft': value.ninePatchLeft,
  'ninePatchRight': value.ninePatchRight,
  'ninePatchTop': value.ninePatchTop,
  'ninePatchBottom': value.ninePatchBottom,
  'lengthOffsetLeftPx': value.lengthOffsetLeftPx,
  'lengthOffsetRightPx': value.lengthOffsetRightPx,
  'contentInsetLeftPx': value.contentInsetLeftPx,
  'contentInsetRightPx': value.contentInsetRightPx,
  'contentInsetTopPx': value.contentInsetTopPx,
  'contentInsetBottomPx': value.contentInsetBottomPx,
  'contentBandHeightPx': value.contentBandHeightPx,
};

dto.LayoutTextStyleDto textStyleToDto(Map<String, dynamic> m) {
  _keys(m, {
    'colorArgb',
    'inheritColor',
    'fontSizePx',
    'fontPath',
    'fontWeight',
    'italic',
    'backgroundArgb',
    'underline',
    'shadow',
    'backgroundImage',
    'fontFamily',
    'linearText',
    'strikeThrough',
    'nativeUnderline',
    'matchSpacingBeforePx',
    'matchSpacingAfterPx',
    'linePadTopPx',
    'linePadBottomPx',
  });
  return dto.LayoutTextStyleDto(
    colorArgb: (m['colorArgb'] as num).toInt(),
    inheritColor: (m['inheritColor'] ?? false) as bool,
    fontSizePx: (m['fontSizePx'] as num).toDouble(),
    fontPath: (m['fontPath'] ?? '') as String,
    fontWeight: ((m['fontWeight'] ?? 400) as num).toInt(),
    italic: (m['italic'] ?? false) as bool,
    backgroundArgb: m['backgroundArgb'] == null
        ? null
        : (m['backgroundArgb'] as num).toInt(),
    underline: m['underline'] == null ? null : layoutValueToDto(m['underline']),
    shadow: m['shadow'] == null ? null : layoutValueToDto(m['shadow']),
    backgroundImage: m['backgroundImage'] == null
        ? null
        : backgroundImageToDto(
            Map<String, dynamic>.from(m['backgroundImage'] as Map),
          ),
    fontFamily: (m['fontFamily'] ?? 'sans-serif') as String,
    linearText: (m['linearText'] ?? false) as bool,
    strikeThrough: (m['strikeThrough'] ?? false) as bool,
    nativeUnderline: (m['nativeUnderline'] ?? false) as bool,
    matchSpacingBeforePx: ((m['matchSpacingBeforePx'] ?? 0.0) as num)
        .toDouble(),
    matchSpacingAfterPx: ((m['matchSpacingAfterPx'] ?? 0.0) as num).toDouble(),
    linePadTopPx: ((m['linePadTopPx'] ?? 0.0) as num).toDouble(),
    linePadBottomPx: ((m['linePadBottomPx'] ?? 0.0) as num).toDouble(),
  );
}

Map<String, dynamic> textStyleFromDto(dto.LayoutTextStyleDto value) => {
  'colorArgb': value.colorArgb,
  'inheritColor': value.inheritColor,
  'fontSizePx': value.fontSizePx,
  'fontPath': value.fontPath,
  'fontWeight': value.fontWeight,
  'italic': value.italic,
  'backgroundArgb': value.backgroundArgb,
  'underline': value.underline == null
      ? null
      : layoutValueFromDto(value.underline!),
  'shadow': value.shadow == null ? null : layoutValueFromDto(value.shadow!),
  'backgroundImage': value.backgroundImage == null
      ? null
      : backgroundImageFromDto(value.backgroundImage!),
  'fontFamily': value.fontFamily,
  'linearText': value.linearText,
  'strikeThrough': value.strikeThrough,
  'nativeUnderline': value.nativeUnderline,
  'matchSpacingBeforePx': value.matchSpacingBeforePx,
  'matchSpacingAfterPx': value.matchSpacingAfterPx,
  'linePadTopPx': value.linePadTopPx,
  'linePadBottomPx': value.linePadBottomPx,
};

dto.LayoutPageUnderlineDto pageUnderlineToDto(Map<String, dynamic> m) {
  _keys(m, {
    'colorArgb',
    'widthPx',
    'offsetPx',
    'extendToColumn',
    'dashed',
    'dashOnPx',
    'dashOffPx',
  });
  return dto.LayoutPageUnderlineDto(
    colorArgb: (m['colorArgb'] as num).toInt(),
    widthPx: (m['widthPx'] as num).toDouble(),
    offsetPx: (m['offsetPx'] as num).toDouble(),
    extendToColumn: m['extendToColumn'] as bool,
    dashed: m['dashed'] as bool,
    dashOnPx: ((m['dashOnPx'] ?? 6.0) as num).toDouble(),
    dashOffPx: ((m['dashOffPx'] ?? 6.0) as num).toDouble(),
  );
}

Map<String, dynamic> pageUnderlineFromDto(dto.LayoutPageUnderlineDto value) => {
  'colorArgb': value.colorArgb,
  'widthPx': value.widthPx,
  'offsetPx': value.offsetPx,
  'extendToColumn': value.extendToColumn,
  'dashed': value.dashed,
  'dashOnPx': value.dashOnPx,
  'dashOffPx': value.dashOffPx,
};

dto.LayoutCastOptionsDto castOptionsToDto(Map<String, dynamic> m) {
  _keys(m, {
    'enabled',
    'profiles',
    'chapterEffects',
    'characterEffects',
    'bubbles',
  });
  return dto.LayoutCastOptionsDto(
    enabled: (m['enabled'] ?? false) as bool,
    profiles: ((m['profiles'] ?? <dynamic, dynamic>{}) as Map).map(
      (key, item) => MapEntry(
        key as String,
        castProfileToDto(Map<String, dynamic>.from(item as Map)),
      ),
    ),
    chapterEffects: ((m['chapterEffects'] ?? <dynamic, dynamic>{}) as Map).map(
      (key, item) => MapEntry(int.parse(key.toString()), item as String),
    ),
    characterEffects: ((m['characterEffects'] ?? <dynamic, dynamic>{}) as Map)
        .map((key, item) => MapEntry(key as String, item as String)),
    bubbles: ((m['bubbles'] ?? <dynamic, dynamic>{}) as Map).map(
      (key, item) => MapEntry(key as String, layoutValueToDto(item)),
    ),
  );
}

Map<String, dynamic> castOptionsFromDto(dto.LayoutCastOptionsDto value) => {
  'enabled': value.enabled,
  'profiles': value.profiles.map(
    (key, item) => MapEntry(key, castProfileFromDto(item)),
  ),
  'chapterEffects': value.chapterEffects.map(
    (key, item) => MapEntry(key.toString(), item),
  ),
  'characterEffects': value.characterEffects.map(
    (key, item) => MapEntry(key, item),
  ),
  'bubbles': value.bubbles.map(
    (key, item) => MapEntry(key, layoutValueFromDto(item)),
  ),
};

dto.LayoutCastProfileDto castProfileToDto(Map<String, dynamic> m) {
  _keys(m, {'characterId', 'avatarUri'});
  return dto.LayoutCastProfileDto(
    characterId: m['characterId'] as String,
    avatarUri: m['avatarUri'] as String,
  );
}

Map<String, dynamic> castProfileFromDto(dto.LayoutCastProfileDto value) => {
  'characterId': value.characterId,
  'avatarUri': value.avatarUri,
};

dto.LayoutConfigDto configToDto(Map<String, dynamic> m) {
  _keys(m, {
    'breakMode',
    'chapterIndex',
    'chapterTitle',
    'viewportWidthPx',
    'viewportHeightPx',
    'paddingLeftPx',
    'paddingTopPx',
    'paddingRightPx',
    'paddingBottomPx',
    'lineHeightPx',
    'baselineOffsetPx',
    'paragraphSpacingPx',
    'letterSpacingPx',
    'revision',
    'decoration',
    'titleTopSpacingPx',
    'titleBottomSpacingPx',
    'titleParagraphSpacingPx',
    'titleSegmentSpacingPx',
    'titlePageCenterVertical',
    'columnCount',
    'lineSpacingMultiplier',
    'continuousScroll',
    'singleImageStyle',
    'chapterEndPaddingPx',
    'textBottomJustify',
    'htmlLineSpacingAddPx',
    'pageUnderline',
    'inlineImagesPreserveScrollLine',
    'emphasisUnderlineStyle',
    'castOptions',
  });
  return dto.LayoutConfigDto(
    breakMode: dto.LayoutBreakModeDto.values.byName(
      (m['breakMode'] ?? 'chinese') as String,
    ),
    chapterIndex: (m['chapterIndex'] as num).toInt(),
    chapterTitle: m['chapterTitle'] as String,
    viewportWidthPx: (m['viewportWidthPx'] as num).toInt(),
    viewportHeightPx: (m['viewportHeightPx'] as num).toInt(),
    paddingLeftPx: (m['paddingLeftPx'] as num).toDouble(),
    paddingTopPx: (m['paddingTopPx'] as num).toDouble(),
    paddingRightPx: (m['paddingRightPx'] as num).toDouble(),
    paddingBottomPx: (m['paddingBottomPx'] as num).toDouble(),
    lineHeightPx: (m['lineHeightPx'] as num).toDouble(),
    baselineOffsetPx: (m['baselineOffsetPx'] as num).toDouble(),
    paragraphSpacingPx: ((m['paragraphSpacingPx'] ?? 0.0) as num).toDouble(),
    letterSpacingPx: ((m['letterSpacingPx'] ?? 0.0) as num).toDouble(),
    revision: ((m['revision'] ?? 0) as num).toInt(),
    decoration: layoutValueToDto(
      (m['decoration'] ??
          <String, dynamic>{
            'header': null,
            'footer': null,
            'bookmarkBadge': null,
          }),
    ),
    titleTopSpacingPx: ((m['titleTopSpacingPx'] ?? 0.0) as num).toDouble(),
    titleBottomSpacingPx: ((m['titleBottomSpacingPx'] ?? 0.0) as num)
        .toDouble(),
    titleParagraphSpacingPx: m['titleParagraphSpacingPx'] == null
        ? null
        : (m['titleParagraphSpacingPx'] as num).toDouble(),
    titleSegmentSpacingPx: ((m['titleSegmentSpacingPx'] ?? 0.0) as num)
        .toDouble(),
    titlePageCenterVertical: (m['titlePageCenterVertical'] ?? false) as bool,
    columnCount: ((m['columnCount'] ?? 1) as num).toInt(),
    lineSpacingMultiplier: ((m['lineSpacingMultiplier'] ?? 1.0) as num)
        .toDouble(),
    continuousScroll: (m['continuousScroll'] ?? false) as bool,
    singleImageStyle: (m['singleImageStyle'] ?? false) as bool,
    chapterEndPaddingPx: ((m['chapterEndPaddingPx'] ?? 0.0) as num).toDouble(),
    textBottomJustify: (m['textBottomJustify'] ?? false) as bool,
    htmlLineSpacingAddPx: ((m['htmlLineSpacingAddPx'] ?? 0.0) as num)
        .toDouble(),
    pageUnderline: m['pageUnderline'] == null
        ? null
        : pageUnderlineToDto(
            Map<String, dynamic>.from(m['pageUnderline'] as Map),
          ),
    inlineImagesPreserveScrollLine:
        (m['inlineImagesPreserveScrollLine'] ?? true) as bool,
    emphasisUnderlineStyle: m['emphasisUnderlineStyle'] == null
        ? null
        : layoutValueToDto(m['emphasisUnderlineStyle']),
    castOptions: castOptionsToDto(
      Map<String, dynamic>.from(
        (m['castOptions'] ?? <String, dynamic>{}) as Map,
      ),
    ),
  );
}

Map<String, dynamic> configFromDto(dto.LayoutConfigDto value) => {
  'breakMode': value.breakMode.name,
  'chapterIndex': value.chapterIndex,
  'chapterTitle': value.chapterTitle,
  'viewportWidthPx': value.viewportWidthPx,
  'viewportHeightPx': value.viewportHeightPx,
  'paddingLeftPx': value.paddingLeftPx,
  'paddingTopPx': value.paddingTopPx,
  'paddingRightPx': value.paddingRightPx,
  'paddingBottomPx': value.paddingBottomPx,
  'lineHeightPx': value.lineHeightPx,
  'baselineOffsetPx': value.baselineOffsetPx,
  'paragraphSpacingPx': value.paragraphSpacingPx,
  'letterSpacingPx': value.letterSpacingPx,
  'revision': value.revision,
  'decoration': layoutValueFromDto(value.decoration),
  'titleTopSpacingPx': value.titleTopSpacingPx,
  'titleBottomSpacingPx': value.titleBottomSpacingPx,
  'titleParagraphSpacingPx': value.titleParagraphSpacingPx,
  'titleSegmentSpacingPx': value.titleSegmentSpacingPx,
  'titlePageCenterVertical': value.titlePageCenterVertical,
  'columnCount': value.columnCount,
  'lineSpacingMultiplier': value.lineSpacingMultiplier,
  'continuousScroll': value.continuousScroll,
  'singleImageStyle': value.singleImageStyle,
  'chapterEndPaddingPx': value.chapterEndPaddingPx,
  'textBottomJustify': value.textBottomJustify,
  'htmlLineSpacingAddPx': value.htmlLineSpacingAddPx,
  'pageUnderline': value.pageUnderline == null
      ? null
      : pageUnderlineFromDto(value.pageUnderline!),
  'inlineImagesPreserveScrollLine': value.inlineImagesPreserveScrollLine,
  'emphasisUnderlineStyle': value.emphasisUnderlineStyle == null
      ? null
      : layoutValueFromDto(value.emphasisUnderlineStyle!),
  'castOptions': castOptionsFromDto(value.castOptions),
};

dto.LayoutParagraphDto paragraphToDto(Map<String, dynamic> m) {
  _keys(m, {
    'text',
    'clusters',
    'clusterWidthsPx',
    'style',
    'chapterPosition',
    'indentCharacters',
    'alignment',
    'isTitle',
    'link',
    'lineHeightPx',
    'baselineOffsetPx',
    'lineSpacingMultiplier',
    'letterSpacingPx',
    'indentWidthPx',
  });
  return dto.LayoutParagraphDto(
    text: m['text'] as String,
    clusters: (m['clusters'] as List).map((item) => item as String).toList(),
    clusterWidthsPx: Float32List.fromList(
      (m['clusterWidthsPx'] as List)
          .map((item) => (item as num).toDouble())
          .toList(),
    ),
    style: textStyleToDto(Map<String, dynamic>.from(m['style'] as Map)),
    chapterPosition: (m['chapterPosition'] as num).toInt(),
    indentCharacters: ((m['indentCharacters'] ?? 0) as num).toInt(),
    alignment: dto.LayoutAlignmentDto.values.byName(
      (m['alignment'] ?? 'start') as String,
    ),
    isTitle: (m['isTitle'] ?? false) as bool,
    link: m['link'] == null ? null : m['link'] as String,
    lineHeightPx: m['lineHeightPx'] == null
        ? null
        : (m['lineHeightPx'] as num).toDouble(),
    baselineOffsetPx: m['baselineOffsetPx'] == null
        ? null
        : (m['baselineOffsetPx'] as num).toDouble(),
    lineSpacingMultiplier: m['lineSpacingMultiplier'] == null
        ? null
        : (m['lineSpacingMultiplier'] as num).toDouble(),
    letterSpacingPx: m['letterSpacingPx'] == null
        ? null
        : (m['letterSpacingPx'] as num).toDouble(),
    indentWidthPx: m['indentWidthPx'] == null
        ? null
        : (m['indentWidthPx'] as num).toDouble(),
  );
}

Map<String, dynamic> paragraphFromDto(dto.LayoutParagraphDto value) => {
  'text': value.text,
  'clusters': value.clusters.map((item) => item).toList(),
  'clusterWidthsPx': value.clusterWidthsPx.map((item) => item).toList(),
  'style': textStyleFromDto(value.style),
  'chapterPosition': value.chapterPosition,
  'indentCharacters': value.indentCharacters,
  'alignment': value.alignment.name,
  'isTitle': value.isTitle,
  'link': value.link,
  'lineHeightPx': value.lineHeightPx,
  'baselineOffsetPx': value.baselineOffsetPx,
  'lineSpacingMultiplier': value.lineSpacingMultiplier,
  'letterSpacingPx': value.letterSpacingPx,
  'indentWidthPx': value.indentWidthPx,
};

dto.LayoutInlineParagraphDto inlineParagraphToDto(Map<String, dynamic> m) {
  _keys(m, {
    'items',
    'indentCharacters',
    'alignment',
    'lineHeightPx',
    'baselineOffsetPx',
    'baseTextSizePx',
    'emphasized',
    'titleSpacingScale',
    'lineSpacingMultiplier',
    'letterSpacingPx',
    'indentWidthPx',
    'restLineIndentWidthPx',
    'leadingIndentItems',
    'decorations',
    'justifyAtWordBoundaries',
  });
  return dto.LayoutInlineParagraphDto(
    items: (m['items'] as List)
        .map((item) => inlineItemToDto(Map<String, dynamic>.from(item as Map)))
        .toList(),
    indentCharacters: (m['indentCharacters'] as num).toInt(),
    alignment: dto.LayoutAlignmentDto.values.byName(m['alignment'] as String),
    lineHeightPx: (m['lineHeightPx'] as num).toDouble(),
    baselineOffsetPx: (m['baselineOffsetPx'] as num).toDouble(),
    baseTextSizePx: (m['baseTextSizePx'] as num).toDouble(),
    emphasized: (m['emphasized'] ?? false) as bool,
    titleSpacingScale: ((m['titleSpacingScale'] ?? 1.0) as num).toDouble(),
    lineSpacingMultiplier: ((m['lineSpacingMultiplier'] ?? 1.0) as num)
        .toDouble(),
    letterSpacingPx: m['letterSpacingPx'] == null
        ? null
        : (m['letterSpacingPx'] as num).toDouble(),
    indentWidthPx: m['indentWidthPx'] == null
        ? null
        : (m['indentWidthPx'] as num).toDouble(),
    restLineIndentWidthPx: ((m['restLineIndentWidthPx'] ?? 0.0) as num)
        .toDouble(),
    leadingIndentItems: BigInt.from(
      ((m['leadingIndentItems'] ?? 0) as num).toInt(),
    ),
    decorations: ((m['decorations'] ?? <dynamic>[]) as List)
        .map(
          (item) =>
              paragraphDecorationToDto(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    justifyAtWordBoundaries: (m['justifyAtWordBoundaries'] ?? false) as bool,
  );
}

dto.LayoutParagraphDecorationDto paragraphDecorationToDto(
  Map<String, dynamic> m,
) {
  _keys(m, {'kind', 'colorArgb', 'sizePx', 'leadingOffsetPx'});
  return dto.LayoutParagraphDecorationDto(
    kind: dto.LayoutDecorationKindDto.values.byName(m['kind'] as String),
    colorArgb: m['colorArgb'] == null ? null : (m['colorArgb'] as num).toInt(),
    sizePx: (m['sizePx'] as num).toDouble(),
    leadingOffsetPx: ((m['leadingOffsetPx'] ?? 0.0) as num).toDouble(),
  );
}

Map<String, dynamic> paragraphDecorationFromDto(
  dto.LayoutParagraphDecorationDto value,
) => {
  'kind': value.kind.name,
  'colorArgb': value.colorArgb,
  'sizePx': value.sizePx,
  'leadingOffsetPx': value.leadingOffsetPx,
};

dto.LayoutBlockDto blockToDto(Map<String, dynamic> m) {
  switch (m['type']) {
    case 'paragraph':
      _keys(m, {'type', 'value'});
      return dto.LayoutBlockDto.paragraph(
        value: paragraphToDto(Map<String, dynamic>.from(m['value'] as Map)),
      );
    case 'inlineParagraph':
      return dto.LayoutBlockDto.inlineParagraph(
        inlineParagraphToDto({...m}..remove('type')),
      );
    case 'image':
      _keys(m, {
        'type',
        'source',
        'intrinsicWidthPx',
        'intrinsicHeightPx',
        'chapterPosition',
        'action',
        'horizontalAlignment',
        'scaleMode',
        'pageBreakBefore',
        'pageBreakAfter',
      });
      return dto.LayoutBlockDto.image(
        source: m['source'] as String,
        intrinsicWidthPx: (m['intrinsicWidthPx'] as num).toDouble(),
        intrinsicHeightPx: (m['intrinsicHeightPx'] as num).toDouble(),
        chapterPosition: (m['chapterPosition'] as num).toInt(),
        action: m['action'] == null ? null : m['action'] as String,
        horizontalAlignment: dto.LayoutAlignmentDto.values.byName(
          (m['horizontalAlignment'] ?? 'center') as String,
        ),
        scaleMode: dto.LayoutImageScaleDto.values.byName(
          (m['scaleMode'] ?? 'containNoUpscale') as String,
        ),
        pageBreakBefore: (m['pageBreakBefore'] ?? false) as bool,
        pageBreakAfter: (m['pageBreakAfter'] ?? false) as bool,
      );
    case 'blankLine':
      _keys(m, {
        'type',
        'chapterPosition',
        'lineHeightPx',
        'lineSpacingMultiplier',
      });
      return dto.LayoutBlockDto.blankLine(
        chapterPosition: (m['chapterPosition'] as num).toInt(),
        lineHeightPx: (m['lineHeightPx'] as num).toDouble(),
        lineSpacingMultiplier: (m['lineSpacingMultiplier'] as num).toDouble(),
      );
    case 'rule':
      _keys(m, {'type', 'colorArgb', 'widthPx', 'verticalPaddingPx', 'dashed'});
      return dto.LayoutBlockDto.rule(
        colorArgb: (m['colorArgb'] as num).toInt(),
        widthPx: (m['widthPx'] as num).toDouble(),
        verticalPaddingPx: (m['verticalPaddingPx'] as num).toDouble(),
        dashed: (m['dashed'] ?? false) as bool,
      );
    case 'pageBreak':
      _keys(m, {'type'});
      return dto.LayoutBlockDto.pageBreak();
    default:
      throw const FormatException('阅读布局块或行内类型无效');
  }
}

dto.LayoutInlineItemDto inlineItemToDto(Map<String, dynamic> m) {
  switch (m['type']) {
    case 'text':
      _keys(m, {
        'type',
        'value',
        'widthPx',
        'style',
        'chapterPosition',
        'link',
        'markingId',
        'lineHeightPx',
        'baselineOffsetPx',
        'baselineShiftPx',
      });
      return dto.LayoutInlineItemDto.text(
        value: m['value'] as String,
        widthPx: (m['widthPx'] as num).toDouble(),
        style: textStyleToDto(Map<String, dynamic>.from(m['style'] as Map)),
        chapterPosition: (m['chapterPosition'] as num).toInt(),
        link: m['link'] == null ? null : m['link'] as String,
        markingId: m['markingId'] == null ? null : m['markingId'] as String,
        lineHeightPx: m['lineHeightPx'] == null
            ? null
            : (m['lineHeightPx'] as num).toDouble(),
        baselineOffsetPx: m['baselineOffsetPx'] == null
            ? null
            : (m['baselineOffsetPx'] as num).toDouble(),
        baselineShiftPx: ((m['baselineShiftPx'] ?? 0.0) as num).toDouble(),
      );
    case 'image':
      _keys(m, {
        'type',
        'source',
        'widthPx',
        'heightPx',
        'chapterPosition',
        'action',
        'lineFinalWidthPx',
      });
      return dto.LayoutInlineItemDto.image(
        source: m['source'] as String,
        widthPx: (m['widthPx'] as num).toDouble(),
        heightPx: (m['heightPx'] as num).toDouble(),
        chapterPosition: (m['chapterPosition'] as num).toInt(),
        action: m['action'] == null ? null : m['action'] as String,
        lineFinalWidthPx: m['lineFinalWidthPx'] == null
            ? null
            : (m['lineFinalWidthPx'] as num).toDouble(),
      );
    case 'roleCast':
      _keys(m, {
        'type',
        'widthPx',
        'heightPx',
        'chapterPosition',
        'raw',
        'name',
        'voicePoolLabel',
        'quoteOrdinal',
        'voiceEffectMark',
      });
      return dto.LayoutInlineItemDto.roleCast(
        widthPx: (m['widthPx'] as num).toDouble(),
        heightPx: (m['heightPx'] as num).toDouble(),
        chapterPosition: (m['chapterPosition'] as num).toInt(),
        raw: m['raw'] as String,
        name: m['name'] as String,
        voicePoolLabel: m['voicePoolLabel'] as String,
        quoteOrdinal: (m['quoteOrdinal'] as num).toInt(),
        voiceEffectMark: (m['voiceEffectMark'] ?? false) as bool,
      );
    case 'bgmScene':
      _keys(m, {
        'type',
        'widthPx',
        'heightPx',
        'chapterPosition',
        'paragraphIndex',
        'poolName',
        'trackName',
      });
      return dto.LayoutInlineItemDto.bgmScene(
        widthPx: (m['widthPx'] as num).toDouble(),
        heightPx: (m['heightPx'] as num).toDouble(),
        chapterPosition: (m['chapterPosition'] as num).toInt(),
        paragraphIndex: (m['paragraphIndex'] as num).toInt(),
        poolName: m['poolName'] as String,
        trackName: m['trackName'] as String,
      );
    case 'review':
      _keys(m, {
        'type',
        'widthPx',
        'heightPx',
        'chapterPosition',
        'paragraphIndex',
        'reviewKey',
        'count',
        'baselineOffsetPx',
        'compactWidthPx',
        'compactHeightPx',
      });
      return dto.LayoutInlineItemDto.review(
        widthPx: (m['widthPx'] as num).toDouble(),
        heightPx: (m['heightPx'] as num).toDouble(),
        chapterPosition: (m['chapterPosition'] as num).toInt(),
        paragraphIndex: (m['paragraphIndex'] as num).toInt(),
        reviewKey: m['reviewKey'] as String,
        count: (m['count'] as num).toInt(),
        baselineOffsetPx: (m['baselineOffsetPx'] as num).toDouble(),
        compactWidthPx: m['compactWidthPx'] == null
            ? null
            : (m['compactWidthPx'] as num).toDouble(),
        compactHeightPx: m['compactHeightPx'] == null
            ? null
            : (m['compactHeightPx'] as num).toDouble(),
      );
    default:
      throw const FormatException('阅读布局块或行内类型无效');
  }
}
