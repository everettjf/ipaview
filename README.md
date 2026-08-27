# IPAView

> [!IMPORTANT]
> **Archived on August 27, 2026.** IPAView is no longer maintained or distributed. Its focused IPA inspection workflow is planned to continue in [ByteTrawl](https://xnu.app/bytetrawl/). The source remains available for historical reference.

Repository: <https://github.com/everettjf/ipaview>

Website: <https://xnu.app/ipaview/>

[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white)](https://discord.gg/eGzEaP6TzR)

IPAView was a local macOS audit workbench for iOS IPA archives. Drop an IPA to inspect app identity, installed size, embedded frameworks and extensions, localizations, Privacy Manifest coverage, Mach-O architectures, provisioning details, and entitlements. Reports can be exported as JSON.

No archive contents are uploaded. Extraction happens in the app sandbox and cached files are local.

## Historical installation

IPAView is no longer distributed or supported. The former Homebrew command was:

```sh
brew install --cask everettjf/tap/ipaview
```

## Verification

```sh
cd Core
swift test
xcodebuild -project IPAView/IPAView.xcodeproj -scheme IPAView -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

The project is maintained at a low intensity. Contributions and focused fixes are welcome.
