import 'package:icalendar_parser/src/exceptions/icalendar_exception.dart';

class ICalendar {
  final String version;
  final String prodid;
  final List<Map<String, dynamic>> data;

  /// Default constructor.
  ICalendar({
    this.version,
    this.prodid,
    this.data,
  });

  /// Parse an [ICalendar] object from a [String]. The line from the parameter
  /// [icsString] must be separated with a `\n`.
  ///
  /// The first line must be `BEGIN:CALENDAR`, and the last line must be
  /// `END:CALENDAR`.
  ///
  /// The body MUST include the "PRODID" and "VERSION" calendar properties.
  factory ICalendar.fromString(String icsString, {bool allowEmptyLine = true}) {
    String prodid;
    String version;

    // Clean end of file to remove empty lines.
    if (allowEmptyLine) {
      while (icsString.endsWith('\n'))
        icsString = icsString.substring(0, icsString.length - 1);
    }

    if (!icsString.startsWith('BEGIN:VCALENDAR'))
      throw ICalendarBeginException('The first line must be BEGIN:VCALENDAR');
    else if (!icsString.endsWith('END:VCALENDAR'))
      throw ICalendarEndException('The last line must be END:VCALENDAR');

    final lines = icsString.split('\n');

    for (String e in lines) {
      final line = e.trim();
      if (line.isEmpty && !allowEmptyLine)
        throw EmptyLineException('Empty line are not allowed');
      if (prodid == null && line.contains('PRODID:') && line.contains(':')) {
        final parsed = line.split(':');
        prodid = parsed.sublist(1).join(':');
      } else if (version == null &&
          line.contains('VERSION:') &&
          line.contains(':')) {
        final parsed = line.split(':');
        version = parsed.sublist(1).join(':');
      }
    }

    if (version == null)
      throw ICalendarNoVersionException(
          'The body is missing the property VERSION');
    if (prodid == null)
      throw ICalendarNoProdidException(
          'The body is missing the property PRODID');

    return ICalendar(
      version: version,
      prodid: prodid,
      data: fromStringToJson(icsString),
    );
  }

  static Function(String, Map<String, String>, List, Map<String, dynamic>)
      _generateDateFunction(String name) {
    return (String value, Map<String, String> params, List events,
        Map<String, dynamic> lastEvent) {
      final matches =
          RegExp(r'/^(\d{4})(\d{2})(\d{2})$/').allMatches(value).toList();
      if (matches != null && matches.isNotEmpty) {
        lastEvent[name] = DateTime(int.parse(matches[1].input),
            int.parse(matches[2].input) - 1, int.parse(matches[3].input));
        return lastEvent;
      }

      if (RegExp(r'/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})/')
          .hasMatch(value)) {
        lastEvent[name] = DateTime.parse(value.substring(0, 4) +
            '-' +
            value.substring(4, 6) +
            '-' +
            value.substring(6, 11) +
            ':' +
            value.substring(11, 13) +
            ':' +
            value.substring(13));
      }
      return lastEvent;
    };
  }

  static Function(String, Map<String, String>, List, Map<String, dynamic>)
      _generateSimpleParamFunction(String name) {
    return (String value, Map<String, String> params, List events,
        Map<String, dynamic> lastEvent) {
      lastEvent[name] = value.replaceAll(RegExp(r'/\\n/g'), "\n");
      return lastEvent;
    };
  }

