# Signal Echoes

移動中に受信できたBluetooth Low Energy（BLE）の信号を、光点と軌跡で振り返るローカルな可視化プロジェクトです。暗い空間に信号の気配が現れ、受信強度や継続時間によって明るさや尾が変わります。自分視点・俯瞰・自由視点で、短い移動区間を再生する体験を目指します。

**光点は人や機器の実際の位置を示しません。光点の数は人数ではありません。** 単一スマートフォンのRSSIだけでは、送信源の方向・距離・移動速度・同行関係は確定できません。観測した値と、見せるために作る位置・動きを分離します。

## ステータス

2026-11-20現在、Web側のM0合成再生デモをfeatureブランチで実装・自動検証しています。iPhoneの実機収集、精度、電池消費、本人の体験評価は未検証です。本成果は合成データの試作であり、実測対応アプリや配布物ではありません。

最初にWindows/WSL2とPCブラウザで合成データの3D再生を作り、その後、利用可能なMac・Xcode・iPhoneで短時間の記録を検証する予定です。iOSのビルド・署名・実機実行をWindowsだけで完結できるとは想定していません。実機への導入には本人の端末操作が必要です。

## 想定する体験

- 合成データですぐに試せる3Dデモ。
- 自分の軌跡と、受信した短期信号の光点。
- 再生・停止・シーク・速度変更と3つの視点。
- 受信欠測や位置の不確かさを隠さない表示。
- ファイルをPC内で開くローカル再生。

実測MVPは最大15分の前景セッションを想定します。画面ロックやアプリ切替では一時停止し、終日・背景・ポケット内での連続記録は保証しません。カメラ撮影、第三者の識別、長期追跡は目的に含めません。

## データの扱い

Publicリポジトリに含めるデータは、独立生成した合成データだけです。実測のBLEログ、仮IDの観測列、本人の移動履歴、署名情報、シークレットを公開しません。ローカル座標や短期仮IDに変えても、実測データが公開可能になるわけではありません。

記録アプリは元のBLE識別子や広告内容を保存せず、短時間の仮IDと最小限の観測を使う設計です。クラウド送信や同期はMVPに含めません。実測ファイルはソースコードのcheckout外で管理します。

## 設計文書

| 文書 | 内容 |
| --- | --- |
| [プロダクト仕様](01-product-spec.md) | 目的、非目的、体験、データ最小化、評価指標 |
| [技術設計](02-technical-design.md) | API、保存スキーマ、合成JSON、観測と演出の分離 |
| [実装ロードマップ](03-implementation-roadmap.md) | ディレクトリ、開始コマンド、順序付き作業、外部操作 |
| [試験・受入計画](04-test-and-acceptance.md) | 合成・実機・性能・プライバシー・UXの合格条件 |
| [未確認事項](05-open-questions.md) | 設計判断、実機の確認事項、Windows中心のビルド経路 |
| [引継ぎ監査](06-handoff-audit.md) | 文書検査と未検証事項、後続実装の完了判定 |

次の実装項目は、データ契約と合成fixture、光点の最小再生、時間操作と3視点です。詳しい開始手順は実装ロードマップにあります。featureブランチには起動可能なM0 Webデモが含まれます。

## 技術的な根拠

BLEの受信条件・背景制約は [AppleのスキャンAPI](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/scanforperipherals%28withservices%3Aoptions%3A%29) と [Core Bluetoothの背景処理ガイド](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)、iOS開発環境は [Xcodeの対応表](https://developer.apple.com/xcode/system-requirements) を参照しています。確認日: 2026-11-20。具体的な端末での成立性は今後の実機試験で確認します。

公開・配布・ライセンスの方針は今後決定します。公開リポジトリであること自体を、実測データの公開やアプリ配布の許可とは扱いません。
## M0 合成デモの起動（featureブランチ）

Node.js 24・npmが使えるWindows/WSL2またはLinux PCで、リポジトリのルートから実行します。

```bash
npm ci
npm run fixtures
npm run typecheck
npm test
npm run build
npm run check:public-data
npm run dev
```

表示先: `http://127.0.0.1:5173/`。外部ホスティングや新規アカウントは不要です。俯瞰・自分視点・自由視点、再生・シーク、6つの合成シナリオ、ローカルJSONインポートを備えています。スクリーンショットは `docs/validation/` 以下の合成データのみを使用しています。

Chrome/Chromiumによる操作スモークテスト: `npx tsx scripts/smoke-test.ts`（`/usr/bin/chromium`があるLinux環境の例）。GUI/動画品質は本人が確認して評価します。現段階でiPhoneのBluetoothを収集する機能はありません。
