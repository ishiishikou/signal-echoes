# Signal Echoes — 実装ロードマップと担当手順

作成・確認日: 2026-11-20 UTC。これは将来の実装担当ChatGPT向け計画で、**今回の実装承認ではない**。現在の成果は7件の設計文書。対象リポジトリは `https://github.com/ishiishikou/signal-echoes`、調査時点でpublic・main・size 0。本計画の作成時点でアプリの実装・配布、費用発生、本人情報公開は未承認。設計文書についてはChatGPTが公開向けに整え、GitHubに登録した。

目的は、短い移動区間のBLE受信変化を、人物位置と誤認させない光点として再生すること。実装は合成データから開始し、実機の成立性を早期に別ゲートで確認する。RSSIから人物の進行方向・速度を求めるタスクは作らない。

## 1. 承認境界と分担

| 作業 | 次担当 | 前提・権限 |
| --- | --- | --- |
| 本文書の完了審査 | 引継ぎ先ChatGPT | 読取り・文書検査。今回の承認内 |
| Web試作のローカル実装・依存導入 | 実装担当AI | 新しい実装指示で範囲を確認。今回未実施 |
| iOSコード作成・Macビルド | 実装担当AI／Mac操作可能な担当 | 利用可能なMacへのアクセス権、互換Xcode、実機が必要 |
| Apple Accountログイン、信頼、Developer Mode、OS権限 | 本人 | パスコード・2FAをAIログへ渡さない |
| 私有機器での記録試験 | 本人＋実装担当 | 試験場所・機器・転送先が決まっていること |
| GitHub commit/push/PR、公開ホスティング、TestFlight等 | 別途指定された担当 | 今回の承認外。計画の完了条件には含めない |

作業再開時は利用者の非公開運用ルールを再確認し、既存ファイルを読む。作業許可が実装まで与えられたら、範囲内のコード作成・検証は段階ごとの形式的確認で止めない。新規課金・公開・配布・実個人データの共有は別の境界である。

## 2. 成果物構成（まだ存在しない将来のファイル）

```text
signal-echoes/
  README.md
  01-product-spec.md            # 01〜05はREADMEと同じルートへ置く
  02-technical-design.md
  03-implementation-roadmap.md
  04-test-and-acceptance.md
  05-open-questions.md
  docs/                         # 検証記録。06の内部監査は自動公開しない
  .gitignore
  .node-version
  .npmrc                        # save-exact=true
  package.json
  package-lock.json
  apps/
    viewer/
      package.json
      index.html
      vite.config.ts
      src/main.ts
      src/style.css
      src/import/import-session.ts
      src/worker/analysis.worker.ts
      src/scene/create-scene.ts
      src/scene/particles.ts
      src/scene/self-path.ts
      src/scene/cameras.ts
      src/ui/timeline.ts
      src/ui/quality-panel.ts
    recorder-ios/
      SignalEchoes.xcodeproj/
      SignalEchoes/SignalEchoesApp.swift
      SignalEchoes/SessionController.swift
      SignalEchoes/BLEScanner.swift
      SignalEchoes/EphemeralIdentityMap.swift
      SignalEchoes/LocationRecorder.swift
      SignalEchoes/MotionRecorder.swift
      SignalEchoes/SessionWriter.swift
      SignalEchoes/SessionExporter.swift
      SignalEchoes/Models.swift
      SignalEchoes/Info.plist
      SignalEchoesTests/
  packages/core/
    package.json
    src/schema.ts
    src/types.ts
    src/config.ts
    src/validate.ts
    src/time.ts
    src/identity-policy.ts       # 仮時計で期限契約を試す参照関数
    src/signal.ts
    src/self-path.ts
    src/render-frame.ts
    src/index.ts
    test/
  fixtures/synthetic/
    manifest.json
    rise.json
    quiet.json
    gaps.json
    noisy.json
    id-rotation.json
    indoor.json
    stress.json
  scripts/generate-fixtures.ts
  scripts/check-public-data.ts
  tests/e2e/
  docs/validation/               # 合成のみのテスト結果・環境情報
```

実測、実機スクリーンショット、署名、私有情報入りログはcheckout外の本人管理ディレクトリへ置く。`apps/viewer/public`に実測を置くとそのまま配信されるため禁止。

## 3. 最初のコマンド（将来の実装開始後のみ実行）

