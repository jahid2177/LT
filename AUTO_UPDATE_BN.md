# অটো-আপডেট ও GitHub Release (v1.2.0)

## কীভাবে কাজ করে

1. `pubspec.yaml`-এ `version:` বাড়িয়ে (নাম ও `+` এর পরের build number দুটোই, যেমন `1.2.0+12` → `1.2.1+13`) `main`-এ push করুন।
2. GitHub Actions APK build করে, স্থায়ী key দিয়ে sign করে এবং `v<version>` নামে একটি GitHub Release প্রকাশ করে। Release-এ থাকে `live-tv-remote.apk` ও `version.json`।
3. TV-তে থাকা অ্যাপ চালুর ~১২ সেকেন্ড পরে এবং এরপর প্রতি ৬ ঘণ্টায় `releases/latest/download/version.json` দেখে। নতুন `versionCode` পেলে "App update available" ডায়ালগ দেখায়।
4. **Update now** চাপলে অ্যাপ APK নামিয়ে Android-এর installer খুলে দেয়। Android নিজে নিশ্চিতকরণ চায়; Android 12+ এ প্রথমবারের পর এটি নীরবে হতে পারে। **Later** চাপলে অ্যাপ আবার চালু না করা পর্যন্ত ওই ভার্সনের জন্য আর জিজ্ঞেস করে না।

## একবারের সেটআপ (আবশ্যক)

GitHub রিপো → **Settings → Secrets and variables → Actions → New repository secret**-এ দুটি secret যোগ করুন:

| নাম | মান |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | keystore ফাইলের base64 লেখা |
| `ANDROID_KEYSTORE_PASSWORD` | keystore-এর পাসওয়ার্ড |

Secret না থাকলে build চলবে, কিন্তু APK অস্থায়ী debug key দিয়ে sign হবে এবং **কোনো Release প্রকাশ হবে না**।

keystore ফাইল ও পাসওয়ার্ডের একটি কপি নিরাপদ জায়গায় রাখুন। এগুলো হারালে আর কোনো update পুরোনো অ্যাপের ওপর বসবে না।

## প্রথমবার

আগের APK-গুলো অস্থায়ী debug key দিয়ে sign করা ছিল। তাই TV থেকে পুরোনো অ্যাপ **একবার uninstall** করে Release-এর `live-tv-remote.apk` ইনস্টল করতে হবে (favorites মুছে যাবে)। এরপর থেকে update অ্যাপের ভেতর থেকেই আসবে।

## সীমাবদ্ধতা

- রিপো ও Release পাবলিক থাকতে হবে।
- TV-তে এই অ্যাপের জন্য "Install unknown apps" অনুমতি চাইলে একবার অনুমতি দিতে হবে।
- Update বসার সময় অ্যাপ বন্ধ হয়; installer-এর **Open** চেপে বা লঞ্চার থেকে আবার চালু করুন।
- Diagnostic (debug) APK-তে update check বন্ধ, কারণ তার package name আলাদা।
- এই পরিবেশে Flutter SDK/TV নেই; প্রকৃত build ও TV-তে install এখনো পরীক্ষা করা হয়নি।

## v1.2.0-এর অন্যান্য পরিবর্তন

- রিমোট দিয়ে Favorite: guide-এ চ্যানেল হাইলাইট করে → RIGHT → ♥ আইকন → OK।
- Stream error হলে **OK** চাপলে retry হয় (LEFT/BACK/MENU দিয়ে guide)।
- চ্যানেল লোগো ছোট সাইজে decode হয় (কম RAM-এর TV-তে মেমোরি বাঁচে)।
- Custom playlist আর সংরক্ষিত GitHub অফলাইন কপি মুছে দেয় না।
- Favorites তালিকার হিসাব দ্রুত করা হয়েছে; অব্যবহৃত `TvHomeActivity.kt` সরানো হয়েছে।
- Flutter ভার্সন 3.47.7-এ pin করা হয়েছে।

## Run workflow থেকে নতুন ভার্সন প্রকাশ (v1.3.0 থেকে)

GitHub → **Actions → Android TV APK → Run workflow** (branch: `main`):

- **version**: যেমন `1.3.1`। ফাঁকা রাখলে `pubspec.yaml`-এর ভার্সন ব্যবহার হয়।
- **build_number**: ফাঁকা রাখুন; সর্বশেষ Release-এর build + 1 নিজে বসবে।
- **notes**: ঐচ্ছিক। টিভিতে আপডেট ডায়ালগে "What is new" হিসেবে দেখায় (সর্বোচ্চ ৬০০ অক্ষর)।

ওই ভার্সনের Release আগে থেকে থাকলে workflow error দেয়।

## মৃত লিংকের রিপোর্ট

**Actions → Check stream links** প্রতিদিন নিজে চলে (চাইলে Run workflow দিয়েও চালানো যায়)।
bundled `assets/channels.json` ও GitHub-এর `faria2177/live-tv-channels` ফিড দুটোই পরীক্ষা করে।
রিপোর্ট run-এর Summary-তে দেখা যায়। **কিছু নিজে মোছে না।** "Uncertain" মানে
timeout/403/5xx; GitHub-এর সার্ভারের অঞ্চল-নিষেধাজ্ঞার কারণেও হতে পারে, তাই যাচাই করে মুছুন।
`stream-link-report` artifact-এ মৃত চ্যানেল বাদ দেওয়া একটা কপিও থাকে।
