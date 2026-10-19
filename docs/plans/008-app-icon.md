# Plan 008: StrideQuest app icon

Status: approved
Approved: 2026-10-19
Issues: <filled in after approval>

## Context

The app still ships the default Flutter icon on iOS and Android. You provided StrideQuest artwork (2000×2000 WebP): a runner, a cyclist and a swimmer in neon pink, orange and cyan on a dark navy background, a gold "SQ" medal at the top right and the words "Stride Quest" at the bottom. It is drawn as a rounded-square tile with a glossy border on an outer navy background, with a small sparkle watermark outside the tile at the bottom right.

That artwork can't be used as is:

- iOS wants a full-bleed square with no transparency and no drawn corners or border; the OS applies its own mask. A drawn rounded tile shows as a tile inside a tile.
- Android launchers mask the icon to a circle, squircle or other shape, and adaptive icons need a separate foreground and background layer.
- The text "Stride Quest" can't be read at home screen and settings sizes (40–60 px).
- The colours don't match the app. The app theme is lime `#D0EC60` on near-black (`lib/core/theme/app_theme.dart`), with the dark olive "run" gradient `#4F6E1A → #0F1A0A` (`app_tokens.dart`). You asked for green as the main colour, like the app theme.

## Open questions and assumptions

1. **Colour: the whole artwork in the app's lime and green, the medal stays gold (decided by you on 2026-10-19).** The artwork is mapped by brightness to a lime scale built from the theme: `#0A1406` → `#1A2C0E` → `#4F6E1A` → `#D0EC60` → `#F6FFD8`. The gold medal keeps its original colours. The alternative you saw and turned down kept the neon athletes and only turned the background green.
2. **No text in the icon (decided by you on 2026-10-19).** The icon keeps the three athletes and the medal, zoomed in to fill the square. The app name already shows under the icon.
3. **The prototype previews were reviewed in this session.** The final crop may move by a few pixels when the masters are made, so nothing important touches the edge under the iOS and Android masks.
4. **Android themed icon (monochrome layer) is included.** Android 13+ shows it when the user turns on themed icons. It is a single-colour silhouette taken from the artwork's bright strokes. If it looks poor at small size, the issue drops it and says so in the PR.
5. **iOS 18 dark and tinted icon variants are out of scope.** iOS uses the default icon in those modes. A follow-up can add them.

## Approach

Mobile only. No backend, API, schema or database change.

**Masters (kept in the repo).** A one-off Python script, `mobile/tool/app_icon/make_masters.py` (Pillow and NumPy, run in a throwaway virtualenv; it is not part of the app or the backend), turns the source artwork into the masters. The source and the outputs live in `mobile/assets/icon/`, which is **not** listed under `flutter: assets`, so none of it is bundled into the app:

- `source.webp`: your original artwork, unchanged.
- `app_icon.png` (1024×1024, RGB, no alpha): crop to the inside of the glossy border, fill the rounded corners and border remnants from the surrounding background, remove the text band, zoom in on the athletes and medal, then recolour to the lime scale. The watermark sits outside the tile, so the crop removes it. This is the iOS icon and the Android legacy icon.
- `app_icon_foreground.png` (1024×1024, RGBA): the same artwork scaled into the Android adaptive safe zone (the centre 66 of 108 dp), its edges faded to transparent so it blends into the background layer.
- `app_icon_monochrome.png` (1024×1024, RGBA): white silhouette with alpha from the artwork's brightness, for themed icons.

**Platform icons.** Generated from the masters with [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) `^0.14.4` as a **dev dependency** (a dependency change your approval must cover). It never ships in the app. Its config goes in `mobile/pubspec.yaml`:

```yaml
flutter_launcher_icons:
  image_path: assets/icon/app_icon.png
  ios: true
  remove_alpha_ios: true
  android: true
  min_sdk_android: 21
  adaptive_icon_background: "#16260C"
  adaptive_icon_foreground: assets/icon/app_icon_foreground.png
  adaptive_icon_monochrome: assets/icon/app_icon_monochrome.png
```

`#16260C` is the edge colour of the recoloured master, so the adaptive background matches the foreground's faded edge. Run `dart run flutter_launcher_icons` in `mobile/` and commit the generated files:

- iOS: every PNG in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` replaced, including the 1024×1024 marketing icon, and its `Contents.json`.
- Android: `ic_launcher.png` in every `mipmap-*dpi` folder; `mipmap-anydpi-v26/ic_launcher.xml` (adaptive, with the monochrome layer); `drawable-*dpi/ic_launcher_foreground.png` and `ic_launcher_monochrome.png`; `values/colors.xml` with the background colour. `AndroidManifest.xml` already points at `@mipmap/ic_launcher`, so it does not change.

The app's theme, code and tests don't change.

## Risks

- **Rendering artefacts from the clean-up** (a seam where the corners were filled, a smudge where the text was). Contained by checking the 1024 master at full size and the icon on both home screens.
- **The medal or a limb gets clipped by a launcher mask.** Contained: the adaptive foreground keeps the artwork inside the 66 dp safe zone, and the home screen screenshots are checked with circle and squircle masks.
- **iOS rejects the marketing icon** if it has an alpha channel. Contained by `remove_alpha_ios: true` and checking the 1024 PNG has no alpha.
- **The new dev dependency clashes with existing ones.** Contained by `flutter pub get`, `flutter analyze` and the full `flutter test`.

## Verification

- `flutter analyze` and the full `flutter test` in `mobile/`.
- `sips -g hasAlpha` on every iOS icon PNG reports `no`; the 1024 PNG is 1024×1024.
- iOS: build and install on the iPhone 17 simulator, screenshot the home screen before and after.
- Android: `flutter build apk --debug`, install on an emulator, screenshot the home screen before and after, plus the themed icon if the emulator supports it. Not verified yet: the Android NDK on this machine is broken (`~/Library/Android/sdk/ndk/28.2.13676358` has no `source.properties`). Deleting that folder lets Gradle download it again; that is your call, since it deletes files outside the repo. Without it, the PR shows the generated Android PNGs and a `Not verified: <reason>` line for the emulator.

## Ticket evidence

`ui` ticket. The design reference is your artwork (`mobile/assets/icon/source.webp`) and the two decisions above. Screen states and text scales don't apply to an app icon; the sizes that matter are the generated icon sizes and the home screen of each platform.

## Issues to create

| # | Title | Labels | Acceptance criteria | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `feat: StrideQuest app icon for iOS and Android` | frontend, enhancement | - [ ] `mobile/assets/icon/` holds `source.webp` and the masters `app_icon.png` (1024×1024, no alpha), `app_icon_foreground.png` and `app_icon_monochrome.png`, none of them bundled as app assets<br>- [ ] The masters have no glossy border, drawn corners, outer background, watermark or "Stride Quest" text, fill the square edge to edge, and use the app's lime and green with the medal in gold<br>- [ ] `mobile/tool/app_icon/make_masters.py` recreates the masters from `source.webp`<br>- [ ] `flutter_launcher_icons` is a dev dependency with its config in `pubspec.yaml`, and the generated files are committed<br>- [ ] iOS `AppIcon.appiconset` is complete, including the 1024×1024 marketing icon, and no icon PNG has alpha<br>- [ ] Android has `ic_launcher.png` in every mipmap density and an adaptive icon (foreground inside the safe zone, background `#16260C`, monochrome layer)<br>- [ ] `flutter analyze` and `flutter test` pass<br>- [ ] Before and after home screen screenshots on the iOS simulator and an Android emulator, or `Not verified` with the reason | none |