以下はWindowsのWSL2 bashまたはAIRでWeb試作を作る例。計画書のディレクトリで実行しない。NodeがVite要件を満たさなければ保守中の対応LTSを既存の管理方式で用意する。有料サービスや外部公開は不要。

```bash
node --version
npm --version
git --version
test ! -e /workspace/signal-echoes-implementation
git clone https://github.com/ishiishikou/signal-echoes.git /workspace/signal-echoes-implementation
cd /workspace/signal-echoes-implementation
git status --short
npm init -y
npm pkg set private=true --json
npm pkg set 'workspaces[0]=apps/viewer' 'workspaces[1]=packages/core'
npm config set save-exact true --location=project
mkdir -p apps packages/core fixtures/synthetic scripts tests/e2e docs/validation
npm create vite@latest apps/viewer -- --template vanilla-ts --no-interactive
cd packages/core
npm init -y
npm pkg set name=@signal-echoes/core type=module
cd ../..
npm install three zod --workspace apps/viewer
npm install zod --workspace packages/core
npm install --save-dev typescript vitest @playwright/test tsx @types/three
```

各コマンドの終了コードを確認して次へ進む。上の`test`が失敗したら削除せず既存内容を確認する。空repo clone時の空リポジトリ警告は想定内。ネットワークや権限で失敗したときは別サービスへ自動登録しない。ここでの`@latest`は初回選定だけで、生成後はpackage.jsonの全直接依存を選定したexact版へ揃え、lockfileとNode/npm版を記録し、以後`npm ci`で再現する。

次にcoreの`exports`を`./src/index.ts`へ、viewerからの依存をローカルworkspaceの対応版へ設定し、ViteがTSソースを解決することをbuildで確認する。Zodでstrict schemaとJSON受入を実装する。rootに下記scriptsを作ってから試験を実行する（まだ存在するコマンドではない）。

| script | 定義案 |
| --- | --- |
| `dev` | `npm run dev --workspace apps/viewer -- --host 127.0.0.1` |
| `build` | `npm run build --workspace apps/viewer` |
| `typecheck` | `tsc --noEmit -p packages/core/tsconfig.json && tsc --noEmit -p apps/viewer/tsconfig.json` |
| `test` | `vitest run` |
| `fixtures` | `tsx scripts/generate-fixtures.ts` |
| `check:public-data` | `tsx scripts/check-public-data.ts` |
| `test:e2e` | `playwright test` |

ブラウザの初回セットアップは`npx playwright install chromium`。AIRだけでlocalhostへ到達できない場合はローカルWindowsへソースを置いて同じ手順で起動するか、許可済みのローカル転送を使う。`--host 0.0.0.0`やトンネルの外部公開を勝手に追加しない。原則はWindowsブラウザから`http://localhost:5173`。

## 4. 順序付き作業カード

### T00 — 計画の取込み・環境確認

前提: 新しい実装指示。入力は本7文書。作業: 実装権限、OS、Node/npm、Mac有無、iPhone/iOS、広告用の私有機器の有無を実際に確認し、`docs/validation/environment.md`へ機種の一般名と版だけ記録。Apple ID・シリアル・正確な所在地は記録しない。`.gitignore`には`raw/ measured/ private/ captures/ exports/ *.ipa *.p12 *.mobileprovision .env*`、Xcodeのuserdata、node_modules、dist、テスト一時出力を追加する。

合格: 実測を保存する場所がcheckout外に定まり、Web経路とMac経路を分けられる。MacなしはM0を止める理由にしない。S1は環境待ちとする。

### T01 — データ契約を先に固定

改修: `packages/core/src/{types,schema,config,validate,time}.ts`、core/package.json・tsconfig、root scripts。手順: 02のSessionV1をstrictで実装し、時刻・サイズ・件数・ID・有限値を検証。schemaに`analysis`や`render`を混入できないことを確認。`sourceDirection`や`sourceDistanceM`は導出型でnull以外を許さない。

検証: 04のA01〜A04。合格: 02の完全JSONが読め、未知版・NaN・余剰フィールド・重複が明示的に拒否される。無効ファイルの中身をconsoleへdumpしない。

### T02 — 再現できる合成データと計算

改修: `scripts/generate-fixtures.ts`、`fixtures/synthetic/*`、`signal.ts`、`self-path.ts`、`render-frame.ts`、`identity-policy.ts`、各unit test。手順: 決定的PRNG（例xorshift32、非ゼロseed、unsigned32処理を仕様化）を使って04のfixtureを生成。trace寿命を120秒以内に分割。Theil–Sen、median、gap、品質ラベル、仮想配置を純粋関数で実装する。期限・無効値・位置品質の契約もTypeScript参照関数で試し、M1のSwift側は同じ入力表で照合する。

