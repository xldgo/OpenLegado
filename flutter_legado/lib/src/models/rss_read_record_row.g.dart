// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rss_read_record_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RssReadRecordRow _$RssReadRecordRowFromJson(Map<String, dynamic> json) =>
    _RssReadRecordRow(
      origin: json['origin'] as String? ?? '',
      title: json['title'] as String? ?? '',
      link: json['link'] as String?,
      readTime: (json['read_time'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RssReadRecordRowToJson(_RssReadRecordRow instance) =>
    <String, dynamic>{
      'origin': instance.origin,
      'title': instance.title,
      'link': instance.link,
      'read_time': instance.readTime,
    };
