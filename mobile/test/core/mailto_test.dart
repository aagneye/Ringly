import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/mailto.dart';

void main() {
  group('buildMailto', () {
    test('encodes spaces as %20, never +', () {
      final uri = buildMailto(
        to: 'priya@example.com',
        subject: 'Follow up on the proposal',
        body: 'Hi Priya, thanks for the call',
      );
      final s = uri.toString();
      expect(s, contains('subject=Follow%20up%20on%20the%20proposal'));
      expect(s, contains('body=Hi%20Priya%2C%20thanks%20for%20the%20call'));
      expect(s, isNot(contains('+')));
    });

    test('encodes newlines as %0A', () {
      final uri = buildMailto(
        to: 'a@b.com',
        subject: 'Notes',
        body: 'Line one\nLine two',
      );
      expect(uri.toString(), contains('body=Line%20one%0ALine%20two'));
    });

    test('encodes CRLF newlines', () {
      final uri = buildMailto(to: 'a@b.com', subject: 'S', body: 'one\r\ntwo');
      expect(uri.toString(), contains('body=one%0D%0Atwo'));
    });

    test('encodes reserved characters & ? # in subject and body', () {
      final uri = buildMailto(
        to: 'a@b.com',
        subject: 'Q&A? #1',
        body: 'cost & time? #urgent',
      );
      final s = uri.toString();
      expect(s, contains('subject=Q%26A%3F%20%231'));
      expect(s, contains('body=cost%20%26%20time%3F%20%23urgent'));
    });

    test('encodes unicode', () {
      final uri = buildMailto(to: 'a@b.com', subject: 'Café ☕', body: 'naïve');
      final s = uri.toString();
      // 'é' → %C3%A9, '☕' → %E2%98%95, 'ï' → %C3%AF
      expect(s, contains('subject=Caf%C3%A9%20%E2%98%95'));
      expect(s, contains('body=na%C3%AFve'));
    });

    test('null recipient produces mailto:?subject=...', () {
      final uri = buildMailto(to: null, subject: 'Hello there', body: 'Body');
      final s = uri.toString();
      expect(s, startsWith('mailto:?'));
      expect(s, contains('subject=Hello%20there'));
    });

    test('empty recipient produces mailto:?subject=...', () {
      final uri = buildMailto(to: '', subject: 'Hi', body: 'B');
      expect(uri.toString(), startsWith('mailto:?'));
    });

    test('encodes the recipient address', () {
      final uri = buildMailto(to: 'first last@example.com', subject: 'S', body: 'B');
      expect(uri.toString(), startsWith('mailto:first%20last%40example.com?'));
    });

    test('parses to a mailto scheme', () {
      final uri = buildMailto(to: 'a@b.com', subject: 'S', body: 'B');
      expect(uri.scheme, 'mailto');
    });
  });
}
