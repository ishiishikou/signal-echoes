# Signal Echoes — 引継ぎ監査・完了審査

作成・確認日: 2026-11-20 UTC。対象: `ishiishikou/signal-echoes`。納品先: AIRの `/workspace/signal-echoes-planning-20261120`。この文書は引継ぎ先ChatGPTのための内部監査を含む。Public用READMEと異なり、privateな運用ルールへの参照や実行ログの所在を含むため、GitHubへ自動転記しない。

## 1. 依頼範囲と成果

依頼は日本語Markdown7件による技術調査・設計レビュー・詳細実装計画。アプリの実装、GitHubへの書込み、課金、本人情報の公開、実アプリ配布は対象外。中断後、ユーザーは完成済み01を基準に残り6件の作成と全体の整合・非空検査を指示した。

| ファイル | 独立して読める内容 | 状態 |
| --- | --- | --- |
| [01-product-spec.md](01-product-spec.md) | 目的・非目的、3視点、ユーザーストーリー、指標、観測/演出、最小化 | 完成済み文書を保持 |
| [02-technical-design.md](02-technical-design.md) | API、前景記録、単調時計、仮ID、スキーマ、擬似コード、完全な合成JSON入出力 | 作成 |
| [03-implementation-roadmap.md](03-implementation-roadmap.md) | ディレクトリ、初回コマンド、T00〜T09、Mac操作、工程ゲート | 作成 |
| [04-test-and-acceptance.md](04-test-and-acceptance.md) | A01〜A12、D01〜D12、P01〜P06、fixture、電池・UX・機密検査 | 作成 |
| [05-open-questions.md](05-open-questions.md) | 推奨判断、Q01〜Q18、Windows中心のiPhoneビルド経路、再検討条件 | 作成 |
| [README.md](README.md) | publicに載せられる説明、未実装ステータス、次の実装、データ非公開 | 作成 |
| [06-handoff-audit.md](06-handoff-audit.md) | 確認証拠、未検証、完了判定、引継ぎチェックリスト | 本書 |

初期依頼・実行ログ・再開スクリプトなどの既存ファイルは7件の成果物に含めない。これらはprivateな会話や実行環境情報を含み得るため、公開候補にも含めない。

## 2. 確認済みの事実と証拠の種類

| 項目 | 今回確認した内容 | 限界 |
| --- | --- | --- |
| 対象repo | GitHub connectorのread-only取得でpublic、default_branch main、size 0 | 初期コミットが存在するという意味ではない。今回書込みなし |
| 作業場所 | shellのcwdと既存依頼ファイルを確認。AIR connectorでも同じpathの依頼ファイルをstatし8,500bytesを確認 | ファイル存在の証拠。端末でのアプリ動作の証拠ではない |
| 起動設定 | 既存`astra-run.log`冒頭にmodel gpt-6-astra、reasoning effort high、workdirを確認 | 実行ログに記録された設定。自己申告から推定したものではない |
| ルール | 非公開運用ルールの適用箇所を確認 | 関連しない全ノートの一括読込はしていない |
| BLE | Apple API本文と背景処理、peer identifier、SIGのPrivacy/Direction Findingを確認 | 実機の検出率・RSSI品質は未測定 |
| 自己位置 | Appleのaccuracy・heading・reduced accuracy・CMPedometer・ARKitを確認 | 駅での精度や本人端末の可用性は未測定 |
| ビルド | Xcode対応表、Personal Team、Developer Modeの公式説明を確認 | 本人のMac・Apple Accountへログインしていない |
| 文書例 | JSON構文・数値例・参照をローカル検査する | アプリコードの実行とは区別する |

## 3. 運用ルールの適用

Astraはユーザーの非公開運用ルールを確認し、許可範囲・作業完了判定・不確実性の記録を適用した。非公開リポジトリの内部URLや内容はPublic版に含めない。

## 4. 技術調査の一次資料台帳

全て2026-11-20にWebツールで取得・確認。JS本文だけだったAppleページは提供される`.md`リンクを開いてAPI本文を確認した。資料にない試作閾値は設計判断として分けている。検索結果だけで実測結果を推定していない。

