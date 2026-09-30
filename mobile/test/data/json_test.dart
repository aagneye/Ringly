import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/json.dart';

void main() {
  test('readInt accepts ints, doubles and numeric strings', () {
    expect(readInt({'a': 3}, 'a'), 3);
    expect(readInt({'a': 2.6}, 'a'), 3);
    expect(readInt({'a': '7'}, 'a'), 7);
    expect(readInt({'a': 'x'}, 'a', -1), -1);
    expect(readInt({}, 'a'), 0);
  });

  test('readStringOrNull treats empty and missing as null', () {
    expect(readStringOrNull({'a': ''}, 'a'), isNull);
    expect(readStringOrNull({}, 'a'), isNull);
    expect(readStringOrNull({'a': 'hi'}, 'a'), 'hi');
  });

  test('readDate parses ISO strings and ignores junk', () {
    expect(readDate({'d': '2026-09-30T10:00:00.000Z'}, 'd')?.toUtc().hour, 10);
    expect(readDate({'d': 'not a date'}, 'd'), isNull);
    expect(readDate({'d': 12}, 'd'), isNull);
  });

  test('readList skips entries that are not objects', () {
    final items = readList(
      {'xs': [{'n': 1}, 'bad', null, {'n': 2}]},
      'xs',
      (j) => readInt(j, 'n'),
    );
    expect(items, [1, 2]);
  });
}
