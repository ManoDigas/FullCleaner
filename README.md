# FullCleaner

FullCleaner is a Flutter app for Android and Windows that helps the user review and remove application leftovers without bypassing operating-system protections.

## Current features

### Windows
- Choose an application `.exe` or its folder.
- Scan common per-user data locations for folders with the same application name.
- Show every candidate before deletion.
- Keep the selected installation folder unchecked by default.
- Block Windows/system roots and other high-risk generic directories.
- Open Windows Apps settings so the program can be uninstalled normally before residue cleanup.

### Android
- List installed non-system applications.
- Open the selected app's official Android settings page.
- Start the official Android uninstall flow.
- Select user-authorized files for deletion.
- Does not attempt to bypass Android app sandboxing or root protections.

## Important limitation

No software can reliably promise that deleted data is physically unrecoverable on every SSD/flash device. FullCleaner performs logical deletion of explicitly selected items. Android also prevents a normal third-party app from directly deleting another app's private `/data/data/...` storage.

## Build

The repository includes `.github/workflows/build.yml`.

The workflow generates the standard Flutter Android/Windows platform boilerplate, runs `flutter analyze`, builds a release APK and a Windows release folder, then uploads both as GitHub Actions artifacts.

You can also build locally with a recent stable Flutter SDK:

```bash
flutter create . --platforms=android,windows --project-name full_cleaner --org com.manodigas
flutter pub get
flutter run
```

## Development branch

Initial implementation: `feature/initial-fullcleaner`
