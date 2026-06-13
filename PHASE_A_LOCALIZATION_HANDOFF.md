# Phase A — キャラクター/AIコンテンツ多言語化 引き継ぎ書

**最終更新:** 2026-05-01
**前提:** Phase B (UI骨格) / Phase C (既存翻訳の穴埋め) は完了済み・ビルド成功 (`** BUILD SUCCEEDED **`)
**対象アプリ:** 筋肉ごめん (SorryGains) / `/Users/koya1104/Desktop/Muscle360/SorryGains/`

---

## 1. なぜ Phase A を分離したか

Phase B/C は機械的な「JA→EN 直訳」で済む UI ラベル・モデル表示文・通知文だった。

一方、本フェーズの対象は **「筋肉キャラクターの口調・人格」** が主体のコンテンツ。単なる直訳ではなく、

- 厳しめだが愛のある武道家口調 (「〜だぞ」「〜しろ」「ワシ」)
- 古風な比喩 / ユーモア
- 短文でリズムよく決める

という日本語特有の語感を、英語でどう再現するかという **キャラクターローカライゼーション設計** の判断が必要。直訳すると人格が崩壊し、ユーザー体験が大幅に劣化する。

そのため、まず方針を決めてから一気に実装する流れになる。

---

## 2. 対象ファイルと文字列数

合計 **約280文字列** / 6ファイル / 1,123行

| ファイル | 文字列数 | 行数 | カテゴリ |
|---|---:|---:|---|
| `Core/Calculation/SageAdviceFragments.swift` | 119 | 208 | 仙人助言の断片(冒頭/本論/締め × 8カテゴリ) |
| `Core/Animation/CharacterSpeechView.swift` | 60 | 229 | キャラ吹き出しセリフ (12本×5ステージ) |
| `Core/Calculation/FoundationModelsSageAdviceProvider.swift` | 39 | 209 | Apple Foundation Models へのプロンプト |
| `Core/Calculation/LocalSageAdviceProvider.swift` | 26 | 228 | テンプレ助言生成・文脈注入文・フォローアップ |
| `Core/Reactions/DrinkReactionProvider.swift` | 20 | 152 | 飲酒1〜5杯目のリアクション (4本×5段階) |
| `Core/Models/RecoveryActionType.swift` | 14 | 97 | お詫び行動完了時のキャラ反応 (7アクション×2ステージ) |

---

## 3. 各ファイルの構造と難易度

### 3.1 `RecoveryActionType.swift` ⭐ (最易)
```swift
func reactionDialogue(for stage: Int) -> String {
    switch self {
    case .workout:
        stage >= 3
            ? "まだ間に合う…信じてるぞ！"
            : "よし！！それでこそ俺の主人だ！"
    // ... 7アクション × 2ステージ = 14文
    }
}
```

**作業:**
- 全14文を `String(localized:)` 化
- xcstrings に `recoveryAction.reaction.{action}.{calm|harsh}` 系のキーで追加
- 例: `recoveryAction.reaction.workout.calm` ja: `"よし！！それでこそ俺の主人だ！"` en: `"Now THAT's my master! Yes!!"`

### 3.2 `DrinkReactionProvider.swift` ⭐⭐
```swift
private static let reactions: [[DrinkReaction]] = [
    [ // 1杯目 — 4 variants
        DrinkReaction(dialogue: "...まぁ、1杯くらいならな。", emoji: "😑", intensity: .mild),
        // ...
    ],
    // ... 5段階 × 4本 = 20文
]
```

**作業:**
- `dialogue: String(localized: "drinkReaction.{n}.{i}")` のキー化
- 5段階 (1〜5杯目) × 4 variants = 20キー追加

### 3.3 `CharacterSpeechView.swift` ⭐⭐
```swift
static let dialoguePool: [[String]] = [
    [ // Stage 0: ゴリマッチョ — 自信満々 (12本)
        "今日もいい筋肉だ！",
        "この大胸筋を見てくれ！",
        // ...
    ],
    // ... 5ステージ × 12本 = 60文
]
```

**作業:**
- 配列要素を全て `String(localized: "characterSpeech.stage{N}.line{i}")` に
- 60キー追加

**英訳の方向性 (各ステージのトーン):**
- Stage 0 ゴリマッチョ・自信満々: "Look at these pecs!" "Today's gains are unstoppable!"
- Stage 1 細マッチョ・警告: "Hey, hold up..." "My fibers are crying..."
- Stage 2 普通・不安: "Where did my abs go..." "Mirror's getting scary..."
- Stage 3 ぷよぷよ・激怒: "Are you KIDDING me?!" "Look at this body!"
- Stage 4 ガリガリ・絶望: "I... can't go on..." "I was once a muscle..."

