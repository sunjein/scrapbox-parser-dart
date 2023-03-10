import 'dart:io';

enum LineTypes {
  Plain,
  Quote,
  Code, // 多分非対応
}

// enum Types {
//   Internal,
//   External,
//   Icon,
// }

enum Style {
  Bold,
  Big,
  Italic,
  Underline,
  Delete,
}

class Parser {
  // 全体のプロセス
  List parse(List<String> content) {
    final List parsed = [];
    LineTypes currentLineType = LineTypes.Plain;
    for (String line in content) {
      final Map<String, dynamic> linetypedata =
          getLineType(line, currentLineType);
      line = linetypedata["line"];
      final lineParsed = lineProcess(line);
      lineParsed["lineType"] = linetypedata["LineType"];
      parsed.add(lineParsed);
    }
    return parsed;
  }

  Map<String, dynamic> getLineType(String line, LineTypes currentLineType) {
    RegExp quote_exp = RegExp(r'^(\s*)>(.*)');
    if (quote_exp.hasMatch(line)) {
      final Match? match = quote_exp.firstMatch(line);
      // >を除いた形のline
      final content = match!.group(1)! + match.group(2)!;
      return {"LineType": LineTypes.Quote, "line": content};
    }
    return {"LineType": LineTypes.Plain, "line": line};
  }

  // 行のプロセス
  Map<String, dynamic> lineProcess(String line) {
    // インデント関連
    final Map<String, dynamic> indentData = countIndent(line);
    final int depth = indentData["depth"];
    String content = indentData["content"];

    // ブラケットの処理
    RegExp codeExp = RegExp(r'`.+`');
    final List temp_result = parseCode(content);
    List result = [];
    temp_result.forEach((element) {
      if (element.isNotEmpty) {
        if (codeExp.hasMatch(element)) {
          result.add(element);
        } else {
          final bracketParsed = parseBrackets(element);
          result += bracketParsed;
        }
      }
    });

    // 結果データを返却
    Map<String, dynamic> lineParsed = {
      "indentDepth": depth,
      "content": result,
    };
    return lineParsed;
  }

  // インデントのカウント
  Map<String, dynamic> countIndent(String line) {
    RegExp exp = RegExp(r'^(\s*)(.*)');
    RegExpMatch? match = exp.firstMatch(line);
    if (match == null) return {"depth": 0, "content": line};
    return {"depth": match[1]!.length, "content": match[2]!};
  }

  List parseCode(String input) {
    // `print("hello, world!")` などで囲まれている部分のパース
    StringBuffer outCodeBuffer = StringBuffer();
    StringBuffer inCodeBuffer = StringBuffer();
    List result = [];
    bool inCode = false;
    for (int i = 0; i < input.length; i++) {
      var c = input[i];
      if (c == '`') {
        inCode = !inCode;
        inCodeBuffer.write(c);
        if (inCode == false) {
          // codeから脱した→正式に分割する
          if (inCodeBuffer.toString().isNotEmpty)
            result.add(outCodeBuffer.toString());
          result.add(inCodeBuffer.toString());
          outCodeBuffer.clear();
          inCodeBuffer.clear();
        }
      } else {
        if (inCode) {
          inCodeBuffer.write(c);
        } else {
          outCodeBuffer.write(c);
        }
      }
    }
    if (outCodeBuffer.toString().isNotEmpty)
      result.add(outCodeBuffer.toString() + inCodeBuffer.toString());
    return result;
  }

  List parseBrackets(String input) {
    StringBuffer buffer = StringBuffer();
    List result = [];
    int nest = 0;
    bool finalNested = false;
    for (int i = 0; i < input.length; i++) {
      finalNested = false;
      String c = input[i];
      if (c == '[') {
        if (nest == 0) {
          finalNested = true;
          if (buffer.toString().isNotEmpty) result.add(buffer.toString());
          buffer.clear();
        }
        nest++;
      } else if (c == ']') {
        nest--;
        if (nest == 0) {
          finalNested = true;
          final child = parseBrackets(buffer.toString());
          if (buffer.toString().isNotEmpty) result.add(child);
          buffer.clear();
        }
      }
      if (finalNested == false) {
        // 最後の括弧を入れるかを判断している
        buffer.write(c);
      }
    }
    if (buffer.toString().isNotEmpty) result.add(buffer.toString());
    return result;
  }