合格: 02の入出力例と数値一致（表示座標は誤差1e-4以内）、再生成byte一致、未来値を変更しても過去フレームは変わらない。追跡IDの再結合やRSSI→距離換算がない。

### T03 — 最小の3D体験

改修: viewerのmain、scene一式、style。手順: まず合成riseのみで床・自己軌跡・粒を表示。InstancedMeshまたはPointsで最大256粒、上限超過はhash順で安定選択。3視点・軌跡切断・固定ステージ・小さな残光を実装。フレーム時刻は再生時計から求め、実時間deltaの累積でseek結果が変わらない構造にする。

検証: 合成riseとindoorで表示。合格: 粒の位置・数に関する常時説明があり、位置欠測を実経路に見せない。shader/GPU不対応なら時系列表が使える。

### T04 — 時間操作・インポート・誤解防止

改修: timeline、quality-panel、import-session、worker、e2e。手順: 0.5/1/2/4倍、一時停止、シーク、先頭、ファイル読込、品質凡例を追加。File API以外のURLインポートはMVPに作らない。Workerに大きいparse/analysisを移し、キャンセルとファイル差替え時の解放を実装。画面状態と読み込み失敗をキーボードでも確認できるようにする。

合格: US-01〜US-06のうち合成で検証できる部分、04のA05〜A12。ネットワークの外部送信0。演出と観測の違いを説明なしで理解できなければラベルを直す。

### G0 — M0判定

T01〜T04の必須テストを実行し、合成スクリーンショット、機械テスト結果、本人の体験評価をまとめる。本人評価が未実施なら「自動検証済／体験未評価」でありM0受入完了とはしない。S1環境があればT03後に先行してS1へ進め、視覚調整だけに時間を使い続けない。

### T05 / S1 — iPhoneの最小成立性スパイク

前提: 利用可能なMac・対応Xcode・本人iPhone・既知の広告機器。改修: recorder-iosのproject、BLEScanner、EphemeralIdentityMap、SessionController、Models、最小Writer、Info.plist。初期スパイクはBLEと状態だけ。位置・モーションは次工程。

手順: XcodeでiOS App / Swift / SwiftUI / bundle IDを作る。本人がPersonal Teamを選び、実機ペアリングとDeveloper Modeを設定。Bluetooth用途説明を付け、`poweredOn`後にサービス指定スキャン。`connect`やGATT呼出しなしで、私有機器から2分×3回記録。RSSI、1秒ビン件数、callback間隔、scanActive、無効値件数だけを保存する。次にnilフィルターでも同じ私有機器を比較する。画面ロック・復帰も1回確認する。

合格: 04のD01〜D03。既知機器で充足率80%以上を目標とし、届かない場合は広告周期・機器状態・OS・権限を確認して1回調整し再試験。閾値を下げて無理に成功とせず、疎観測型への縮小案を05に追記する。MacなしならS1未検証のままM0を仕上げる。

### T06 — 自己位置・歩行・時刻・状態

改修: LocationRecorder、MotionRecorder、SessionController、Models、Info.plist、XCTest。手順: When In Use位置とモーションの用途説明を加え、API availabilityを確認。単調時計・位置timestamp変換、古い位置の拒否、位置品質、原点・segment切断を実装。緯度経度は変換中のメモリだけ。前景を失ったら各サービスを停止し、復帰時に本人が再開する。再開時は仮ID表を初期化する。

合格: D04〜D06。位置・モーション拒否でもクラッシュせず、保存時のnullと理由が正しい。画面ロックを止めるためにidleTimerを無効化しない。階数推定やARKitは入れない。

### T07 — 保存・回復・転送

改修: SessionWriter、SessionExporter、import-session、core/schema、XCTest。手順: Application Support、complete protection、バックアップ除外、24時間保持、50MiB/100,000件/15分制限を実装。NDJSON追記を単一serial writerに集約し、終了時は一時JSON→atomic rename。強制終了で不完全な最後の行を捨てて回収。標準exportにUUID・広告内容・壁時計・緯度経度がないことを検査。

本人操作: ローカル保存先を選び、実ファイルをPCへ移動。Finderファイル共有を使う場合はエクスポート用Documentsだけを公開し、原記録のApplication Supportを公開しない。転送コピーは自動消去対象外と示す。