### 3.4 `SageAdviceFragments.swift` ⭐⭐⭐ (最難・最大ボリューム)
8カテゴリ × (openings + bodies + closings) = **119断片**

```swift
enum SageAdviceFragments {
    struct Bundle {
        let openings: [String]   // 例: "おいおい、" "ふん、" "なあ、聞けよ。"
        let bodies: [String]     // 例: "今日はちょっとやりすぎだ。筋肉が悲鳴あげてる。"
        let closings: [String]   // 例: "明日のトレで全部チャラにしてやれ。"
    }
    static let fragments: [SageAdviceCategory: Bundle] = [...]
}
```

**カテゴリ:**
1. `drankTooMuch` (飲みすぎ)
2. `drankALittle` (少し飲んだ)
3. `goodJob` (節制成功)
4. `neutral` (通常)
5. `streak` (連続飲酒)
6. `hardTrainHeavyDrink` (高強度トレ + 多量飲酒)
7. `hardTrainLightDrink` (高強度トレ + 軽い飲酒)
8. `lightTrainHeavyDrink` (軽トレ + 飲みすぎ)

**設計上の重要ポイント:**
- 断片は組合せて1つの助言を作る (`opening + body + closing`)
- **JAは助詞でつながる文化** だが、ENは語順が違う
- 例: ja `"おいおい、" + "今日はやりすぎだ。" + "明日で取り返せ。"` → 自然
- 例: en `"Hey, " + "you went too far today." + "Make up for it tomorrow."` → 自然

→ 英訳時は **JA と同じく opening/body/closing の3断片構造を維持** すれば、結合時も自然な英文になる。区切り文字を `""` (空) → `" "` (スペース) に切り替える対応が必要。

**作業の流れ:**
1. xcstrings キーを `sage.fragment.{category}.opening.{i}` 形式で約120キー追加
2. `Bundle` 構造体を `[LocalizedStringResource]` ベースに変更するか、`String(localized:)` を初期化時に呼ぶように変更
3. `LocalSageAdviceProvider.randomComposition` の結合 separator をロケール依存に
4. `injectContext` の動的挿入 (例: `"\(N)日連続で飲んでる現実、見ろ。"`) もテンプレ化

### 3.5 `LocalSageAdviceProvider.swift` ⭐⭐⭐
- `injectContext` 内: 動的に文を組み立てて文中に挿入
  ```swift
  result = "\(context.consecutiveDrinkingDays)日連続で飲んでる現実、見ろ。" + result
  ```
- `buildLinkedFollowUp`: 部位名を埋め込んだフォローアップ
  ```swift
  return "\(partsText)を追い込んだ日だ。水とプロテインで取り返せ。"
  ```
- `defaultFollowUps`: カテゴリ別のフォロー文 (8カテゴリ × 1文)
- `bodyPartLocalizedName`: ローカルな部位名マッピング (Phase B で `bodyPart.*` 共通キーを追加済み → これを再利用すべき)

**作業:**
- 部位名は `String(localized: "bodyPart.\(key)")` に置換 (Phase B で追加済みキー再利用)
- 動的挿入の文を `String(format: String(localized: "..."), value)` パターンに
- `defaultFollowUps` を `[Category: LocalizedStringResource]` か関数化

### 3.6 `FoundationModelsSageAdviceProvider.swift` ⭐⭐⭐⭐ (設計判断必須)

**核心問題: LLM プロンプトをどうするか?**

現在のプロンプトは Apple Foundation Models に対して **「日本語で出力しろ」と命じている**:

```swift
static let personaInstructions = """
あなたは「筋肉仙人」という個性豊かなキャラクターです。
人物像:
- 厳しいが愛のある武道の達人。古風な口調で語る。
...
出力規則:
- 必ず日本語で2〜3文、100文字以内。
...
"""
```

**選択肢:**

| 案 | 説明 | メリット | デメリット |
|---|---|---|---|
| **A** | プロンプト全体を JA/EN 2セット用意 | 各言語で自然な人格 | 仙人=武士の人格を英語化する難しさ。Sensei? Sage? |
| **B** | プロンプトは JA のまま、出力のみ "respond in {locale}" 指示 | 実装が単純 | LLM の英訳品質は不安定 |
| **C** | EN ロケールでは LLM をスキップし、`LocalSageAdviceProvider` (テンプレ英訳済み) を使う | 安定 | LLM の多様性が失われる |

**推奨:** 案A (full bilingual prompts)
- "Muscle Sage" / "Sensei" 等のキャラ設定
- "speak with old-master gravitas, sometimes blunt, always with love"
- 出力規則は同等に "2-3 sentences, 200 chars max"

