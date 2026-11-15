import 'package:flutter/services.dart';

enum TextTool {
  nfc, withoutMarks, uppercase, lowercase,
  titleCase, sentenceCase, cleanSpaces, markdown,
}

// Offline, explicit text editing: no monitoring and no network.
class TextToolbox {
  static const _native = MethodChannel('com.telexmini/control');

  static Future<String> apply(String source, TextTool operation) async {
    if (operation == TextTool.nfc) {
      try {
        return await _native.invokeMethod<String>('normalizeNfc', {
          'text': source,
        }) ?? source;
      } on MissingPluginException {
        return source;
      } on PlatformException {
        return source;
      }
    }
    return applyPure(source, operation);
  }

  static String applyPure(String value, TextTool operation) {
    switch (operation) {
      case TextTool.nfc:
        return value; // Windows native bridge handles canonical composition.
      case TextTool.withoutMarks:
        return stripVietnamese(value);
      case TextTool.uppercase:
        return value.toUpperCase();
      case TextTool.lowercase:
        return value.toLowerCase();
      case TextTool.titleCase:
        return value.replaceAllMapped(
          RegExp(r'(^|\s)(\S+)', multiLine: true),
          (match) {
            final word = match.group(2)!;
            return (match.group(1) ?? '') +
                word[0].toUpperCase() + word.substring(1).toLowerCase();
          },
        );
      case TextTool.sentenceCase:
        var capitalize = true;
        final result = StringBuffer();
        for (final rune in value.runes) {
          final ch = String.fromCharCode(rune);
          final isLetter = RegExp(r'[A-Za-zÀ-ỹĐđ]').hasMatch(ch);
          result.write(isLetter && capitalize ? ch.toUpperCase() : ch);
          if (isLetter) capitalize = false;
          if ('.!?\n'.contains(ch)) capitalize = true;
        }
        return result.toString();
      case TextTool.cleanSpaces:
        return value.replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split('\n')
            .map((line) => line.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
            .join('\n');
      case TextTool.markdown:
        return applyPure(value, TextTool.cleanSpaces)
            .split('\n')
            .map((line) => line.startsWith('• ') || line.startsWith('· ')
                ? '- ${line.substring(2)}' : line)
            .join('\n');
    }
  }

  static String stripVietnamese(String source) {
    const groups = <String, String>{
      'a': 'áàảãạăắằẳẵặâấầẩẫậ',
      'e': 'éèẻẽẹêếềểễệ',
      'i': 'íìỉĩị',
      'o': 'óòỏõọôốồổỗộơớờởỡợ',
      'u': 'úùủũụưứừửữự',
      'y': 'ýỳỷỹỵ',
      'd': 'đ',
    };
    final map = <String, String>{};
    for (final entry in groups.entries) {
      for (final rune in entry.value.runes) {
        final ch = String.fromCharCode(rune);
        map[ch] = entry.key;
        map[ch.toUpperCase()] = entry.key.toUpperCase();
      }
    }
    final result = StringBuffer();
    for (final rune in source.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'[\u0300-\u036F]').hasMatch(ch)) continue;
      result.write(map[ch] ?? ch);
    }
    return result.toString();
  }
}
