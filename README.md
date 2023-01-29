![Screenshot](https://boards.chance.surf/assets/promo.png)

# Chance

Imageboard browser built using Flutter intended for use on iOS and Android.

## Features

- Multi-column layout for larger screens
- WEBM playback and conversion
- Pick images through in-app web search
- Media gallery view
- Save threads, posts, and attachments to a local collection
- Automatically aligns the captcha slider
- Gestures to navigate through replies
- Switch between multiple browsing tabs
- Optional and automatic adjustments for mouse usage
- Regular-expression filters to hide or highlight posts
- Support for archives to access deleted threads or search for posts
- Thread watcher to check for replies

## Installing on Android

APKs are available on the [releases page](https://github.com/moffatman/chan/releases/).

## Installing on iOS

Chance has not yet been submitted to the App Store. [Click here to join the beta testing group for iOS.](https://testflight.apple.com/join/gdHJSbzI)

## How to compile

1. [Install flutter](https://docs.flutter.dev/get-started/install)
2. Clone and enter the Chance repository
```
git clone https://github.com/moffatman/chan.git
cd chan
```
3. Fetch dependencies
```
flutter pub get
```
4. (Optional) Modify the package name (find-and-replace `com.moffatman.chan` with your own package identifier)
    - This will let you create signing keys and create signed builds, which is necessary to install the app on your own iOS devices, or distribute Android APKs
5. Run `build_runner` to create some necessary generated dart code
```
flutter pub run build_runner build
```
6. To build an APK for android, run `flutter build apk --split-per-abi --release --enable-experiment=records`
7. To build for iOS (Mac and Xcode required), run `flutter build ios --release --enable-experiment=records`
8. To run in development mode, use `flutter run --enable-experiment=records` while your device is connected

Chance is developed using the `flutter` `master` branch, so if you get errors while building or running, try using `flutter channel dev` or `flutter channel master`. Because it takes advantage of some preview Dart 3 features, the argument `--enable-experiment=records` is required to run it.

## FAQ

### Why isn't it displaying the content I expect?

By default, the app is set up to browse a test server. In the app settings, you can edit your content preferences to browse a different imageboard. 

### Why are some settings on a web page?

To comply with [Apple App Store guidelines](https://developer.apple.com/app-store/review/guidelines/#user-generated-content), not all settings are modifiable in the app. 

### How can I quickly scroll to the top of a thread?

Tap the status bar

### How can I quickly scroll to the bottom of a thread?

Hold on the post counter at the bottom-right

### How can I get help, report a bug, or request a feature?

There is an imageboard available in the settings page of Chance that is used for meta-discussion.

## License

Chance is licensed under version 3 of the GNU General Public License. See [LICENSE](https://github.com/moffatman/chan/blob/master/LICENSE) for more information. 
