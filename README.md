# IPAView

Repository: <https://github.com/everettjf/ipaview>

Website: <https://xnu.app/ipaview/>

IPAView is a local macOS audit workbench for iOS IPA archives. Drop an IPA to inspect app identity, installed size, embedded frameworks and extensions, localizations, Privacy Manifest coverage, Mach-O architectures, provisioning details, and entitlements. Reports can be exported as JSON.

No archive contents are uploaded. Extraction happens in the app sandbox and cached files are local.

## Verification

```sh
cd Core
swift test
xcodebuild -project IPAView/IPAView.xcodeproj -scheme IPAView -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

[Download from the Mac App Store](https://apps.apple.com/us/app/ipaview-for-dev/id6475201960?mt=12)
