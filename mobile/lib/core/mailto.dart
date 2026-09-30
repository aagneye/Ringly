/// Building a `mailto:` link that survives being handed to a real mail client.
///
/// The subtlety: [Uri(queryParameters: ...)] encodes a space as `+`, which is
/// correct for `application/x-www-form-urlencoded` but wrong inside a
/// `mailto:` URI — RFC 6068 wants `%20`. A subject like "Follow up" would
/// arrive as "Follow+up" in the user's compose window. So we build the query
/// string by hand with [Uri.encodeComponent], which percent-encodes spaces as
/// `%20`, newlines as `%0A`, and the reserved characters `&`, `?`, `#`.
library;

/// Build a `mailto:` URI for [to] with the given [subject] and [body].
///
/// [to] may be null or empty, in which case the link opens a blank-recipient
/// compose window (`mailto:?subject=...`) and the user fills in the address in
/// their mail app. Per RFC 6068 all three parts are percent-encoded so the
/// subject and body reach the mail client exactly as written.
Uri buildMailto({String? to, required String subject, required String body}) {
  final query = 'subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}';
  final recipient = (to == null || to.isEmpty) ? '' : Uri.encodeComponent(to);
  return Uri.parse('mailto:$recipient?$query');
}