  void bracketInsideProcess(String insideContent) {
    print(insideContent);
  }
}

class Converter {
  // 全体のプロセス
  convert(List parsedLines) {
    final List allLineWidgets = [];
    for (Map parsedLine in parsedLines) {
      final lineWidgets = lineProcess(parsedLine["content"]);
      allLineWidgets.add(lineWidgets);
    }
  }

  lineProcess(List content) {
    List all = [];
    content.forEach(
      (element) {
        final List<Map<String, dynamic>> returnedElements =
            partProcess(element, {});
        all += returnedElements;
      },
    );
    print(all);
    // return RichText(
    //   text: TextSpan(children: singleLineWidgets),
    // );
  }

  List<Map<String, dynamic>> partProcess(part, parent) {
    Map<String, dynamic> thisObj = {
      "type": parent["type"] ?? "Plain",
      "content": "",
      "style": parent["style"] ?? Set(),
    };
    // List, Stringどちらもくる
    if (part is List) {
      if (part.length == 1) {
        thisObj["type"] = "Link";
      }
      if (part[0] is String) thisObj["content"] = part[0];
      thisObj = parsePartContent(thisObj);
      List<Map<String, dynamic>> children = [];
      part.forEach((element) {
        List<Map<String, dynamic>> r = partProcess(element, thisObj);
        if (part.length == 1 && element is List) {
          r[0]["style"] = Style.Bold;
        }
        children += r;
      });
      return children;
    }
    if (part is String) {
      thisObj["content"] = part;
      thisObj = parsePartContent(thisObj);
    }
    return [thisObj];
  }

  Map<String, dynamic> parsePartContent(Map<String, dynamic> obj) {
    // 最初の方の解析しかできません。後方に追加する形のブラケット記法があったらリスト全体を渡して処理して返却する処理が必要
    // [* hello [world] aaa]はOK, [hello [world] aaa!]はだめ
    // そのため、bold記法ではテキスト部分が何もなくても(.*で0以上の一致)判定するようにしています。
    final Map<String, dynamic> thisObj = {
      "type": obj["type"] ?? "Plain",
      "content": obj["content"] ?? "",
      "style": obj["style"] ?? Set(),
    };

    // 太字、大きい字、斜体、打ち消し
    Match? styleRegexMatch =
        RegExp(r'([\-\*\/_]+)\s+(.*)').firstMatch(thisObj["content"]);
    if (styleRegexMatch != null) {
      final Set<Style> styles = {};
      final String styleCharacters = styleRegexMatch.group(1)!;
      int bold = 0;
      for (String char in styleCharacters.split("")) {
        if (char == "*") bold++;
        if (char == "_") styles.add(Style.Underline);
        if (char == "/") styles.add(Style.Italic);
        if (char == "-") styles.add(Style.Delete);
      }
      if (bold > 1) {
        styles.add(Style.Big);
      } else if (bold == 1) {
        styles.add(Style.Bold);
      }
      thisObj["content"] = styleRegexMatch.group(2)!;
      thisObj["style"] = styles;
      return thisObj;
    }

    // アイコン記法
    Match? iconRegexMatch =
        RegExp(r'(.+)\.icon').firstMatch(thisObj["content"]);
    if (iconRegexMatch != null) {
      final String username = iconRegexMatch.group(1)!;
      thisObj["content"] = username;
      thisObj["type"] = "Icon";
      return thisObj;
    }
    return thisObj;
  }
}

void main() {
  File file = File("page.sb");
  String fileContent = file.readAsStringSync();
  final parser = Parser();
  final parsed = parser.parse(fileContent.split("\n"));
  final converter = Converter();
  converter.convert([parsed[0]]); // コンテンツが長いので意図的にparsed[0]を設定
}
