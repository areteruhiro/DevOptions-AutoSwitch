# DevOptions AutoSwitch

[免責事項 / Disclaimer](DISCLAIMER.md)

## 日本語

利用前に免責事項を確認してください。本モジュールの導入・使用は自己責任です。

SukiSU / KernelSU / Magiskに対応したサービスモジュールです。対象アプリへ
コードを読み込まず、LSPosedやZygiskも使用しません。

選択したアプリが起動またはフォアグラウンドへ移動すると、
`Settings.Global.development_settings_enabled`を一時的に`0`へ変更します。
別のアプリへ移動したときは元の値を正確に復元します。対象アプリの起動中は
USBデバッグも無効化し、終了時に復元します。ワイヤレスデバッグは初期設定では
変更しません。

### 現在の動作確認環境

2026年8月28日時点で、次の環境を使用して開発・動作確認しています。

- 端末: Xiaomi / Redmi XIG05
- Android: 15（API 35）
- CPU ABI: `arm64-v8a`
- Kernel: `5.10.209-android12-9-gf0826289c516`
- Root管理: SukiSU Ultra `v4.1.3`（versionCode `40837`）
- モジュール: DevOptions AutoSwitch `1.0`

これは動作確認済み環境の記録であり、同一環境または他の環境での動作を保証する
ものではありません。

### 対象アプリの選択

SukiSUまたはKernelSUでモジュールの**アクション**を押してください。
現在の対象が選択されたアプリ一覧が開きます。アプリを選択または解除し、
**Apply**を押すとすぐに反映されます。再起動は不要です。
画面右上で日本語とEnglishを切り替えられます。初回は端末言語を使用し、
選択した言語は次回も保持されます。

WebUIボタンからも同じ画面を開けます。モジュールWebUIに対応していない
管理アプリでは、アクション実行時に従来のターミナル表示へ切り替わります。

### 手動設定

設定ファイルはモジュール外に保存されます。

- `/data/adb/devmode-cloak/targets.txt`: 対象パッケージ名（1行に1つ）
- `/data/adb/devmode-cloak/config.conf`: ADB非表示などの設定
- `/data/adb/devmode-cloak/devmode-cloak.log`: 動作ログ

### 注意事項

- 対象アプリとAndroidの開発者向けオプション画面を分割表示しないでください。
- `HIDE_USB_ADB=1`が初期値のため、対象アプリの起動中はADB接続が切断されます。
- `HIDE_WIRELESS_ADB=1`にすると、ワイヤレスデバッグも一時的に無効化します。
- 本モジュールは開発者向けオプションの状態判定だけを対象とします。root、
  ブートローダーのアンロック、インストール済みアプリ、SUSFSなどは隠しません。

### ライセンス

本プロジェクトはGNU General Public License v3.0 or later
（`GPL-3.0-or-later`）で提供します。詳細は[LICENSE](LICENSE)を確認してください。

## English

Read the disclaimer before installation. You install and use this module at
your own risk.

DevOptions AutoSwitch is a service module for SukiSU, KernelSU, and Magisk. It does not
load code into target apps and does not require LSPosed or Zygisk.

When a selected app is launched or brought to the foreground, the module
temporarily sets `Settings.Global.development_settings_enabled` to `0`. The
exact previous value is restored when another app becomes active. USB ADB is
also disabled for target apps and restored on exit. Wireless debugging is left
unchanged by default.

### Current tested environment

Development and testing were performed in the following environment as of
August 28, 2026:

- Device: Xiaomi / Redmi XIG05
- Android: 15 (API 35)
- CPU ABI: `arm64-v8a`
- Kernel: `5.10.209-android12-9-gf0826289c516`
- Root manager: SukiSU Ultra `v4.1.3` (versionCode `40837`)
- Module: DevOptions AutoSwitch `1.0`

This records the tested environment and does not guarantee operation on the
same or any other environment.

### Select target apps

In SukiSU or KernelSU, tap **Action** on the module. Select or clear apps in the
app list, then tap **Apply**. Changes take effect immediately without a reboot.
Use the language selector in the upper-right corner to switch between Japanese
and English. The device language is used initially, and your choice is saved.
The same screen is available from the manager's WebUI button. Managers without
module WebUI support retain the terminal-style Action fallback.

### Manual configuration

- `/data/adb/devmode-cloak/targets.txt`: one target package name per line
- `/data/adb/devmode-cloak/config.conf`: optional ADB hiding settings
- `/data/adb/devmode-cloak/devmode-cloak.log`: runtime log


### Notes

- Do not use the Android Developer Options screen in split-screen with a target app.
- `HIDE_USB_ADB=1` is the default, so ADB disconnects while a target app is active.
- Set `HIDE_WIRELESS_ADB=1` to temporarily disable wireless debugging as well.
- This module only addresses Developer Options state checks. It does not hide
  root, an unlocked bootloader, installed packages, SUSFS, or other integrity signals.

### License

This project is licensed under the GNU General Public License v3.0 or later
(`GPL-3.0-or-later`). See [LICENSE](LICENSE) for the complete license text.
