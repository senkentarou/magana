# Magana

**English** | [日本語](README.md)

Press and release the left ⌘ to switch to Latin input, the right ⌘ to switch to
Japanese. A menu bar app for US-layout Macs.

It switches only on a press that ends on its own, so ⌘C, ⌘-click, and a long
hold are unchanged.

There is no virtual keyboard driver and no configuration file. The only
permission it needs is Accessibility.

## Features

- 英数 or かな on each ⌘, swappable, either side can be disabled
- Per-application rules: pass ⌘ through untouched, or hold 英数 / かな while the application is frontmost
- Stops automatically while a JIS keyboard is connected
- Adjustable timeout separating a press from a hold
- Pause from the menu bar, launch at login, in-app updates

## Privacy

- Keys other than ⌘ register only as "a key was pressed". No key code, no character, nothing in the log
- The only network traffic is the update check and its download

## Requirements

macOS 14 Sonoma or later. Accessibility permission.

## Install

Download `Magana-<version>.zip` from
[Releases](https://github.com/senkentarou/magana/releases), extract it, and move
`Magana.app` to `/Applications`.

Magana asks for Accessibility on first launch. Enable it under **System Settings
› Privacy & Security › Accessibility** and it starts working.

## Build

```
make run     # build, sign, install to /Applications, launch
make check   # lint, build, test
```

## Architecture

| Target | Role |
|---|---|
| `MaganaCore` | The judgement. No AppKit, so `swift test` covers it |
| `Magana` | The SwiftUI / AppKit shell. Every call into the OS lives here |

## License

[GPL-3.0](LICENSE)