  static Map<String, Function> _objects = {
    'BEGIN': (String value, Map<String, String> params, List events,
        Map<String, dynamic> lastEvent) {
      if (value == "VCALENDAR") return null;

      lastEvent = {'type': value};
      events.add(lastEvent);

      return lastEvent;
    },
    'END': (String value, Map<String, String> params, List events,
        Map<String, dynamic> lastEvent, List<Map<String, dynamic>> data) {
      if (value == "VCALENDAR") return lastEvent;

      data.add(lastEvent);

      int index = events.indexOf(lastEvent);
      if (index != null) events.removeAt(index);

      if (events.isEmpty)
        lastEvent = null;
      else
        lastEvent = events.last;

      return lastEvent;
    },
    'DTSTART': _generateDateFunction('startDate'),
    'DTEND': _generateDateFunction('endDate'),
    'DTSTAMP': _generateDateFunction('end'),
    'COMPLETED': _generateDateFunction('completed'),
    'DUE': _generateDateFunction('due'),
    'UID': _generateSimpleParamFunction('uid'),
    'SUMMARY': _generateSimpleParamFunction('name'),
    'DESCRIPTION': _generateSimpleParamFunction('description'),
    'LOCATION': _generateSimpleParamFunction('location'),
    'URL': _generateSimpleParamFunction('url'),
    'ORGANIZER': (String value, Map<String, String> params, List events,
        Map<String, dynamic> lastEvent) {
      final mail = value.replaceAll('MAILTO:', '').trim();

      if (params.containsKey('CN')) {
        lastEvent['organizer'] = {
          'name': params['CN'],
          'mail': mail,
        };
      } else
        lastEvent['organizer'] = {'mail': mail};

      return lastEvent;
    },
    'GEO': (String value, Map<String, String> params, List events,
        Map<String, dynamic> lastEvent) {
      final pos = value.split(';');
      if (pos.length != 2) return lastEvent;

      lastEvent['geo'] = {};
      lastEvent['geo']['latitude'] = num.parse(pos[0]);
      lastEvent['geo']['longitude'] = num.parse(pos[1]);
      return lastEvent;
    },
    'CATEGORIES': (String value, Map<String, String> params, List events,
        Map<String, dynamic> lastEvent) {
      lastEvent['categories'] = value.split(RegExp(r'/\s*,\s*/g'));
      return lastEvent;
    },
    'ATTENDEE': (String value, Map<String, String> params, List events,
        Map<String, dynamic> lastEvent) {
      lastEvent['attendee'] ??= [];

      final mail = value.replaceAll('MAILTO:', '').trim();

      if (params.containsKey('CN')) {
        (lastEvent['attendee'] as List).add({
          'name': params['CN'],
          'mail': mail,
        });
      } else
        (lastEvent['attendee'] as List).add({'mail': mail});
      return lastEvent;
    }
  };

  /// Parse a [List] of icalendar object from a [String]. The line from the
  /// parameter [icsString] must be separated with a `\n`.
  static List<Map<String, dynamic>> fromStringToJson(String icsString,
      {bool allowEmptyLine = true}) {
    List<Map<String, dynamic>> data = [];
    List events = [];
    Map<String, dynamic> lastEvent = {};

    List<String> lines = icsString.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      final exp = RegExp(r'/^ /');
      while (i + 1 < lines.length && exp.hasMatch(lines[i + 1])) {
        i += 1;
        line = lines[i].trim();
      }

      List<String> dataLine = line.split(':');
      if (dataLine.length < 2) {
        continue;
      }

      List<String> dataName = dataLine[0].split(';');

      final name = dataName[0];
      dataName.removeRange(0, 1);

      Map<String, String> params = {};
      dataName.forEach((e) {
        List<String> param = e.split('=');
        if (param.length == 2) params[param[0]] = param[1];
      });

      dataLine.removeRange(0, 1);
      String value = dataLine.join(':').replaceAll(RegExp(r'\\,'), ',');
      if (_objects.containsKey(name)) {
        if (name == 'END')
          lastEvent = _objects[name](value, params, events, lastEvent, data);
        else
          lastEvent = _objects[name](value, params, events, lastEvent);
      }
    }
    return data;
  }

  /// Convert [ICalendar] object to a [Map] containing all its data.
  ///
  /// ```
  /// {
  ///   "version": ICalendar.version,
  ///   "prodid": ICalendar.prodid,
  ///   "data": ICalendar.data
  /// }
  /// ```
  Map<String, dynamic> toJson() => {
        "version": version,
        "prodid": prodid,
        "data": data,
      };

  @override
  String toString() =>
      'iCalendar - VERSION: $version - PRODID: $prodid - DATA: $data';
}
