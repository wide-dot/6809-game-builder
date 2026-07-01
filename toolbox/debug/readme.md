# wddebug

## Description
Debug GUI for DCMOTO and Teo emulators.

wddebug does not emulate anything: it attaches to a **running** emulator process,
locates the emulated Thomson RAM by scanning for the TO8 boot-logo signature, and
reads it live to drive the ImGui debug views (memory map, sprites, palette, watches…).

## Platform support
The memory-access backend is abstracted behind `debug.os.NativeProcess`:

| Platform | Backend | Native API |
|----------|---------|------------|
| Windows  | `WindowsProcess` | Toolhelp32 + `ReadProcessMemory` |
| macOS    | `MacProcess`     | `task_for_pid` + `mach_vm_read_overwrite` |

The correct backend is selected at runtime (`com.sun.jna.Platform`).

## Build
```
mvn -pl toolbox/debug -am package
```
This populates `repo/` and `bin/` at the repository root (both git-ignored).

## Run
Ready-made launchers (they build the classpath from `repo/` after the package step):

| Platform | Script |
|----------|--------|
| macOS    | `toolbox/debug/run-mac.command` (double-clickable; adds `-XstartOnFirstThread`) |
| Windows  | `toolbox/debug/run-windows.bat` |

The appassembler also generates `bin/wddebug` / `bin/wddebug.bat`, but on macOS use
`run-mac.command` because GLFW requires the JVM main thread.

### macOS, DCMOTO under Wine
1. Launch DCMOTO under Wine (e.g. the Sikarugir wrapper), set it to **TO8** mode and
   perform a **hard reboot** so the boot logo is visible.
2. Start wddebug. It auto-detects the `dcmoto*.exe` Wine process, finds the RAM and hooks in.

Reading another process's memory requires either running as root **or** a JVM signed
with the `com.apple.security.cs.debugger` entitlement (see `entitlements.mac.plist`).
SIP does **not** need to be disabled: the emulator runs under your own user.
On many setups a same-user Wine process is already reachable without extra signing.

To sign a packaged runtime's launcher:
```
codesign -f -s - --entitlements entitlements.mac.plist <runtime>/bin/java
```

### Notes
- Requires the 64-bit DCMOTO build (`dcmoto-64_*.exe`); under Rosetta 2 its x86-64
  memory is read transparently via Mach.
- The process is matched on the substring `dcmoto` in its path, preferring the `.exe`
  so the Wine wrapper/helpers are ignored.
