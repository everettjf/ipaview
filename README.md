# IPAView

Repository: <https://github.com/everettjf/ipaview>

Website: <https://xnu.app/ipaview/>

IPAView is a local macOS audit workbench for iOS IPA archives. Drop an IPA to inspect app identity, installed size, embedded frameworks and extensions, localizations, Privacy Manifest coverage, Mach-O architectures, provisioning details, and entitlements. Reports can be exported as JSON.

No archive contents are uploaded. Extraction happens in the app sandbox and cached files are local.

## Install

IPAView is distributed primarily through Homebrew:

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
