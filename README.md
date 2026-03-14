# Logitech Precise Volume Roller for Mac

A small macOS utility that fixes the erratic volume control behavior of the **Logitech G915** (and potentially other Logitech keyboards with high-sensitivity volume rollers).

## 🚀 The Problem
On macOS, the Logitech G915 volume roller often scrolls much too fast or jumps erratically because it sends standard volume events that macOS interprets as full steps. This utility intercepts those events and converts them into precise "fine-grained" volume adjustments (equivalent to holding `Option + Shift + Volume Up/Down`).

## ✨ Features
- **Precise Control**: 1 scroll tick = 1/4 of a volume notch.
- **Direction Lock**: Prevents accidental volume jumps caused by mechanical encoder bounce.
- **Launch at Login**: Easily set the app to start automatically when you log in.
- **Stealth Mode**: Option to hide the menu bar icon for a completely background experience.
- **Small & Fast**: Written in pure Swift with minimal resource usage.

## 📦 Installation

### Option 1: Direct Download (Recommended)
1.  Go to the [Releases](https://github.com/Satanski/LogitechPreciseVolumeRollerForMac/releases) page.
2.  Download the latest `LogitechPreciseVolumeRoller.zip`.
3.  Unzip and move `LogitechPreciseVolumeRoller.app` to your `/Applications` folder.
4.  Open the app.

### Option 2: Build from Source
If you have Swift and Xcode installed:
```bash
git clone https://github.com/Satanski/LogitechPreciseVolumeRollerForMac.git
cd LogitechPreciseVolumeRollerForMac
./package.sh
```
Then move the generated `LogitechPreciseVolumeRoller.app` to your `/Applications` folder.

## 🛠 Permissions
This app requires **Accessibility** permissions to intercept and modify volume key events.

1.  When you first launch the app, macOS will ask for permission.
2.  Go to **System Settings** → **Privacy & Security** → **Accessibility**.
3.  Ensure **LogitechPreciseVolumeRoller** is enabled.
4.  If it doesn't work, try removing it from the list with the `-` button and adding it again manually.

## ⚙️ Configuration
The app runs in the Menu Bar. Click the icon to:
- Enable/Disable **Launch at Login**.
- **Hide Menu Bar Icon**: The app will continue running in the background. To show it again, simply launch the app again from `/Applications`.

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