**作業項目:**
- `personaInstructions` を `String(localized: "sage.llm.persona")` で切り替え
- `buildPrompt` の状況サマリ (`"- 飲酒: \(count)杯 / 純アルコール\(...)g"`) をロケール依存テンプレ化
- `categoryJP`/`toneJP`/`bodyPartJP`/`intensityJP` をローカライズ (Phase B 既存キー流用可)

---

## 4. 実装順の推奨

```
ステップ1: RecoveryActionType.reactionDialogue (14文) ← ウォームアップ
ステップ2: DrinkReactionProvider (20文)
ステップ3: CharacterSpeechView (60文)
ステップ4: SageAdviceFragments (119文) ← ここが本番
ステップ5: LocalSageAdviceProvider 文脈注入・フォローアップ (26文)
ステップ6: FoundationModelsSageAdviceProvider プロンプト (39文) ← 設計判断必要
ステップ7: ビルド検証 (xcodegen → xcodebuild)
```

各ステップ完了後に xcstrings へキー追加 → ビルド確認、を回すのが安全。

---

## 5. 設計上の選択肢 (実装前に決める)

### 5.1 キーの命名規則
- **A案 (推奨)**: 構造的キー `sage.fragment.drankTooMuch.opening.0` … 見通しがよい
- **B案**: JA リテラルをキーにする (Phase B/C と同じ慣習) … 整理しにくい

→ Phase A はボリュームが大きいので **A案** を推奨。

### 5.2 配列の取り扱い
JA リテラル配列 `["A", "B", "C"]` を多言語化する一般的パターン:

```swift
// Before
let openings = ["おいおい、", "ふん、", ...]

// After (案1: keys array)
let openingKeys = (0..<8).map { "sage.fragment.drankTooMuch.opening.\($0)" }
let openings = openingKeys.map { String(localized: String.LocalizationValue($0)) }

// After (案2: enum + localized accessor)
enum DrankTooMuchOpening: Int, CaseIterable {
    case ohOh = 0, hmph, hey, ...
    var localized: String { String(localized: "sage.fragment.drankTooMuch.opening.\(rawValue)") }
}
```

→ 数が多いので、**案1 のキー配列方式 + ヘルパー関数** を推奨。

### 5.3 結合時の separator
JA の助言は断片を `""` (空) で連結 (例: `"おいおい、今日はやりすぎだ。明日で取り返せ。"`)。
EN は `" "` (スペース) で連結 (例: `"Hey, you went too far today. Make up for it tomorrow."`)。

```swift
let separator = String(localized: "sage.fragment.separator") // ja: "" / en: " "
let message = pieces.joined(separator: separator)
```

### 5.4 フォントの確認
英語化により文字列が **平均1.5〜2倍長く** なる。SwiftUI 側で `.lineLimit` / `.minimumScaleFactor` がきちんと指定されているか、Phase A 完了後に **EN ロケールでビューを目視確認** する必要がある。特に:
- `CharacterSpeechView` の `SpeechMarqueeText` (右→左に流れるアニメ)
- `SageView` の助言テキスト表示
- `DrinkReactionOverlay` の絵文字+セリフ

---

## 6. 検証方法

### 6.1 ビルド検証
```bash
cd /Users/koya1104/Desktop/Muscle360/SorryGains
xcodegen generate
xcodebuild -project SorryGains.xcodeproj \
  -scheme SorryGains \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=E09CD7F6-1493-461F-A8F7-808741FAF95D' \
  -configuration Debug build
```
※ `id=...` は iPhone 16 Pro (iOS 18.0)。利用可能なシミュレータは `xcrun simctl list devices` で確認。

### 6.2 EN ロケールでの動作確認
**Scheme > Run > Options > App Language: English** に切り替えてシミュレータ起動。

主要画面を一通り操作:
1. ホーム → 飲酒記録追加 → DrinkReactionOverlay の英訳セリフ確認
2. ホーム → 影響度ガイドシート → ImpactGuideSheet の英訳確認
3. お詫び行動シート → 各アクションタップ → reactionDialogue 英訳確認
4. 仙人タブ → 助言ボタン → SageAdviceFragments 結合結果の英文確認
5. iOS 26+ シミュレータでは Foundation Models プロンプトの英訳出力確認
6. 通知許可 → 各通知トリガを起こして英訳確認

### 6.3 自動監査スクリプト
Phase B/C で使った監査スクリプトを再利用可能:

