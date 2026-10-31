import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../models/epg_program.dart';

/// Parses an XMLTV guide (optionally gzipped, as many providers serve it).
/// Top-level and free of Flutter types so it can run via `compute`, because
/// a full guide can be tens of megabytes.
List<EpgProgram> parseXmltvBytes(List<int> bytes) {
  final isGzip = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  final text = utf8.decode(isGzip ? gzip.decode(bytes) : bytes, allowMalformed: true);

  final document = XmlDocument.parse(text);
  final programs = <EpgProgram>[];
  for (final node in document.findAllElements('programme')) {
    final channelId = node.getAttribute('channel');
    final startRaw = node.getAttribute('start');
    final title = node.getElement('title')?.innerText;
    if (channelId == null || startRaw == null || title == null) continue;

    final start = _parseXmltvTime(startRaw);
    if (start == null) continue;

    programs.add(EpgProgram(channelId: channelId, title: title, start: start));
  }
  return programs;
}

DateTime? _parseXmltvTime(String raw) {
  final trimmed = raw.trim();
  if (trimmed.length < 14) return null;

  final year = int.tryParse(trimmed.substring(0, 4));
  final month = int.tryParse(trimmed.substring(4, 6));
  final day = int.tryParse(trimmed.substring(6, 8));
  final hour = int.tryParse(trimmed.substring(8, 10));
  final minute = int.tryParse(trimmed.substring(10, 12));
  final second = int.tryParse(trimmed.substring(12, 14));
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }

  var dt = DateTime.utc(year, month, day, hour, minute, second);

  final offsetMatch = RegExp(r'([+-])(\d{2})(\d{2})$').firstMatch(trimmed);
  if (offsetMatch != null) {
    final sign = offsetMatch.group(1) == '-' ? -1 : 1;
    final offsetHours = int.parse(offsetMatch.group(2)!);
    final offsetMinutes = int.parse(offsetMatch.group(3)!);
    dt = dt.subtract(
      Duration(hours: sign * offsetHours, minutes: sign * offsetMinutes),
    );
  }

  return dt;
}
