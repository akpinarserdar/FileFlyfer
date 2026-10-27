# FileFlyfer

[Türkçe](README.md) | **English**

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) [![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](#requirements)

FileFlyfer is a free, open-source macOS app for managing shared Android storage over USB and wireless ADB. It brings wired and Wi-Fi devices together in one workspace, needs no companion app on your phone, and does not require root access.

## Features

- Connect multiple USB and Wi-Fi ADB devices at once, manage them from one list, and switch between phones quickly
- Pair Android 11+ phones over Wi-Fi with a QR code, with manual IP/port and pairing-code options
- View the device model, name, and Android version
- Browse folders under `/sdcard`, follow the current path, and favorite folders
- View file names, types, sizes, and modification dates
- Transfer single or multiple files between Mac and phone, with drag and drop
- Keep every transfer pinned to its target phone, even when switching devices
- Cancel an in-progress transfer
- Create folders, rename files or folders, and delete them with confirmation
- Resolve name conflicts by overwriting, skipping, or choosing a new name
- Safely handle Unicode file names

ADB does not provide a reliable percentage, so the app does not show a fabricated transfer percentage.

## Requirements

- macOS 13 or later
- Xcode 15 or later (to run the Xcode project)
- Swift 6 toolchain (to build with Swift Package Manager)
- `adb` from Android SDK Platform-Tools
- An Android device with USB or wireless debugging enabled and its screen unlocked

Install ADB through Android Studio's SDK Manager or the Android SDK Platform-Tools package. The app searches `ADB_PATH`, common Homebrew locations, and `~/Library/Android/sdk/platform-tools/adb`. Set `ADB_PATH` if ADB is installed elsewhere.

## Download and run

On GitHub, choose **Code → Download ZIP** to download the source, or copy the HTTPS URL from the **Code** menu:

```sh
git clone https://github.com/akpinarserdar/FileFlyfer.git
cd FileFlyfer
```

Open the Xcode project, select the `FileFlyfer` scheme, and click **Run**:

```sh
open FileFlyferXcode/FileFlyferXcode.xcodeproj
```

Xcode may ask you to configure local signing the first time you run the project. If the phone is not detected, install Platform-Tools as described above.

## Build from the command line

With Swift 6 installed, run these commands from the project directory:

```sh
swift build
swift run FileFlyfer
```

Run the tests with:

```sh
swift test
```

If ADB is not in a standard location:

```sh
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb" swift run FileFlyfer
```

## Connect an Android phone over USB

1. Open **Settings → About phone**.
2. Tap **Build number** seven times to enable developer options.
3. Turn on **Developer options → USB debugging**.
4. Connect the phone to your Mac with a USB data cable.
5. Unlock the phone and approve the RSA debugging prompt.

If the phone does not appear, check the connection with `adb devices -l`. If the device shows as `unauthorized`, approve the RSA prompt on the phone.

## Connect an Android phone over Wi-Fi

Android 11 or later and Android SDK Platform-Tools are required. Turn on **Developer options → Wireless debugging** on the phone and connect the Mac and phone to the same Wi-Fi network. In FileFlyfer, click **Kablosuz Bağlan**. For the first pairing, open **Pair device with QR code** on the phone, scan the QR shown by FileFlyfer, and click **Taranınca otomatik bağlan**. FileFlyfer discovers the ADB mDNS service, pairs, and connects. Allow local network access if macOS asks. If QR pairing is unavailable, use the manual pairing code and IP/port fields.

## ADB and privacy

The ADB binary is not included in this source repository. Each user installs Android SDK Platform-Tools on their own computer and follows its license terms. The app runs ADB locally and transfers files over USB or the local Wi-Fi network.

On the Mac, the app invokes ADB with an executable path and separate arguments rather than concatenating shell commands. Some operations on the phone require remote shell commands; file names are passed safely, and operations are limited to shared storage.

## Known limitations

- Wireless ADB requires Android 11 or later; MTP, iOS, root access, cloud storage, and syncing are not supported.
- Folder downloads are not supported yet; select individual files to download.
- Some Android vendor builds may not include the `stat` or `base64` commands used to read file details.
- Transfer progress is indeterminate because ADB does not provide a reliable percentage.

## Contributing

Use GitHub Issues to report bugs or suggest features. Before submitting a change, run `swift test` and `swift build`, then describe the change in your pull request. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

FileFlyfer is released under the [MIT License](LICENSE). Android SDK Platform-Tools is a separate Google product and is subject to its own license terms.