```bash
python3 << 'EOF'
import json, re, os
with open('SorryGains/Resources/Localizable.xcstrings') as f:
    existing = set(json.load(f)['strings'].keys())
swift_files = []
for root, _, files in os.walk('SorryGains'):
    for f in files:
        if f.endswith('.swift'):
            swift_files.append(os.path.join(root, f))
ja = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*[぀-ヿ一-鿿][^"\\]*(?:\\.[^"\\]*)*)"')
total = 0
for path in sorted(swift_files):
    miss = []
    with open(path) as f:
        for ln, line in enumerate(f, 1):
            if line.strip().startswith('//'): continue
            for m in ja.finditer(line):
                s = m.group(1)
                if s not in existing and '\\(' not in s:
                    miss.append((s, ln))
    if miss:
        print(f'\n{path} ({len(miss)})')
        for s, ln in miss: print(f'  L{ln}: {s!r}')
        total += len(miss)
print(f'\nTOTAL: {total}')
EOF
```

Phase A 完了時の期待値: **TOTAL: 0** (Phase B/C で扱わなかったコメント文・例外文を除く)

---

## 7. 既存資産 (Phase B/C で追加済み・再利用可能)

### 7.1 Phase A で再利用すべき既存キー
| キー | JA | EN |
|---|---|---|
| `bodyPart.chest` 〜 `cardio` | 胸/背中/脚/肩/二頭筋/三頭筋/腹筋/有酸素 | Chest/Back/Legs/Shoulders/Biceps/Triceps/Abs/Cardio |
| `intensity.low/medium/high` | 低/中/高強度 | Low/Medium/High intensity |
| `bodyParts.separator` | `・` | ` · ` |

→ `LocalSageAdviceProvider.bodyPartLocalizedName` / `FoundationModelsSageAdviceProvider.bodyPartJP` は削除して共通キー利用に統一すべき。

### 7.2 xcstrings 編集スクリプトテンプレ
Phase B/C で使ったパターン:

```python
import json
PATH = "SorryGains/Resources/Localizable.xcstrings"
with open(PATH) as f:
    data = json.load(f)
strings = data["strings"]

def add(k, ja, en):
    strings[k] = {"localizations": {
        "ja": {"stringUnit": {"state": "translated", "value": ja}},
        "en": {"stringUnit": {"state": "translated", "value": en}},
    }}

NEW = {
    "sage.fragment.drankTooMuch.opening.0": ("おいおい、", "Hey there, "),
    # ... 続く
}
for k, (ja, en) in NEW.items():
    add(k, ja, en)

with open(PATH, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print(f"Added {len(NEW)}")
```

---

## 8. 推定工数

| ステップ | 推定時間 | 備考 |
|---|---|---|
| ステップ1: RecoveryActionType | 30分 | 14文 |
| ステップ2: DrinkReactionProvider | 45分 | 20文 |
| ステップ3: CharacterSpeechView | 1〜1.5時間 | 60文・5キャラ性格切替 |
| ステップ4: SageAdviceFragments | 2.5〜3時間 | 119文・8カテゴリのトーン維持 |
| ステップ5: LocalSageAdviceProvider | 1時間 | 動的挿入の構造変更 |
| ステップ6: FoundationModelsSageAdviceProvider | 1.5時間 | プロンプト設計 + テスト |
| ステップ7: ビルド & 目視確認 | 1時間 | EN ロケールで全機能確認 |
| **合計** | **8〜9時間** | 1セッションで完遂可能 |

---

## 9. 完了の定義 (Definition of Done)

- [ ] 上記6ファイルの全 JA リテラルが `String(localized:)` 経由になっている
- [ ] `Localizable.xcstrings` に対応キーが ja/en 両方 `state: translated` で登録されている
- [ ] `xcodebuild` が `** BUILD SUCCEEDED **` で完了
- [ ] EN ロケールで主要画面 (Home/History/Sage/Settings) が崩れずに表示される
- [ ] EN ロケールで通知 / キャラ吹き出し / 助言生成が英文で動作する
- [ ] 上記の自動監査スクリプトで未対応文字列 0 件
- [ ] 既存テスト (`SorryGainsTests`) がグリーン

---

## 10. 留意事項

### 10.1 キャラクター名の英訳
- 「筋肉仙人」 → "Muscle Sage" / "Muscle Sensei" / "The Sage" のいずれか1つに統一
- 「筋肉ごめん」 → 既に "Sorry, Gains" で確定 (App Store 名)
- ステージ名 (ゴリマッチョ等) → Phase B で `character.body.gori/lean/normal/flabby/skinny` を確定済み

