# MemPulse

A colored dot in the macOS menu bar that shows the system's **memory pressure**,
using the same traffic-light scale as Activity Monitor:

| Dot | Pressure | What it means |
|:---:|----------|---------------|
| 🟢 | Normal   | Plenty of memory available. |
| 🟡 | Elevated | macOS is compressing memory and starting to swap. |
| 🔴 | Critical | Heavy swapping: quit something. You also get a notification. |

Open the menu to see:

- Swap used, RAM used and compressed RAM.
- The **top 5 apps by memory**, with all of each app's processes added up
  (Chrome counts its *Helpers* and *Renderers* together, not one by one).
- A **Quit** button for each app. Hold **⌥ Option** while clicking it to force quit.
- A toggle to launch MemPulse at login.

Built to spare your SSD from unnecessary swap, without opening Activity Monitor.

## Requirements

- macOS 14 (Sonoma) or later.
- Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) to build.

## Installation

```sh
brew install xcodegen
git clone https://github.com/rich-97/macos-mem-pulse.git
cd macos-mem-pulse
xcodegen generate
xcodebuild -scheme MemPulse -configuration Release -destination 'platform=macOS' build
```

The app ends up at
`~/Library/Developer/Xcode/DerivedData/MemPulse-*/Build/Products/Release/MemPulse.app`.
Copy it to `/Applications` and open it. Or open `MemPulse.xcodeproj` in Xcode and
press ⌘R.

On first launch macOS asks for permission to send notifications. MemPulse only
sends one when pressure becomes critical.

## How it works

| Data | Source |
|------|--------|
| Dot color | `DispatchSource.makeMemoryPressureSource`: the kernel pushes changes, no polling. On launch the current level is read with `sysctl kern.memorystatus_vm_pressure_level`. |
| Swap | `sysctl vm.swapusage` |
| RAM | `host_statistics64` (`HOST_VM_INFO64`) |
| Top apps | `/bin/ps -axo pid=,rss=,comm=` every 5 s, grouped by the enclosing `.app` |

No third-party dependencies. No App Sandbox, because it runs `/bin/ps`.

## Development

`project.yml` is the source of truth; the `.xcodeproj` is generated and not
checked in. Run `xcodegen generate` again after adding or removing files.

```sh
xcodebuild test -scheme MemPulse -destination 'platform=macOS'
```

To see the colors without actually filling up RAM:

```sh
sudo memory_pressure -l warn     -S -s 15   # → yellow
sudo memory_pressure -l critical -S -s 15   # → red + notification
```

The dot goes back to green when it finishes.

## License

[MIT](LICENSE)
