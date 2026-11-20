# Signal Echoes M1 — iPhone Recorder

SwiftUI / CoreBluetooth / CoreLocation / CoreMotion でBLE受信と自己移動を記録し、既存M0ビューアで開けるSession V1 JSONとして書き出す前景専用アプリです。

## 機能
- BLE RSSIの1秒ビン集計、短命ID（最大120秒、30秒無観測で失効）
- 緯度経度はメモリ内だけで相対座標化し、保存は相対座標のみ
- 歩数・測位品質・権限/中断状況を保存。OS機器UUID、広告payload、位置の絶対座標、端末名は出力しない
- 最大15分、100,000件、50MiB、端末内24時間保持、手動削除と共有シート
- 画面を離れた場合は収集停止・中断扱い。常時バックグラウンド収集はしない

## ビルド
macOS + Xcode + XcodeGenで apps/recorder-ios/project.yml からプロジェクトを生成。Github Actions の iOS Recorder CI は署名不要のSimulator build/testを行う。

## TestFlight配布
配布側はApple Developer Programの有料会員資格とApp Store Connectのアプリ登録が必要。GitHub Actions TestFlight Upload (manual) は main 限定の手動起動で、環境 testflight の保護と以下のSecretsを要求する。

- APPLE_TEAM_ID と IOS_BUNDLE_ID
- APPLE_CERTIFICATE_P12_BASE64 と APPLE_CERTIFICATE_PASSWORD
- APPLE_PROFILE_BASE64
- APPSTORE_API_KEY_ID / APPSTORE_API_ISSUER_ID / APPSTORE_API_PRIVATE_KEY_BASE64

Secretsはチャットや公開レポジトリへ貼らない。Apple Distribution証明書(.p12)、App Store Connect配布プロファイル、App Store Connect API key(.p8)の実値を各Secretへ入れる。リポジトリがmainに統合された後、GitHubのActionsから手動アップロードし、App Store Connectで処理完了・テスター割当を確認する。

## iPhoneでの操作
アプリを開き、Bluetooth・位置・モーション許可を与えて記録開始。まず私有BLE機器で2分×3回測定し、その後15分以内の短距離歩行を記録。記録終了後、保存JSONをファイル共有してPCへ移動し、M0ビューアのローカルJSON読込で再生する。

## 注意
RSSIは送信源の方向・距離・実人数や同行関係を保証しない。実測JSONは公開しない。24時間の自動削除は起動時の期限削除であり、外部へ共有したコピーは対象外。署名・TestFlight・iPhone実機はApple側の準備後に検証する。