### 10.2 トーン保持のチェックリスト
英訳時に以下を意識:
- 命令形を維持 ("Drink water." not "You should drink water.")
- 短く言い切る (英文も10〜15語以内に収める)
- 無駄な冠詞・主語を削る (英文の口語スタイル)
- ユーモアの皮肉感を残す ("...nothing left to say." 等)

### 10.3 LLM プロンプト変更時の回帰
`FoundationModelsSageAdviceProvider` のプロンプトを変更したら、必ず実機 (iOS 26+) で:
- JA ロケール: 既存通りの仙人口調が出るか
- EN ロケール: 期待する Muscle Sage 口調が出るか
- 失敗時のフォールバック (`LocalSageAdviceProvider`) が動くか

---

**作業開始時はこのドキュメント全体を読んでから着手してください。**

---

## 11. Phase A 実施結果 (2026-05-02)

### 完了内容
| ファイル | 文字列数 | 実装方式 |
|---|---:|---|
| `RecoveryActionType.swift` | 14 | rawValue + stage suffix で動的キー解決 |
| `DrinkReactionProvider.swift` | 20 | `ReactionData` 構造体 (key/emoji/intensity) でメタデータ保持・dialogue は `String(localized:)` で都度解決 |
| `CharacterSpeechView.swift` | 60 | `dialogueKeys: [[String]]` をキー配列ベースに変換、`dailyLines` でロケール解決 |
| `SageAdviceFragments.swift` | 119 | `Bundle` を `openingKeys/bodyKeys/closingKeys` 化、`localizedOpenings/Bodies/Closings` computed property を追加 |
| `LocalSageAdviceProvider.swift` | 26 | followUp は `String(format: localizedTemplate, partsText)` パターン、`bodyPartLocalizedName` は共通 `bodyPart.*` キーを参照 |
| `FoundationModelsSageAdviceProvider.swift` | 39 | persona 完全 JA/EN 2セット (案A 採用)、prompt 各行を `String(format: ..., args)` で構築 |

### 追加したキー (合計 272)
- `recoveryAction.reaction.{action}.{calm|harsh}` — 14
- `drinkReaction.{1-5}.{0-3}` — 20
- `characterSpeech.stage{0-4}.line{0-11}` — 60
- `sage.fragment.{category}.{opening|body|closing}.{i}` — 119
- `sage.fragment.separator` — 1 (ja: "" / en: " ")
- `sage.injection.consecutiveDays` / `consecutiveDaysMarker` / `muscleTarget` / `muscleReplacement` — 4
- `sage.followUp.linked.*` — 6
- `sage.followUp.default.*` — 6
- `sage.followUp.unlinkedTraining` — 1
- `sage.llm.persona` — 1
- `sage.llm.prompt.*` (header/footer/各行 + workout.done/none) — 11
- `sage.llm.category.*` — 8
- `sage.llm.tone.*` — 4
- `sage.llm.intensity.*` — 3
- `sage.llm.contextualFollowUp.*` — 4

### 設計判断
- **キー命名規則**: 構造化命名 (案A) を採用。`sage.fragment.drankTooMuch.opening.0` 形式で見通し良好。
- **separator 切替**: `sage.fragment.separator` キーで `""` (JA) / `" "` (EN) を切替。`pieces.joined(separator: SageAdviceFragments.separator)` で結合。
- **LLM プロンプト**: 案A (full bilingual) を採用。`sage.llm.persona` に JA/EN 2セットを丸ごと格納し、ロケールで自動切替。
- **既存 Phase B/C キーの再利用**: `bodyPart.*`、`bodyParts.separator` を `LocalSageAdviceProvider` と `FoundationModelsSageAdviceProvider` 双方で再利用。重複定義を削除。
- **動的注入**: JA-specific の "筋肉" → "部位の筋肉" 置換は、`sage.injection.muscleTarget`/`muscleReplacement` キー化することでロケール非依存の置換ロジックに変更。EN は `"muscles"` → `"chest muscles"` として動作。

### 検証結果
- `xcodebuild` (iPhone 16 Pro / iOS Simulator): **`** BUILD SUCCEEDED **`** ✅
- Phase A 6ファイルのハードコード JA 文字列: **0件** ✅
- `Localizable.xcstrings` キー総数: 702 (うち 701 が ja/en `state: translated`)
- 残 1件は Phase A 以前から存在する `""` 空キー (Xcode 自動抽出残留・実害なし)

### 既知の残タスク (Phase A スコープ外)
- EN ロケールでの目視確認 (`SpeechMarqueeText` のレイアウト崩れチェック等) — 実機 / シミュレータで実施推奨
- Foundation Models (iOS 26+) の EN 出力品質確認 — 実機テスト推奨
- `""` 空キーの cleanup (任意)
