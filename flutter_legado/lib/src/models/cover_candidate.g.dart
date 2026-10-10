// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cover_candidate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CoverCandidate _$CoverCandidateFromJson(Map<String, dynamic> json) =>
    _CoverCandidate(
      url: json['url'] as String? ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CoverCandidateToJson(_CoverCandidate instance) =>
    <String, dynamic>{
      'url': instance.url,
      'width': instance.width,
      'height': instance.height,
    };