合格: D07〜D09。同じ実測JSONがPCで読み込める。JSON自体・画面写真・traceIdをGitHubやチャットに貼らず、件数・品質集計だけを報告する。

### T08 — E2E・電池・UX

改修: 失敗に関係する箇所のみ、`docs/validation`の合成結果と非機密集計。手順: 04のD10〜D12。屋外の短い安全な経路、屋内の位置不良、静止、前景/ロックを試す。実データの評価は本人管理環境で行う。電池は15分×2セッションを同条件の基準と比較する。手順を再実行できるよう端末一般名・OS・輝度・経過時間・結果を残す。

合格: 必須項目に未実施がないこと。実測粒が少ないこと自体をバグとせず、受信範囲の結果として扱う。本人が「また見たい」を満たさないならM1完成としない。

### T09 — 公開候補検査と引継ぎ

改修: check-public-data、README、検証記録。公開操作は実施しない。検査: allowlist外データ・シークレット・署名・実経路・private文書本文がないこと、合成fixtureが再生成一致すること、ネットワーク試験。`git diff`と`git status`で候補を見直す。commitする場合も別途与えられた実装指示の範囲を守る。

合格: 04のP01〜P06、06の完了審査。引継ぎは「実施／検証／未完／停止理由／次担当」の5項目を必ず分ける。

## 5. Macでのビルド手順と人の操作

XcodeとiOSの組合せは [公式対応表](https://developer.apple.com/xcode/system-requirements) をその時点で確認する。Windows/WSL2のSwiftだけでiOS SDK・署名・実機実行を完結させる計画にしない。

1. 本人がMacのXcodeを導入・起動し、必要コンポーネントと利用条件を確認する。今回購入や契約はしない。
2. Xcodeでprojectを作り、一般的なbundle ID（個人メールなどを含めない）を指定する。iOS 17を暫定deployment targetとし、実機OSが対応するか確認。
3. 本人がXcodeにApple Accountを追加し、Personal Teamを選択。秘密鍵・認証情報をrepoへ保存しない。
4. ケーブルでiPhoneを接続し、本人が「信頼」とDeveloper Modeの再起動・確認操作を行う。
5. Schemeを共有し、実機を選択してRun。Bluetooth等の権限を本人が選ぶ。
6. 以下はproject生成後にMac上で実行する。`DEVICE_ID`はローカルのみで取得し公開しない。

```bash
xcodebuild -version
xcodebuild -list -project apps/recorder-ios/SignalEchoes.xcodeproj
xcodebuild -showdestinations -project apps/recorder-ios/SignalEchoes.xcodeproj -scheme SignalEchoes
xcodebuild -project apps/recorder-ios/SignalEchoes.xcodeproj -scheme SignalEchoes -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
# 実機テスト先はXcodeで選択、または本人環境のDEVICE_IDを変数に設定後:
xcodebuild -project apps/recorder-ios/SignalEchoes.xcodeproj -scheme SignalEchoes -destination "id=${DEVICE_ID}" test
```

Simulatorのbuild成功はBLE実測成功ではない。Personal Teamは公式案内でprofile等に7日制約があり、期限後は再ビルド・再インストールが必要。TestFlight/App Store配布とは分ける。詳細は [05](05-open-questions.md)。

## 6. リスクによる分岐と再開情報

| 条件 | 続行できること | 保留すること／再開条件 |
| --- | --- | --- |
| Macなし | T00〜T04、合成試験、公開候補の検査 | T05〜T08。互換Mac＋本人操作が揃ったら再開 |
| BLEが疎い | 時系列・欠測・合成体験の完成 | 物理移動分類は追加しない。既知機器で原因を検証 |
| 屋内位置が不良 | 固定ステージ再生 | 実経路の再現。M2手動アンカー等を別検討 |
| 画面を点けた運用が不適 | 短時間作品として評価 | 終日利用。別端末等は新たな方針判断 |
| 有料Mac/Developer契約が必要 | 既存環境でできる工程 | 契約。具体費用と目的を整理して本人判断 |
| データ漏洩検査が失敗 | ローカル修正・再検査 | 公開候補化。実測やログを削除・分離して再審査 |

完了条件: M0は合成再生の自動検証＋本人評価、M1はそれに実機E2E・保持削除・転送・電池評価が加わる。文書完成、コード完成、実機成功、公開済を同じ意味にしない。今回の終了条件は文書7件の完成と整合検査であり、これらの実装工程は未実施。