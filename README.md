# AvoidZeppNagoya

Zepp Nagoya で開催されるイベントの混雑時間帯を通知する iOS / macOS / watchOS アプリです。

---

## 機能

### 混雑通知

Zepp Nagoya の公式サイトからイベントスケジュールを取得し、混雑が予想される時間帯にローカル通知を送ります。

| 通知タイミング | 内容 |
|--------------|------|
| 開演時刻 | 🔴「Zepp Nagoya 混雑中 – [アーティスト名] 開場」 |
| 開演時刻 + 30分 | 🟢「Zepp Nagoya 混雑解消」 |
| 推定終演時刻 | 🔴「Zepp Nagoya 混雑中 – [アーティスト名] 終演」 |
| 推定終演時刻 + 30分 | 🟢「Zepp Nagoya 混雑解消」 |

> **推定終演時刻について**
> 公式サイトには終演時刻が掲載されていないため、開演時刻に「公演時間の目安」を加算した時刻を使用します。目安は設定画面で 1.5 / 2 / 2.5 / 3 時間から選択できます（デフォルト: 2時間）。

### スケジュール取得

当月・翌月の2ヶ月分のイベント情報を自動取得します。

#### 最小スクレイピング間隔

意図的に **6時間** を最小間隔として設定しています。

```
isStale = (現在時刻 - 最終取得時刻) > 6時間
```

- アプリ起動時: データが6時間以上古い場合のみ取得
- iOS バックグラウンド (`BGAppRefreshTask`): 次回実行を最低6時間後にリクエスト
- 手動更新（「今すぐ更新」ボタン）: 間隔制限なし

1回の更新で最大 約60リクエスト（2ヶ月 × 約30日）が発生しますが、そのほとんどはイベントのない日のカレンダーページのみの取得で終わります。実際のイベント詳細ページへのアクセスはイベント開催日数分（月に数件〜十数件）に限られます。

また、全リクエストに以下の User-Agent を付与しています。

```
AvoidZeppNagoya/1.0 (contact: buru.aoshin@gmail.com)
```

### 設定画面

| 項目 | 内容 |
|------|------|
| 通知を有効にする | 通知の ON / OFF |
| 公演時間の目安 | 1.5 / 2 / 2.5 / 3 時間（終演通知の基準） |
| 今すぐ更新 | スケジュールを即時取得して通知を再スケジュール |

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
│  │ 月カレンダー取得 │      │ 最大16イベント分     │      │
│  │ → イベント日抽出│      │ (= 64通知) を登録    │      │
│  │ → 日別詳細取得  │      └──────────────────────┘      │
│  └────────┬────────┘                ▲                   │
│           │                         │                   │
│           ▼                         │                   │
│       EventStore  ──────────────────┘                   │
│  ┌──────────────────────────────────┐                   │
│  │ @MainActor ObservableObject      │                   │
│  │ - events: [ZeppEvent]            │                   │
│  │ - concertDuration: TimeInterval  │                   │
│  │ - notificationsEnabled: Bool     │                   │
│  │ UserDefaults で永続化            │                   │
│  └──────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────┘
         ▲                  ▲                  ▲
         │                  │                  │
┌────────┴──────┐  ┌────────┴──────┐  ┌────────┴──────┐
│     iOS/      │  │    macOS/     │  │   watchOS/    │
│               │  │               │  │               │
│ App.swift     │  │ App.swift     │  │ App.swift     │
│ ContentView   │  │ ContentView   │  │ ContentView   │
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
    ├─► ScheduleFetcher.fetchEvents()
    │       │
    │       ├─► GET /schedule/?_y=YYYY&_m=M  （カレンダー）
    │       │       └─► .event-calendar-date a → イベント日を抽出
    │       │
    │       └─► GET /schedule/?_y=YYYY&_m=M&_d=D  （日別、イベント日のみ）
    │               └─► .sch-contentWrap .sch-content → [ZeppEvent]
    │
    ├─► UserDefaults に保存
    │
    └─► NotificationScheduler.scheduleNotifications()
            └─► 既存の Zepp 通知を削除 → 直近16件分を再登録
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
