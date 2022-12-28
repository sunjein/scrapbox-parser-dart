
# Scrapbox Parser Dart

[Dart](https://dart.dev/)で制作しているScrapboxのパーサーです。

今後Flutterで使用できるようにする予定です。

## 実装についての今後

### 大まかな流れ

1. Quote, CodeBlock, Table(?)などの全体に渡るものを解析 (blockプロセス)
2. Linkの囲みを解析(not正規表現) (lineプロセス)
3. Linkの内部を解析(正規表現)


### パーサーの流れ

#### 1. オリジナルのデータ

```text
>文章があり、[* その中に強調があり、[リンク]が強調されている。]
```

#### 2. 分割された生の階層構造のリストデータ

```dart
["文章があり、", ["* その中に強調があり、", ["リンク"], "が強調されている。"]]
```

#### 3. ひとつひとつブラケットを再帰関数で処理
- 親のスタイルを継承していく
- 基本的にウィジェットで表示する形にするようにしたいから、フラットなリストとして作りたい

```dart
// これ全体で1行分とする
{
    "wholeLineYype": "Quote",
    "indentDepth": 0,
    "content": [
        {
            "type": "Plain",
            "content": "文章があり",
            "style": null,
        },
        {
            "type": "Plain",
            "content": "その中に強調があり",
            "style": "Bold", // TextStyle or Enum
        },
        {
            "type": "Link",
            "content": "リンク",
            "style": "Bold",
        },
        {
            "type": "Plain",
            "content": "が強調されている。",
            "style": "Bold",
        },
    ]
}
```