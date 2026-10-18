import 'package:aeroflow/models/models.dart';
import 'package:aeroflow/utils/web_export.dart';
import 'package:flutter_test/flutter_test.dart';

Seat seat(String number, [TravelClass c = TravelClass.economy]) => Seat(number: number, travelClass: c, price: 1);

void main() {
  test('economy 3-3: A/F window, B/E middle, C/D aisle', () {
    expect(['12A', '12B', '12C', '12D', '12E', '12F'].map((n) => seat(n).position), [SeatPosition.window, SeatPosition.middle, SeatPosition.aisle, SeatPosition.aisle, SeatPosition.middle, SeatPosition.window]);
  });
  test('business 2-2: A/F window, C/D aisle', () {
    expect(['2A', '2C', '2D', '2F'].map((n) => seat(n, TravelClass.business).position), [SeatPosition.window, SeatPosition.aisle, SeatPosition.aisle, SeatPosition.window]);
  });
  test('parses row and letter, including old-format seats', () {
    final s = seat('14B', TravelClass.first);
    expect((s.row, s.letter, s.position), (14, 'B', SeatPosition.middle));
  });
  test('initials use first two names', () {
    expect(const AppUser(id: '1', fullName: 'asha  rao kumar', email: 'a@b.c', phone: '123456').initials, 'AR');
  });
  test('CSV quotes commas, quotes and line breaks', () {
    expect(toCsv([['a', 1, null], ['x,y', 'say "hi"', 'two\nlines']]), 'a,1,\r\n"x,y","say ""hi""","two\nlines"');
  });
}
