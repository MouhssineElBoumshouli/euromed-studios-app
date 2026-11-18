/// The app's `Text`: the same as Flutter's, but shown in the app language
/// (see tr.dart). Screens import it instead of Flutter's own `Text`
/// (`import 'package:flutter/material.dart' hide Text;`), so French stays
/// in the code and nothing else changes for them.
library;

import 'package:flutter/widgets.dart' as w;
import 'package:flutter/widgets.dart' hide Text;

import 'tr.dart';

export 'tr.dart' show tr, trExact;

class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  })  : textSpan = null,
        _userText = false;

  /// Text someone typed (a project title, a message, a note): shown as
  /// written. Only an exact known text is translated (the demo's own
  /// content), never a piece of it.
  const Text.user(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  })  : textSpan = null,
        _userText = true;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  })  : data = null,
        _userText = false;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final w.TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  final bool _userText;

  @override
  Widget build(BuildContext context) {
    // Rebuild when the language changes.
    Localizations.maybeLocaleOf(context);
    if (textSpan != null) {
      return w.Text.rich(
        _span(textSpan!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: tr(semanticsLabel),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return w.Text(
      _userText ? trExact(data!) : tr(data!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: tr(semanticsLabel),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  static InlineSpan _span(InlineSpan s) {
    if (s is! TextSpan) return s;
    return TextSpan(
      text: tr(s.text),
      style: s.style,
      recognizer: s.recognizer,
      semanticsLabel: tr(s.semanticsLabel),
      mouseCursor: s.mouseCursor,
      onEnter: s.onEnter,
      onExit: s.onExit,
      locale: s.locale,
      spellOut: s.spellOut,
      children: s.children?.map(_span).toList(),
    );
  }
}
