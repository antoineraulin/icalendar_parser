import 'package:flutter_test/flutter_test.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:icalendar_parser/src/exceptions/icalendar_exception.dart';

main() {
  final _valid =
      'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//hacksw/handcal//NONSGML v1.0//EN\nBEGIN:VEVENT\nUID:uid1@example.com\nDTSTAMP:19970714T170000Z\nORGANIZER;CN=John Doe:MAILTO:john.doe@example.com\nDTSTART:19970714T170000Z\nDTEND:19970715T035959Z\nSUMMARY:Bastille Day Party\nGEO:48.85299;2.36885\nEND:VEVENT\nEND:VCALENDAR';
  final _noCalendarBegin =
      'VERSION:2.0\nPRODID:-//hacksw/handcal//NONSGML v1.0//EN\nBEGIN:VEVENT\nUID:uid1@example.com\nDTSTAMP:19970714T170000Z\nORGANIZER;CN=John Doe:MAILTO:john.doe@example.com\nDTSTART:19970714T170000Z\nDTEND:19970715T035959Z\nSUMMARY:Bastille Day Party\nGEO:48.85299;2.36885\nEND:VEVENT\nEND:VCALENDAR';
  final _noCalendarEnd =
      'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//hacksw/handcal//NONSGML v1.0//EN\nBEGIN:VEVENT\nUID:uid1@example.com\nDTSTAMP:19970714T170000Z\nORGANIZER;CN=John Doe:MAILTO:john.doe@example.com\nDTSTART:19970714T170000Z\nDTEND:19970715T035959Z\nSUMMARY:Bastille Day Party\nGEO:48.85299;2.36885\nEND:VEVENT';

  TestWidgetsFlutterBinding.ensureInitialized();
  test('Missing BEGIN:VCALENDAR', () {
    expect(() => ICalendar.parseFromString(_noCalendarBegin),
        throwsA(isInstanceOf<ICalendarBeginException>()));
  });

  test('Missing END:VCALENDAR', () {
    expect(() => ICalendar.parseFromString(_noCalendarEnd),
        throwsA(isInstanceOf<ICalendarEndException>()));
  });

  test('Valid calendar', () {
    ICalendar.parseFromString(_valid);
  });
}
