# AvoidZeppNagoya

Zepp Nagoya で開催されるイベントの混雑時間帯を通知する iOS / macOS / watchOS アプリです。

---

## 機能

### 混雑通知

Zepp Nagoya の公式サイトから当日のイベントスケジュールを取得し、混雑が予想される時間帯にローカル通知を送ります。

| 通知タイミング | 内容 |
|--------------|------|
| 開演時刻 | 🔴「Zepp Nagoya 混雑中 – [アーティスト名] 開場」 |
| 開演時刻 + 30分 | 🟢「Zepp Nagoya 混雑解消」 |
| 推定終演時刻 | 🔴「Zepp Nagoya 混雑中 – [アーティスト名] 終演」 |
| 推定終演時刻 + 30分 | 🟢「Zepp Nagoya 混雑解消」 |

> **推定終演時刻について**
> 公式サイトには終演時刻が掲載されていないため、開演時刻に「公演時間の目安」を加算した時刻を使用します。目安は設定画面で 1.5 / 2 / 2.5 / 3 時間から選択できます（デフォルト: 2時間）。

### スクレイピング設計

サイトへの負荷を最小限に抑えるため、以下の制約を設けています。

#### 取得対象: 当日分のみ

1回の更新で発生するリクエストは **最大2回**（当日詳細ページ1回 + 存在しない場合は1回のみ）です。

#### 動作時間帯: 平日 17:00〜21:00 JST のみ

```
TimeWindow.isActive() = 平日 かつ 17:00 ≤ 現在時刻 < 21:00 (JST)
```

この条件を満たさない場合、起動時の自動更新・バックグラウンド更新ともに実行をスキップします。通知も同様に、この時間帯外にトリガーされるものはスケジュールしません。

#### 最小スクレイピング間隔: 6時間

```
isStale = (現在時刻 - 最終取得時刻) > 6時間
```

- アプリ起動時: データが6時間以上古い場合のみ取得
- iOS バックグラウンド (`BGAppRefreshTask`): 次回実行を最低6時間後にリクエスト

上記3つの制約を組み合わせると、実質的な更新頻度は **週1〜3回程度** に収まります。

#### User-Agent

全リクエストに連絡先を付与しています。

```
contact: buru.aoshin@gmail.com
```

### 設定画面

| 項目 | 内容 |
|------|------|
| 通知を有効にする | 通知の ON / OFF |
| 公演時間の目安 | 1.5 / 2 / 2.5 / 3 時間（終演通知の基準） |

---

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                        Shared/                          │
│                                                         │
│  ScheduleFetcher          NotificationScheduler         │
│  ┌─────────────────┐      ┌──────────────────────┐      │
│  │ URLSession      │      │ UNUserNotification   │      │
│  │ + SwiftSoup     │      │ Center               │      │
│  │                 │      │                      │      │
│  │ 当日の詳細ページ │      │ 平日17〜21時の        │      │
│  │ を1回取得       │      │ 通知のみ登録          │      │
│  └────────┬────────┘      └──────────────────────┘      │
│           │                         ▲                   │
│           ▼                         │                   │
│       EventStore  ──────────────────┘                   │
│  ┌──────────────────────────────────┐                   │
│  │ @MainActor ObservableObject      │                   │
│  │ - events: [ZeppEvent]            │                   │
│  │ - concertDuration: TimeInterval  │                   │
│  │ - notificationsEnabled: Bool     │                   │
│  │ UserDefaults で永続化            │                   │
│  └──────────────────────────────────┘                   │
│                                                         │
│  TimeWindow                                             │
│  ┌──────────────────────────────────┐                   │
│  │ 平日 17:00〜21:00 JST か判定     │                   │
│  │ → false なら refresh() をスキップ │                   │
│  └──────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────┘
         ▲                  ▲                  ▲
         │                  │                  │
┌────────┴──────┐  ┌────────┴──────┐  ┌────────┴──────┐
│     iOS/      │  │    macOS/     │  │   watchOS/    │
│               │  │               │  │               │
│ BGAppRefresh  │  │ 起動時リフレ  │  │ 起動時リフレ  │
│ Task で       │  │ ッシュのみ    │  │ ッシュのみ    │
│ バックグラウ  │  │               │  │               │
│ ンド更新      │  │               │  │               │
└───────────────┘  └───────────────┘  └───────────────┘
```

### データフロー

```
起動 / BGAppRefreshTask
    │
    ▼
EventStore.refresh()
    │
    ├─ TimeWindow.isActive()? No → 終了（スクレイピングしない）
    │
    ↓ Yes
    ├─► ScheduleFetcher.fetchEvents()
    │       │
    │       └─► GET /schedule/?_y=YYYY&_m=M&_d=D  （当日のみ）
    │               └─► .sch-contentWrap .sch-content → [ZeppEvent]
    │
    ├─► UserDefaults に保存
    │
    └─► NotificationScheduler.scheduleNotifications()
            └─► 既存の Zepp 通知を削除
                → 平日17〜21時に該当する通知のみ登録
```

### 依存ライブラリ

| ライブラリ | 用途 |
|-----------|------|
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) | HTML パース（Swift Package Manager） |

---

## 動作環境

| プラットフォーム | 最低バージョン |
|----------------|--------------|
| iOS | 17.0+ |
| macOS | 14.0+ |
| watchOS | 10.0+ |

---

## セットアップ

```bash
# xcodegen でプロジェクト生成（初回 or project.yml 変更時）
brew install xcodegen
xcodegen generate

open AvoidZeppNagoya.xcodeproj
```

watchOS SDK が未インストールの場合は Xcode > Settings > Components からインストールしてください。
