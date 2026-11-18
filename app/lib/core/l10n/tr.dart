/// App language (decision 0008).
///
/// French is written directly in the code, as before. For English, every
/// text is looked up in `en_catalog.dart` when it is shown on screen:
/// - exact texts ("Annuler" → "Cancel");
/// - texts with values in them ("Bonjour {0}," → "Hello {0},"), where each
///   value is translated too when it is a known text ("{1:s}" adds an
///   English plural "s" where the French value was a plural ending);
/// - texts glued together with " · " or line breaks, translated piece by
///   piece.
/// Anything unknown (names, studio names, data typed by people) is shown
/// as it is.
library;

import 'en_catalog.dart';

abstract final class L {
  static String _code = 'fr';

  static String get code => _code;
  static bool get en => _code == 'en';

  static void setLanguage(String code) {
    if (code == _code) return;
    _code = code;
    _cache.clear();
  }
}

final _cache = <String, String>{};

/// [s] in the app language. Works on null too (returns null).
T tr<T extends String?>(T s) {
  if (s == null || !L.en || s.isEmpty) return s;
  // Countdowns change every minute: keep the cache small.
  if (_cache.length > 2000) _cache.clear();
  return (_cache[s] ??= _translate(s, 0)) as T;
}

/// For text people typed (titles, messages, notes): only an exact known
/// text is translated (the demo's own content), never a piece of it.
String trExact(String s) => L.en ? (enExact[s] ?? s) : s;

final _placeholder = RegExp(r'\{(\d)(?::([npr]))?\}');

class _Pattern {
  _Pattern(String fr, this.en)
      : re = RegExp(_regex(fr), dotAll: true),
        order = [
          for (final m in _placeholder.allMatches(fr)) int.parse(m.group(1)!),
        ],
        quoted = {
          for (final m in RegExp(r'[«"]\s?\{(\d)\}\s?[»"]').allMatches(fr))
            int.parse(m.group(1)!),
        };
  final RegExp re;
  final String en;

  /// Which placeholder each regex group is ({1} may come before {0}).
  final List<int> order;

  /// Values in quotes are names people typed: never translated.
  final Set<int> quoted;

  /// {0:n} a number, {1:p} a French plural ending, {0:r} a booking
  /// reference, {0} anything.
  static String _regex(String fr) {
    final b = StringBuffer('^');
    var i = 0;
    for (final m in _placeholder.allMatches(fr)) {
      b.write(RegExp.escape(fr.substring(i, m.start)));
      b.write(switch (m.group(2)) {
        'n' => r'(\d+(?:[.,]\d+)?)',
        'p' => '([sx]?)',
        'r' => r'(ES-[\w-]+)',
        _ => '(.*?)',
      });
      i = m.end;
    }
    b
      ..write(RegExp.escape(fr.substring(i)))
      ..write(r'$');
    return b.toString();
  }
}

/// Most specific first: the longer the fixed text, the earlier it is tried.
final List<_Pattern> _patterns = () {
  final keys = enPatterns.keys.toList()
    ..sort((a, b) => b
        .replaceAll(RegExp(r'\{\d\}'), '')
        .length
        .compareTo(a.replaceAll(RegExp(r'\{\d\}'), '').length));
  return [for (final k in keys) _Pattern(k, enPatterns[k]!)];
}();

const _separators = ['\n', ' · ', ' / ', ' × ', ' — ', ' – ', ' : ', '. '];

String _translate(String s, int depth) {
  final exact = enExact[s];
  if (exact != null) return exact;

  for (final p in _patterns) {
    final m = p.re.firstMatch(s);
    if (m == null) continue;
    var out = p.en;
    for (var g = 0; g < p.order.length; g++) {
      var value = m.group(g + 1)!;
      final n = p.order[g];
      // "2,5" → "2.5" in English.
      if (RegExp(r'^\d+,\d+$').hasMatch(value)) value = value.replaceAll(',', '.');
      // "{1:s}": English plural "s" when the French had a plural ending.
      out = out.replaceAll('{$n:s}', value.isEmpty ? '' : 's').replaceAll(
            '{$n}',
            depth < 4 && !p.quoted.contains(n)
                ? _translate(value, depth + 1)
                : value,
          );
    }
    return out;
  }

  // Keep outer spaces: " Raison" → " Reason".
  final trimmed = s.trim();
  if (trimmed.length != s.length && trimmed.isNotEmpty) {
    final start = s.indexOf(trimmed);
    return s.substring(0, start) +
        _translate(trimmed, depth) +
        s.substring(start + trimmed.length);
  }

  if (depth < 4) {
    for (final sep in _separators) {
      if (!s.contains(sep)) continue;
      final parts = s.split(sep);
      final glue = sep == ' : ' ? ': ' : sep;
      final done = [for (final x in parts) _translate(x, depth + 1)];
      // Only use the split if it actually translated something.
      if (done.join(sep) != parts.join(sep)) return done.join(glue);
    }
    // "Raison :" with French spacing before the colon.
    for (final end in [' :', ' ?', ' !']) {
      if (s.endsWith(end) && s.length > end.length) {
        final head = s.substring(0, s.length - end.length);
        final t = _translate(head, depth + 1);
        if (t != head) return '$t${end.trim()}';
      }
    }
  }
  return s;
}
