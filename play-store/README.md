# Tikaddis Play Store release

Prepared version: **1.0.1 (version code 101)**, package `com.ethioclicks.tikaddis`.
The previously uploaded maximum version code was confirmed as 100.

## Release issue to resolve

The local account deletion guide and app dialog describe soft deletion with
account and activity records retained. Verify the deployed implementation and
provide deletion of the account and associated user data, with any legitimate
retention exceptions explained to users. Do not treat the existing deactivation
flow as proof of compliance with Google's
[account deletion policy](https://support.google.com/googleplay/android-developer/answer/18258653).
This preparation does not change production data retention behavior.

## Build

Keep the existing Play upload keystore and `android/key.properties` on this
machine. Do not generate a replacement key or commit signing secrets.
Release builds fail if signing configuration is missing.

```powershell
flutter analyze
flutter test
flutter build appbundle --release
./play-store/verify-native-alignment.ps1 -BundlePath build/app/outputs/bundle/release/app-release.aab
```

The upload artifact is `build/app/outputs/bundle/release/app-release.aab`.
The prepared copy and build verification details are in
`build/play-store/1.0.1+101/`. Build output is intentionally excluded from Git.
Use `release-notes-en-US.txt` for the Play Console release notes.

## Before rollout

- Check the highest version code across **all** Play Console tracks. Code 101
  must be unused and greater than previously uploaded codes. If needed, update
  `pubspec.yaml` to a higher code and rebuild; do not upload the old bundle.
- Compare the certificate SHA-256 in the verification report with **App
  integrity > Upload key certificate** in Play Console.
- Upload the AAB to internal testing and install the Play-delivered build.
  Exercise sign-in, session renewal, notification updates, promotion search,
  channel approvals, uploads, and account deletion with test accounts. Automated
  tests do not establish production backend or device compatibility.
- Review the pre-launch report and Play Console compatibility checks before
  promoting to production.
- Confirm App access reviewer credentials and Data safety answers still match
  current behavior, including stored session credentials and file uploads.
- Verify the public privacy policy and account deletion URL in the store listing.
  `ACCOUNT_DELETION_WEB_GUIDE.md` contains implementation guidance and a placeholder
  URL, not evidence that the public deletion page is deployed.
- Attach the matching `mapping.txt` if Console requests a deobfuscation file.

No Play Console access or store upload is performed by this preparation.

## Requirements references

- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Android 16 KB page size compatibility](https://developer.android.com/guide/practices/page-sizes)
- [Flutter Android release guide](https://docs.flutter.dev/deployment/android)
