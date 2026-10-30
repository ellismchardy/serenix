# Dev setup (Windows)

How to get from a fresh Windows PC to green `swift test`, and onto a phone. There's no Mac
(ADR 0003): `SerenixCore` builds here, and the iOS app is built by CI and sideloaded.

## 1. Install the toolchain
```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--passive --wait --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
winget install --id Swift.Toolchain -e --version 6.4.1
```
Match the Swift version pinned in `.github/workflows/ci.yml` (currently 6.4.1): a different
`swift format` can lint differently from CI.
Then **open a new terminal** (and restart Claude Code and VS Code). Terminals that were already
open don't see the new `PATH` or `SDKROOT`, and fail with `swift: command not found` (Git
Bash), `The term 'swift' is not recognized` (PowerShell), or `unable to load standard library`.

Once per clone:
```bash
git config core.hooksPath .githooks
```
The pre-commit hook lints staged Swift files with `swift format lint --strict` and then runs
`swift build`, so a commit fails on lint errors or if `swift` isn't on the `PATH`.

## 2. Check it works
```bash
swift format lint --strict --recursive src tests Package.swift
swift build
swift test
```

## 3. Run the app on an iPhone
1. **One-time on the PC:** install iTunes and iCloud from apple.com (not the Microsoft Store),
   then Sideloadly from sideloadly.io.
2. **Get the build:** download the `Serenix-ipa` artifact from the latest CI run, or
   `gh run download <run-id> -n Serenix-ipa` (find the run ID with
   `gh run list --workflow CI --branch main`).
3. **Install:** plug the phone in by USB, unlock it and tap **Trust**. In Sideloadly, drag in
   `Serenix.ipa`, enter an Apple ID (a free one works), click **Start** and enter the 2FA code.
4. **On the phone:**
   - Settings → General → VPN & Device Management → trust your Apple ID.
   - Settings → Privacy & Security → turn on the **iPhone's** Developer Mode. It only appears
     after the first sideload, and the phone restarts.

With a free Apple ID the app expires after **7 days**: re-run Sideloadly to renew. Its
auto-refresh option can renew over Wi-Fi. At most 3 sideloaded apps at once.

## Gotchas
| Symptom | Cause | Fix |
|---|---|---|
| `module 'vcruntime' is defined in both '…\desktop\…' and '…\Desktop\…'` | The repo was opened with different path casing than last time; Swift's module cache treats them as two paths | Always open the repo with the casing Windows shows in Explorer. Delete `.build` and rebuild |
| `warning: unable to create symbolic link at …\.build\debug` | **Windows** Developer Mode is off | Harmless. Turn it on (Windows Settings → System → For developers) to silence it |
| `warning: reference to type 'wchar_t' broken by a context change` | Comes from the Swift toolchain's Windows SDK | Harmless |
| `swift: command not found` / `'swift' is not recognized` in a commit | Hook ran in a terminal opened before the install | Open a new terminal |
