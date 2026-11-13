# DeskSway

[English](#english) | [日本語](#日本語)

## English

A small native macOS menu-bar app that turns horizontal wheel-style scrolling into Space shortcuts while Mission Control is detected. Swift, AppKit and public ApplicationServices APIs; no external packages, network service, analytics or updater. Optional launch at login uses macOS Service Management.

English and Japanese settings, directly recorded shortcuts and scroll directions, and a configurable repeat delay are included. On 2026-11-05, the maintainer reported that all real-device acceptance checks had passed in their environment. This does not establish compatibility with every Mac, mouse or macOS version. The [stage 1 report](docs/phase1-validation.ja.md) and [stage 2 report](docs/stage2-validation.ja.md) retain the earlier development evidence and its limits.

### Screenshots

![General settings with recorded shortcuts, horizontal scroll directions, repeat delay and language selection](docs/images/settings-general.jpg)

![Permissions settings showing separate Accessibility, Input Monitoring and Key Posting statuses](docs/images/settings-permissions.jpg)

Screenshots show one saved configuration; record the shortcuts and mouse directions that match your own setup.

### Install a release

Download the Apple Silicon app ZIP from [GitHub Releases](https://github.com/Tasuku24/DeskSway/releases), extract it, and move `DeskSway.app` into Applications. The automatic “Source code” archives do not contain a built app. See the [English and Japanese installation guide](docs/installation.md) for first-launch approval, input permissions, updates and removal.

Releases are free, ad-hoc signed downloads without Developer ID signing or Apple notarization. macOS may require explicit first-launch approval. The recorded test environment is macOS 27.2 on Apple Silicon; the deployment target of macOS 14 does not guarantee compatibility with other OS versions or Intel Macs.

### Build and run

The current build was checked with Xcode 27.2 / Swift 6.4.2 on macOS 27.2, arm64. The package's deployment floor is macOS 14; that is **not** a compatibility claim for older OS versions or Intel. Detection relies on undocumented system UI structure and is currently only validated on macOS 27.2 with one display.

```sh
swift test
./scripts/build-app.sh
open .build/DeskSway.app
```

The script creates `.build/DeskSway.app` with a local ad-hoc signature, without personal signing information. It is not Developer ID signed or notarized. Rebuilding may require regranting app permissions. Keep the app at a stable location when testing permissions; if you move it to Applications, quit the previous copy first. Only run one copy at a time.

Building from source does not require a paid Apple Developer Program membership. A downloaded prebuilt app without Developer ID signing and notarization may be blocked by macOS. If you trust its source, follow [Apple's instructions for opening an app from an unidentified developer](https://support.apple.com/en-us/102445). Accessibility, Input Monitoring and key-posting permissions are still required separately.

### First use

1. Launch DeskSway to add it to the menu bar. Open the app again, or choose **Settings…** from its menu, to show settings on the current Space. The header shows whether DeskSway is enabled and what Mission Control state it detects. **Command-W** closes settings and **Command-Q** quits while the app is focused. Unsaved changes require confirmation before closing or quitting.
2. Open **Permissions**. Check the separate Accessibility, Input Monitoring and Key Posting statuses. Use **Open System Settings…** for Accessibility/Input Monitoring and **Allow Key Posting…** for the dedicated event-posting request. **Check Permissions**, **Restart App**, and **Show App in Finder** are on this tab. Only a user-initiated permission action requests access. Screen Recording is not used.
3. Open **General**. Click the shortcut button for each direction, then physically press and release the shortcut configured for macOS “Move left/right a space.” This records the shortcut without changing system settings. Modifier-only input is ignored; unsupported/bare keys and duplicate left/right shortcuts are rejected.
4. Click **Record Left** and **Record Right**, operating the actual mouse horizontally in each desired direction. Keep the pointer over settings. The received sign and wheel/gesture format are shown beside each button. Both directions must be opposite signs of the same format. Vertical-dominant and momentum input do not register. Conversion continues while settings is open and pauses only during explicit input recording.
5. Under **Repeated Input**, adjust **Delay between inputs** from 0.00–2.00 seconds in 0.05-second steps (default 0.60). Zero accepts every eligible event without a waiting interval. **Restore Default** restores 0.60 seconds. Under **Language**, choose **Follow System Settings**, Japanese or English; language changes require saving and restarting.
6. Click **Save** (Command-S) to apply shortcuts, scroll mapping and repeat delay together while leaving settings open. Unsaved edits do not affect conversion. **Discard Changes** closes settings without saving the draft. Quit BetterTouchTool before enabling DeskSway, then use the header switch or **Resume** in the menu. Pause or quit DeskSway before restoring BetterTouchTool.

**Permission troubleshooting:** Key posting uses `CGRequestPostEventAccess`; requesting Accessibility alone is not a substitute for that request. If Accessibility and Input Monitoring are recognized but key posting is not, use **Allow Key Posting…** and follow macOS’s instructions, then recheck/restart if needed. An enabled switch in System Settings does not guarantee that the current binary is authorized. During this trial, macOS explicitly logged a code-requirement mismatch between a previous DeskSway grant and the rebuilt ad-hoc binary. If the app still reports missing permission, remove the old DeskSway entry from the affected privacy list, add the current app shown by **Show App in Finder**, grant access, then restart. Do this yourself in System Settings; DeskSway never changes TCC records or bypasses authorization. Ad-hoc rebuilds can require repeating this step. A stable certificate-backed signing setup is not included in this local trial.

The run/pause choice and shortcuts are saved locally in standard Preferences under `local.DeskSway`. Settings are never written to the repository. Opening settings does not stop conversion; unsaved changes require confirmation before closing. On later launches the prior run preference is restored, but conversion still waits for all readiness conditions. Use **General → Launch at login** to enable or disable automatic startup. This switch applies immediately without Save, independently of shortcut edits. It reflects the macOS login-item status; if approval is required, use **Open Login Items…** to allow DeskSway in System Settings. No login item is registered until you enable the switch. Run the signed `.app` bundle from a stable location such as Applications; a bare `swift run` executable cannot register as the app.

### Input protection and limits

- Runtime conversion taps scroll events only. Explicit shortcut recording temporarily taps key down/up in the foreground settings window; it stores one key code and modifier set, never text. Input waiting times out after 15 seconds and focus loss cancels new recording. Cancellation drains only already-swallowed keys until release, including their repeats, before removing the tap; unrelated keys pass through and are not recorded. Restart/quit waits for these held keys to be released. Clicks and middle-button actions are untouched. Generated events are one configured key-down/up pair.
- Conversion requires running state, valid settings, Accessibility, listen/post access, an enabled tap, and a Mission Control observation no more than 500 ms old. All other states pass input through, including App Exposé, unknown, stale detection, pause and missing permissions.
- AX reads run on a separate serial queue with a 200 ms polling target, a 150 ms timeout on **each** AX element, depth 4 and 200-node limits per host. Observation age starts before the scan, not at completion. Sleep/session and relevant process changes invalidate pending results. Multiple AX calls can exceed the poll interval. There is an unavoidable observation window after MC closes; 500 ms is a freshness bound, not a measured detection delay.
- Eligible horizontal input can repeat within the same wheel burst or recorded gesture after the configured waiting time (0.00–2.00 seconds, default 0.60). The interval is measured from the last generated shortcut, so intervening input does not extend it. During the wait only matched horizontal components are suppressed. Each movement needs a new actual input event: there is no repeat timer, queued movement or catch-up after silence. Zero input and momentum never cause another movement.
- Detection/permission loss still interrupts the stream. A wheel stream needs 250 ms without horizontal input before it can resume; a recorded gesture needs a new begin event. This safety reset is separate from the normal repeat interval.
- Vertical-dominant input passes intact. Mixed horizontal-dominant input retains all vertical and third-axis fields while only horizontal fields are cleared. Failures to prepare replacement/key events leave the original event intact. The public posting API provides no acknowledgement that macOS acted on a shortcut.
- **Public CGEvents do not authenticate a physical device.** Defaults accept phase-less wheel-style events, including continuous ones from some mouse smoothers. Recording a phase-bearing input explicitly enables that gesture format. The same format from a trackpad cannot be distinguished from the recorded mouse; momentum always passes without generating a shortcut. A smoother that drops gesture/momentum metadata cannot be reliably distinguished from a new wheel burst. The maintainer reports successful real-device acceptance in their setup; other mouse/smoother combinations are not guaranteed. Do not treat this as an absolute hardware-mouse filter.
- A disabled tap clears detection and is retried with permissions checked, at most every two seconds. Missing permissions can require an app restart. Permission behavior and multi-display compatibility can differ between environments.

### Development and removal

`Sources/DeskSwayCore` owns input policy, shortcut validation, CGEvent preparation and the shared AX reader. `Sources/DeskSway` owns the unified settings, short-lived recorder, main-thread menu, runtime event tap and lifecycle; AX IPC runs separately. The [read-only probe](probes/mission-control/README.md) uses the same reader but does not link the input adapter or install a tap. Tests construct events but never post them.

To remove the app, turn off **Launch at login** in General, quit it and remove the built `.app`. Remove any permission or login-item entries you added through System Settings. Preferences may be retained; deleting the `local.DeskSway` preferences domain separately resets local settings. No separate background helper or launch agent is installed.

Source is maintained in [Tasuku24/DeskSway](https://github.com/Tasuku24/DeskSway) under the [MIT License](LICENSE). Local ad-hoc builds are not Developer ID-signed or notarized distributions.

### Prepare a release

Run the checks and package an app separately from the local test copy:

```sh
swift test
./scripts/package-release.sh 0.2.0-beta.1
```

The packaging script creates an app ZIP and a matching SHA-256 checksum under `.build/releases/`. The ZIP includes the app, MIT license and bilingual installation guide. It does not overwrite an existing asset or register/replace the running local app. Run it on Apple Silicon for the initial arm64 release. Version labels must match `CFBundleShortVersionString` in `Resources/Info.plist`, optionally with a prerelease suffix.

For this preview, create a draft GitHub Release for tag `v0.2.0-beta.1` at the verified commit, use the [release notes](docs/releases/v0.2.0-beta.1.md), and attach the ZIP and checksum. Mark it as a prerelease, then publish after verifying the uploaded assets.

## 日本語

DeskSwayは、Mission Controlの表示を検知したときに、ホイール形式の横スクロールをSpace移動のショートカットへ変換する、小さなmacOSメニューバーアプリです。Swift・AppKit・公開ApplicationServices APIを使用し、外部パッケージ・ネットワークサービス・解析機能・自動更新機能はありません。任意のログイン時自動起動にはmacOSのService Managementを使用します。

英語・日本語の設定画面、ショートカットとスクロール方向の直接記録、連続入力の待ち時間調整に対応しています。2026年11月5日、開発者は自身の環境ですべての実機受け入れ確認に合格したと報告しています。すべてのMac・マウス・macOSでの互換性を示すものではありません。初期の検証結果と制限は[第1段階の報告](docs/phase1-validation.ja.md)と[第2段階の報告](docs/stage2-validation.ja.md)に記録しています。

### スクリーンショット

![ショートカット・横スクロール方向・待ち時間・言語選択を表示した一般設定](docs/images/settings-general.jpg)

![アクセシビリティ・入力監視・キー送信の状態を個別に表示した権限設定](docs/images/settings-permissions.jpg)

画像は保存済み設定の一例です。ご自身の環境に合うショートカットとマウスの入力方向を記録してください。

### 配布版のインストール

[GitHub Releases](https://github.com/Tasuku24/DeskSway/releases)からApple Silicon向けのアプリZIPをダウンロードして展開し、`DeskSway.app` を「アプリケーション」に移動してください。自動生成される「Source code」にはビルド済みアプリは含まれません。初回起動の許可・入力権限・更新・削除については[英語・日本語のインストール手順](docs/installation.md)を参照してください。

配布版は無料で、仮署名（ad-hoc署名）されています。Developer ID署名・Appleの公証はなく、macOSで初回起動の明示的な許可が必要になる場合があります。記録された検証環境はApple SiliconのmacOS 27.2です。macOS 14をビルド対象の下限としていますが、ほかのOSやIntel Macでの互換性を保証するものではありません。

### ビルドと起動

現在のビルドはXcode 27.2・Swift 6.4.2・macOS 27.2・arm64の環境で確認しています。macOS 14をビルド対象の下限としていますが、古いOSやIntel Macでの互換性を示すものではありません。検知には文書化されていないシステムUIの構造を利用しており、現在の検証対象はmacOS 27.2・ディスプレイ1台の環境です。

```sh
swift test
./scripts/build-app.sh
open .build/DeskSway.app
```

このスクリプトは、個人の署名情報を使わない仮署名付きの `.build/DeskSway.app` を作成します。Developer ID署名・公証はありません。再ビルド後は入力権限の再付与が必要になる場合があります。権限を確認するときはアプリの保存場所を固定し、「アプリケーション」へ移動する場合は先に以前のコピーを終了してください。同時に複数のコピーを起動しないでください。

ソースからのビルドに有料のApple Developer Programへの加入は不要です。Developer ID署名・公証のない配布アプリはmacOSにブロックされる場合があります。配布元を信頼できる場合は、[Appleの手順](https://support.apple.com/ja-jp/102445)に従って開いてください。アクセシビリティ・入力監視・キー送信の権限は、それぞれ別に必要です。

### 初期設定

1. DeskSwayを起動するとメニューバーに常駐します。アプリをもう一度開くか、メニューの「設定…」を選ぶと、現在のSpaceに設定画面が表示されます。上部には有効状態とMission Controlの検知状態が表示されます。アプリにフォーカスがあるときは **Command-W** で設定画面を閉じ、**Command-Q** で終了できます。未保存の変更がある場合は確認が表示されます。
2. 「権限」を開き、アクセシビリティ・入力監視・キー送信の状態を個別に確認します。アクセシビリティと入力監視は「システム設定を開く…」、キー送信は専用の「キー送信を許可…」を使います。「権限を再確認」「アプリを再起動」「アプリの場所を表示」もこのタブにあります。権限要求はユーザーが操作したときだけ行います。画面収録の権限は使いません。
3. 「一般」を開き、左右それぞれのショートカットボタンを押して、macOSの「操作スペースを左／右に移動」で設定したキーを実際に押して離します。macOSの設定は変更しません。修飾キーだけの入力は無視し、非対応キー・修飾キーのない入力・左右で同じショートカットは登録できません。
4. 「左を記録」「右を記録」を押し、マウスを実際に横方向へ操作します。ポインターは設定画面上に置いてください。受信した符号とホイール／ジェスチャーの形式が各ボタンの横に表示されます。左右は同じ入力形式で、逆の符号である必要があります。縦方向が優勢な入力と慣性入力は登録しません。設定画面を開いている間も変換は続き、明示的に入力を記録している間だけ一時停止します。
5. 「連続入力」の「次の入力までの待ち時間」を0.00〜2.00秒の範囲で、0.05秒刻みで調整します。初期値は0.60秒で、0秒では対象となる各イベントを待ち時間なしで受け付けます。「標準に戻す」で0.60秒に戻ります。「言語」では「システム設定に従う」「日本語」「English」を選べます。言語変更の反映には保存とアプリの再起動が必要です。
6. 「保存」（Command-S）でショートカット・スクロール方向・待ち時間をまとめて反映します。設定画面は開いたままになります。未保存の変更は変換に影響しません。「変更を破棄」は下書きを保存せずに画面を閉じます。DeskSwayを有効にする前にBetterTouchToolを終了し、上部のスイッチかメニューの「実行」で有効にしてください。BetterTouchToolを再開する前にDeskSwayを一時停止または終了してください。

**権限が認識されない場合：** キー送信には `CGRequestPostEventAccess` を使用します。アクセシビリティの要求だけでは代わりになりません。アクセシビリティと入力監視が認識済みでもキー送信が認識されない場合は「キー送信を許可…」を操作し、macOSの案内に従ってから再確認・再起動してください。システム設定でスイッチがオンでも、現在のバイナリが許可されているとは限りません。この試行では、以前に許可したDeskSwayと再ビルドした仮署名バイナリのコード要件が一致しない旨のログが記録されました。権限が認識されない場合は、該当するプライバシー設定の古いDeskSwayを削除し、「アプリの場所を表示」で確認した現在のアプリを追加して許可し、再起動してください。システム設定でご自身で操作してください。DeskSwayはTCCの記録を変更したり、許可を回避したりしません。仮署名での再ビルド後には、この手順が再び必要になる場合があります。この試行には、証明書を使った安定した署名環境は含まれていません。

実行／一時停止の選択とショートカットは、標準のPreferencesの `local.DeskSway` にローカル保存します。設定をリポジトリへ書き込むことはありません。設定画面を開いても変換は停止せず、未保存の変更を残して閉じる場合は確認します。次回以降の起動では前回の実行状態を復元しますが、すべての動作条件がそろうまで変換を開始しません。

「一般 → ログイン時に起動」で自動起動のオン・オフを切り替えられます。このスイッチはショートカットの編集中でも独立して動作し、保存不要で即時反映されます。macOSが管理するログイン項目の状態を表示し、承認が必要な場合は「ログイン項目を開く…」からシステム設定で許可できます。スイッチをオンにするまで自動登録はしません。「アプリケーション」など固定した場所にある署名付きの `.app` を実行してください。`swift run` の実行ファイル単体では、アプリとして登録できません。

### 入力の保護と制限

- 通常の変換処理で監視するのはスクロールイベントだけです。ショートカットの明示的な記録時だけ、最前面の設定画面でキーの押下・解放を一時的に監視し、1つのキーコードと修飾キーの組み合わせを保存します。文字列は保存しません。入力待ちは15秒で終了し、フォーカスが外れると新しい記録を中止します。中止時は、すでに取り込んだキーの解放まで、そのリピートも含めて処理してから監視を解除します。無関係なキーは通過させ、記録しません。再起動・終了は取り込んだキーの解放を待ちます。クリックや中ボタン操作は変更しません。生成するのは設定されたキーの押下・解放1組です。
- 変換には実行状態・有効な設定・アクセシビリティ・入力監視とキー送信の許可・有効なイベント監視・取得から500 ms以内のMission Control検知結果が必要です。App Exposé・不明な状態・古い検知・一時停止・権限不足など、それ以外の場合は入力を通過させます。
- AXの読み取りは専用の直列キューで実行し、ポーリング目標は200 ms、タイムアウトはAX要素ごとに150 msです。探索は深さ4、対象ホストごとに200ノードまでです。検知結果の経過時間は走査完了時でなく開始前から測定します。スリープ・セッション変更・関連プロセスの変更で処理中の結果を無効化します。複数のAX呼び出しによりポーリング間隔を超える場合があります。Mission Controlを閉じてから検知が更新されるまでの観測のずれは避けられません。500 msは結果の鮮度の上限であり、実測した検知遅延ではありません。
- 対象となる横入力は、設定した待ち時間の後であれば、同じホイールの連続操作や記録済みのジェスチャー内でも繰り返せます。待ち時間は0.00〜2.00秒、初期値は0.60秒です。最後に生成したショートカットから測定するため、途中の入力によって待ち時間は延びません。待機中は一致する横成分だけを抑制します。移動には毎回新しい実際の入力イベントが必要です。リピート用タイマー・移動のキュー・無入力後のまとめ実行はありません。ゼロ入力や慣性入力で追加移動は発生しません。
- 検知や権限が失われると、入力の連続処理を中断します。ホイール入力は横入力が250 ms途切れるまで再開せず、記録済みのジェスチャー入力には新しい開始イベントが必要です。この安全のためのリセットは、通常の待ち時間とは別です。
- 縦方向が優勢な入力はそのまま通過させます。横方向が優勢な混合入力では、縦方向・第3軸の情報をすべて残し、横方向の情報だけを消去します。置換イベントやキーイベントの準備に失敗した場合は元のイベントをそのまま残します。公開のキー送信APIからは、macOSがショートカットを実行したかの確認応答は得られません。
- **公開CGEventでは物理デバイスを認証できません。** 初期設定ではフェーズ情報のないホイール形式のイベントを受け付け、一部のマウス平滑化ソフトが生成する連続イベントも含まれます。フェーズ付き入力を記録すると、そのジェスチャー形式を明示的に有効化します。同じ形式のトラックパッド入力と記録したマウス入力を区別することはできません。慣性入力は常に通過させ、ショートカットを生成しません。平滑化ソフトがジェスチャー・慣性の情報を除去した場合、新しいホイール操作と確実に区別することはできません。開発者の環境では実機確認に成功していますが、ほかのマウスや平滑化ソフトとの組み合わせは保証していません。物理マウスだけを完全に識別する機能とは扱わないでください。
- イベント監視が無効化されると検知結果を消去し、権限を確認しながら2秒に1回以下の頻度で再試行します。権限不足の場合はアプリの再起動が必要になることがあります。権限の挙動や複数ディスプレイでの互換性は環境によって異なる場合があります。

### 開発と削除

`Sources/DeskSwayCore` は入力ポリシー・ショートカット検証・CGEventの準備・共通のAX読み取りを担当します。`Sources/DeskSway` は設定画面・一時的な入力記録・メインスレッドのメニュー・実行時のイベント監視・ライフサイクルを担当し、AXのプロセス間通信は別に実行します。[読み取り専用のプローブ](probes/mission-control/README.md)も共通の読み取り処理を使いますが、入力アダプターのリンクやイベント監視の導入はしません。テストではイベントを作成しますが、送信はしません。

削除するには「一般」で「ログイン時に起動」をオフにし、アプリを終了して `.app` を削除してください。システム設定で追加した権限やログイン項目も削除します。Preferencesは残る場合があります。ローカル設定をリセットするには `local.DeskSway` のPreferencesドメインを別途削除します。独立したバックグラウンドヘルパーやLaunchAgentは導入しません。

ソースは[Tasuku24/DeskSway](https://github.com/Tasuku24/DeskSway)で管理し、[MITライセンス](LICENSE)で公開しています。ローカルの仮署名ビルドにはDeveloper ID署名・Appleの公証はありません。

### リリースの準備

チェックを実行し、ローカルで使用するアプリとは別に配布物を作成します。

```sh
swift test
./scripts/package-release.sh 0.2.0-beta.1
```

パッケージ作成スクリプトは `.build/releases/` にアプリのZIPと対応するSHA-256チェックサムを作成します。ZIPにはアプリ・MITライセンス・英語と日本語のインストール手順が含まれます。既存の配布物の上書きや、起動中のアプリの登録・置き換えはしません。最初のarm64向け配布物はApple Siliconで作成してください。バージョンは `Resources/Info.plist` の `CFBundleShortVersionString` と一致する必要があり、試験版などの接尾辞を追加できます。

この試験版では、検証済みコミットを対象にタグ `v0.2.0-beta.1` のGitHub Releaseを下書きで作成し、[リリース説明](docs/releases/v0.2.0-beta.1.md)を設定してZIPとチェックサムを添付します。試験版に指定し、添付ファイルを検証してから公開します。
