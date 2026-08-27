# Changelog

## 1.0

- Added a SukiSU / KernelSU WebUI for selecting target apps.
- Added search by app label and package name.
- Added atomic Apply-based target list updates without a reboot.
- Added automatic Japanese and English localization with a saved language selector.
- Preserved the existing target list when updating the module.
- Kept app-process injection, LSPosed, and Zygisk out of the implementation.

## Release notice / リリースに関する注意

本ソフトウェアは無保証で提供され、導入・使用は自己責任です。対象アプリの
起動中はADBが切断される場合があります。導入前にバックアップと復旧手段を
準備し、[免責事項](DISCLAIMER.md)を確認してください。

This software is provided without warranty and is used at your own risk. ADB
may disconnect while a selected app is active. Prepare backups and a recovery
method before installation, and read the [disclaimer](DISCLAIMER.md).
