# Install DeskSway / DeskSwayのインストール

## 日本語

この試験版はApple Silicon向けです。macOS 27.2で動作確認済みです。macOS 14以降をビルド対象としていますが、それ以外のOS・Intel Macでの動作は保証していません。

1. [GitHub Releases](https://github.com/Tasuku24/DeskSway/releases)で `DeskSway-<version>-macos-arm64.zip` をダウンロードします。GitHubが自動生成する「Source code」はビルド済みアプリではありません。
2. ZIPをダブルクリックして展開し、中の `DeskSway.app` を「アプリケーション」フォルダへ移動します。既存のDeskSwayが動いている場合は、先に終了してから置き換えてください。
3. 「アプリケーション」のDeskSwayを開きます。この無料配布版にはDeveloper ID署名・Appleの公証がありません。開発元を確認できない旨の警告で開けない場合、配布元を信頼できることを確認してから「システム設定 → プライバシーとセキュリティ」の「このまま開く」で、そのアプリの起動を許可します。管理者による制限などで許可できない場合もあります。[Appleの説明](https://support.apple.com/ja-jp/102445)
4. 起動後はメニューバーに常駐します。メニューの「設定…」を選ぶか、アプリをもう一度開いて設定画面を表示します。
5. 「権限」タブから、アクセシビリティ・入力監視を許可し、「キー送信を許可…」も操作します。「権限を再確認」を押し、必要なら「アプリを再起動」を選びます。3項目が認識済みになったことを確認します。起動許可と、これらの入力権限は別のものです。
6. 「一般」タブで、左右のショートカットをmacOSのSpace移動設定と同じ組み合わせで記録します。「左を記録」「右を記録」でマウスの横操作を登録し、待ち時間を調整して「保存」を押します。
7. BetterTouchToolが動いている場合は終了し、DeskSwayを「有効」にします。Mission Controlを開いて、左右の横操作を確認します。初回は一時停止状態で起動します。

表示言語は「一般 → 言語」で選択し、保存してアプリを再起動すると変わります。自動起動は設定されません。必要ならmacOSのログイン項目から追加してください。

アップデートでは、DeskSwayを終了してアプリを置き換えます。設定は通常保持されますが、この仮署名版では入力権限の再登録が必要になる場合があります。権限が認識されない場合は「アプリの場所を表示」で現在のアプリを確認し、該当するプライバシー設定の古いDeskSwayを削除してから現在のアプリを登録し直してください。

削除するにはDeskSwayを終了してアプリをゴミ箱へ移動し、必要に応じて自分で追加したログイン項目・権限登録を削除します。

## English

This preview is for Apple Silicon and has been checked on macOS 27.2. The build deployment target is macOS 14 or later; other OS versions and Intel Macs are not confirmed supported environments.

1. Download `DeskSway-<version>-macos-arm64.zip` from [GitHub Releases](https://github.com/Tasuku24/DeskSway/releases). GitHub's automatic “Source code” archives do not contain the built app.
2. Double-click the ZIP to extract it. Move `DeskSway.app` into Applications. Quit any running copy before replacing an older version.
3. Open DeskSway from Applications. This free distribution is ad-hoc signed, without Developer ID signing or Apple notarization. If macOS blocks it because the developer cannot be verified, confirm that you trust the download source, then use System Settings → Privacy & Security → Open Anyway to allow this app. Administrator policies can prevent this option. See [Apple's instructions](https://support.apple.com/en-us/102445).
4. DeskSway starts in the menu bar. Choose Settings… from its menu, or open the app again to show settings.
5. Open Permissions. Grant Accessibility and Input Monitoring, then click Allow Key Posting…. Use Check Permissions and, if necessary, Restart App. All three permissions must be recognized. These input permissions are separate from permission to launch the app.
6. In General, record the same left/right shortcuts configured for switching Spaces in macOS. Use Record Left and Record Right to register horizontal mouse input. Adjust the delay and click Save.
7. Quit BetterTouchTool if it is running, then enable DeskSway. Open Mission Control and try both directions. The first launch starts paused.

To change language, choose it in General, save, then restart the app. Startup at login is optional and can be configured using macOS Login Items.

For updates, quit DeskSway and replace the app. Settings normally persist, but ad-hoc builds can require granting permissions again. If permissions are not recognized, use Show App in Finder to locate the current app, remove the old DeskSway entry from the affected privacy setting, and add the current app again.

To uninstall, quit DeskSway, move it to Trash, and remove any permission or login-item entries you added.