| ID | 公式資料URL | 確認した主張・設計への反映 |
| --- | --- | --- |
| S01 | [CoreBluetooth scanForPeripherals](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/scanforperipherals%28withservices%3Aoptions%3A%29) | nil/サービスフィルター、発見callback、背景のサービス指定 |
| S02 | [didDiscover](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/centralmanager(_:diddiscover:advertisementdata:rssi:).md) | RSSIを伴う受信callback、広告情報は別の引数。保存範囲はアプリで限定 |
| S03 | [CBPeer.identifier](https://developer.apple.com/documentation/corebluetooth/cbpeer/identifier) | OSがpeerへUUIDを割り当てる。MACや人物IDとして扱わない |
| S04 | [Core Bluetooth Background Processing](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html) | 背景で重複検出を集約、間隔増大・停止可能性。古いarchive資料なのでS01とも照合 |
| S05 | [Bluetooth SIG: LE Privacy](https://www.bluetooth.com/blog/bluetooth-technology-protecting-your-privacy/) | アドレスランダム化の仕組み。CoreBluetooth UUIDの具体寿命はこの資料から決めない |
| S06 | [Bluetooth SIG: Direction Finding](https://www.bluetooth.com/learn-about-bluetooth/feature-enhancements/direction-finding/) | AoA/AoDに専用の信号・アンテナ構成。一般RSSIから方向が得られるとしない |
| S07 | [horizontalAccuracy](https://developer.apple.com/documentation/corelocation/cllocation/horizontalaccuracy) | 位置不確かさの半径と負値の無効性 |
| S08 | [headingAccuracy](https://developer.apple.com/documentation/corelocation/clheading/headingaccuracy.md) | 方位誤差、負値は無効 |
| S09 | [accuracyAuthorization](https://developer.apple.com/documentation/corelocation/cllocationmanager/accuracyauthorization.md) | reducedAccuracy下で要求精度だけを変えても精密位置にできない |
| S10 | [CMPedometer](https://developer.apple.com/documentation/coremotion/cmpedometer.md) | 歩数等の可用性チェック、非同期更新、NSMotionUsageDescription |
| S11 | [CMPedometerData](https://developer.apple.com/documentation/coremotion/cmpedometerdata) | 距離・ペース・階数は推定・optionalを含む |
| S12 | [ARKit tracking quality](https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality) | カメラ画像＋慣性情報、limited/notAvailable、中断 |
| S13 | [Understanding World Tracking](https://developer.apple.com/documentation/arkit/understanding-world-tracking) | 右手系座標と環境条件。GPSとの原点一致は別問題 |
| S14 | [Xcode system requirements](https://developer.apple.com/xcode/system-requirements) | macOS・SDK・実機対応表。最新番号の断定を避け実装時再確認 |
| S15 | [Developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account) | Personal Team、7日期限と再インストール制約 |
| S16 | [Enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device.md) | 本人による端末設定・再起動・確認 |
| S17 | [NSBluetoothAlwaysUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription) | Bluetooth用途説明キー。名称のAlwaysを背景実行許可と混同しない |
| S18 | [Requesting access to protected resources](https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources) | 用途説明と権限の提示 |
| S19 | [isExcludedFromBackup](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup.md) | Application Support等のバックアップ除外。ユーザー文書のコピーは別管理 |
| S20 | [Vite guide](https://vite.dev/guide/) | vanilla-ts開始コマンド、Node要件 |
| S21 | [three.js installation](https://threejs.org/manual/pages/installation.html) | npm＋開発サーバーでの構成 |

証拠の強さ: S01〜S21はAPI・開発経路の根拠。単一RSSI時系列の非同定性は、方向観測がなく自己/他者運動・遮蔽等が同じ系列を生むという設計上の推論を含む。特定の誤差率を示す査読論文による性能実証は今回行っていない。RSSI閾値、120秒/30秒、15分、24時間、性能・電池目標は本計画の選択で、公式規格値と誤認させない。

## 5. 未確認・未実施

| 項目 | 状態 | 理由・次担当 |
| --- | --- | --- |
| アプリコード／自動テスト実装 | 未実施 | 今回の範囲外。新しい実装指示後にChatGPT/実装担当 |
| Mac/Xcode/iPhone/広告機器の利用可否 | 未確認 | 本人環境確認が必要。05のQ01〜Q04 |
| BLE更新率・UUID挙動・電波欠測 | 未実測 | D02/D03。専用機器以外への検出保証なし |
| 屋内測位・階層・方位・電池 | 未実測 | D05/D06/D11。階層はM1対象外 |
| 実機→PCの転送E2E | 未実施 | D09。Mac経由が第一候補、Windows直結のみは未確認 |
| 体験が楽しいか、理解できるか | 未評価 | 本人のD12が必要。文書の説得力を実体験の証明にしない |
| アプリ配布、追加公開、課金 | 未実施 | 設計対象外 |
| 第三者による独立レビュー | 未実施 | 自己レビューと静的検査を実施。独立検証は完了審査側で可能 |

これらは文書納品の未完ではなく、後続の実装・実機受入の未完。未確認を埋めるために本人へ途中質問はしていない。

## 6. 横断レビューと修正

- 01の値を正本として、セッション15分、仮ID寿命120秒、途絶30秒、残光3〜8秒、保持24時間を02〜05で揃えた。
- 自己位置の5秒以内補間と、BLE欠測中の残光を分離。後者を観測レコードへ戻さない。
- 「同行らしさ」の分類をMVPから外し、受信継続と強度傾向だけを導出する。
- 02の完全JSON例は自己位置2点の間が9秒なので途中の経路を補間しない。t=10秒の粒の座標は観測された自己位置＋演出offsetとした。
- M0の期限・品質テストはTypeScriptの参照関数で行い、M1でSwift側を同じ境界表で試す。Mac不要のM0に実機成功を混入させない。
- READMEが参照する01〜05を将来repoのルートへ置く構成に統一。06と既存実行ログは自動公開しない。
- stress fixtureを78,601件に定め、100,000件の取り込み上限を超えないようにした。描画256粒上限は別fixtureで検証する。

## 7. 納品前の静的検査

検査結果はこの節に確定記録する。検査対象は7文書と埋込みJSONであり、アプリの動作ではない。

**検査結果: PASS（2026-11-20、ローカル静的検査）。**

- 指定7ファイルすべてUTF-8で読取り可能、非空、先頭見出しあり。
- ローカルMarkdownリンク26件の参照先が存在。コードフェンスは各ファイルで対応。
- 02のJSONコードブロック2件をPython `json.loads`で解析成功。入出力のschema・時刻・ビン境界・重複・値域を検査。
- rise例の独立再計算: slope 1dB/s、5秒中央値-73dBm、age100ms、intensity0.55。FNV1a32=4042573567から仮想座標[14.5956,1.2,-2.1654]が小数4桁で一致。
- 自己位置の9秒gapは5秒補間上限超過、尾0の出力が整合。sourceDirectionとsourceDistanceMはnull。
- stress件数は256×300＋900＋901=78,601、100,000件上限未満。最終終了イベントを含む上限の予約も設計へ追記。
- 01は初回確認から内容を変更していない（SHA-256先頭16桁: `0faa2b0d4668baf8`）。既存依頼・ログ・スクリプトは変更対象外。
- RSSI・位置・保持・識別期限・M0/M1境界・公開範囲を文書横断で自己レビュー。残る未検証は節5に列挙。
- これらは文書と数値例の検査であり、アプリのunit/E2E/実機試験を実施したことにはしない。

再確認コマンド（Python標準ライブラリのみ、アプリ実装ではない）:

```bash
python3 - <<'PY'
from pathlib import Path
import json, re
root = Path('/workspace/signal-echoes-planning-20261120')
names = ['01-product-spec.md','02-technical-design.md','03-implementation-roadmap.md',
         '04-test-and-acceptance.md','05-open-questions.md','README.md','06-handoff-audit.md']
for name in names:
    p = root / name
    text = p.read_text(encoding='utf-8')
    assert text.strip(), name
    assert sum(line.startswith('```') for line in text.splitlines()) % 2 == 0, name
    for target in re.findall(r'\]\(([^)]+\.md)\)', text):
        if not target.startswith(('http:', 'https:')):
            assert (root / target).is_file(), (name, target)
    for block in re.findall(r'```json\n(.*?)\n```', text, re.S):
        json.loads(block)
    print(name, p.stat().st_size, 'bytes OK')
PY
```

## 8. ChatGPTによる完了審査チェックリスト

文書審査:

- [ ] 7件をAIRの指定pathから読み、存在・非空を確認した。
- [ ] 目的・非目的・3視点・ユーザーストーリー・指標を01から理解できる。
- [ ] 観測／導出／演出がschema・擬似コード・UIの全てで分離されている。
- [ ] 単一RSSIから人物の位置・方向・速度・同行を確定しない。
- [ ] peer UUID・アドレスランダム化・未検出・欠測を扱っている。
- [ ] iOS前景・背景の違いと、ロック中に記録しないM1の制約が明記されている。
- [ ] 自己位置・方位・歩行・AR・階層の制約を別々に扱っている。
- [ ] 完全な合成JSONと期待出力があり、数値と時刻が整合している。
- [ ] T00〜T09の前提・改修ファイル・検証・合格条件が具体的である。
- [ ] MacなしでできるM0と、人の操作が要るiOS経路が明確である。
- [ ] 04の実機・電池・UX・公開候補検査を実装後の担当が実行できる。
- [ ] Public READMEが未実装を明記し、実測公開を誘導していない。
- [ ] 公式ソースと確認日があり、実測していないことを実測済と呼んでいない。
- [ ] Astra自身は課金・配布・アプリ実装を行っていない。
- [ ] 今回の終了理由が文書完成であり、アプリ完成と混同していない。

実装受入（今はチェックしない）:

- [ ] M0のA試験・適用P試験と本人UX評価に合格。
- [ ] S1のD01〜D03でiPhone実機の成立性を確認。
- [ ] M1の全必須D/P試験に証拠があり、未実施を合格にしていない。
- [ ] 必要な新しい実装・公開等の権限が明確に与えられている。

## 9. 返却時の状態

- **実施**: 技術調査、非公開運用ルール適用確認、設計レビュー、日本語Markdown7件、横断レビュー。
- **検証**: 公式API本文・開発経路の確認、ファイルと埋込み例の静的検査。確定結果は節7。
- **未完**: アプリ実装・機械テスト・実機E2E・本人評価。今回の依頼外であり未実施。
- **停止理由**: 文書作成の依頼範囲を完了して終了する。費用や実機操作の回答待ちで文書を残したわけではない。
- **次担当**: 引継ぎ先ChatGPTが本チェックリストで審査。実装指示を受けた担当は03のT00から開始し、必要な端末操作のみ本人が行う。