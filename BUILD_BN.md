# Live TV Remote — বাংলায় বিল্ড ও ব্যবহার

## GitHub থেকে APK তৈরি

1. `Live-TV-Remote-Flutter.zip` ফাইল Extract করুন।
2. GitHub-এ নতুন খালি Repository খুলুন।
3. Extract করা `live_tv_remote` ফোল্ডারের **ভেতরের সব ফাইল** (লুকানো `.github` ফোল্ডারসহ) Repository-তে আপলোড করুন।
4. GitHub → **Actions** → **Android TV APK** → **Run workflow** চাপুন।
5. Build সফল হলে Run-এর **Artifacts** থেকে `Live-TV-Remote-AndroidTV-arm64` ডাউনলোড করুন।
6. Artifact ZIP-এর ভিতরে `app-release.apk` পাবেন। TV-তে Install করুন।

প্রথম Build-এ Flutter/Gradle dependencies ডাউনলোড হওয়ায় বেশি সময় লাগতে পারে। এটি Play Store signing নয়; sideload testing APK।

## রিমোট দিয়ে ব্যবহার

- **CH+ / CH−** — পরের / আগের চ্যানেল।
- **D-pad UP / DOWN** — সাধারণ অবস্থায় চ্যানেল পরিবর্তন। Guide খোলা থাকলে চ্যানেল নির্বাচন।
- **OK** — Channel Guide খুলবে; Guide-এ OK চাপলে চ্যানেল চলবে।
- **LEFT** — Guide খুলবে বা বন্ধ হবে।
- **RIGHT** — চ্যানেলের তথ্য দেখাবে / Guide বন্ধ করবে।
- **BACK** — Guide বন্ধ বা তথ্য লুকানো।
- **Volume+ / Volume−** — Android TV-এর নিজস্ব ভলিউম কন্ট্রোল।
- **0–9** — চ্যানেল নম্বর টাইপ করে এক সেকেন্ড পর সেই চ্যানেলে যাওয়া।
- **MENU/GUIDE** — চ্যানেল তালিকা।
- **F** (keyboard) — Favorite। **M** — Playlist Settings।

## চ্যানেল কোথা থেকে আসবে?

এই অ্যাপে **কোনো অনুমতি-বিহীন লাইভ চ্যানেল দেওয়া হয়নি**। আপনার বৈধ M3U playlist-এর URL/ফাইল দিন। `Load playback demo` টিপলে কেবল প্লেয়ার পরীক্ষার জন্য **লাইভ নয় এমন** দুটি sample video যুক্ত হবে।

## টিভির নিজস্ব অ্যান্টেনা/ডিশ/কেবল চ্যানেল চালাতে চাইলে

এই প্রজেক্ট IPTV প্লেয়ার। Built-in tuner-এর DVB-T, DVB-C, DVB-S সিগন্যাল পড়তে গেলে TV firmware/TV Input Framework/OEM অনুমতি ও tuner SDK দরকার হতে পারে। সাধারণ Android TV app-এর মাধ্যমে সব টিভির tuner সরাসরি নিয়ন্ত্রণ করা যায় না।

## গুরুত্বপূর্ণ সীমাবদ্ধতা

সব TV remote-এ CH+ / CH− key Android app-এ পৌঁছায় না। অনেক device-এর CH ও volume key hardware বা TV firmware নিজে handle করে। এই ক্ষেত্রে D-pad দিয়ে চ্যানেল পরিবর্তন করা যাবে, কিন্তু হার্ডওয়্যার key জোর করে দখল করা যাবে না।

Build সফল হওয়া যাচাই করতে GitHub Actions-এর `flutter analyze`, `flutter test` ও `flutter build apk` ধাপগুলো সবুজ হওয়া দরকার।


## আপনার দেওয়া GitHub channels.json (নতুন)

অ্যাপ প্রথমবার চালু হলে নিচের URL থেকে JSON ডাউনলোড করার চেষ্টা করবে:

`https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json`

- URL বারবার পেস্ট করতে হবে না।
- পরেরবার চালুর সময় চ্যানেল তালিকা আপডেট করার চেষ্টা করবে।
- ইন্টারনেট সমস্যা হলে সর্বশেষ সফলভাবে সংরক্ষিত তালিকা ব্যবহার করবে (স্ট্রিম দেখতে ইন্টারনেট প্রয়োজন)।
- রিমোটের OK দিয়ে Channel Guide খুলুন; CH+/CH- অথবা D-pad দিয়ে চ্যানেল বদলান।
- Guide-এর Refresh আইকন থেকে চ্যানেল তালিকা পুনরায় লোড করতে পারবেন।
- Settings থেকে JSON/M3U URL, local file, বা pasted content ব্যবহার করতে পারবেন।

**যাচাই সংক্রান্ত সতর্কতা:** এই পরিবেশে GitHub raw JSON-এর ডেটা পড়া যায়নি। প্রজেক্টে সাধারণ JSON কাঠামোর পার্সার তৈরি করা হয়েছে, কিন্তু আপনার প্রকৃত ফাইলের স্কিমা ও স্ট্রিমগুলো এখানে যাচাই করা সম্ভব হয়নি। GitHub Actions-এ `flutter analyze`, `flutter test` ও APK build পরীক্ষা হবে। আপনার JSON ভিন্ন স্কিমা ব্যবহার করলে ফাইলটি সংযুক্ত করুন।

## নতুন আপডেট — README.json ফাইল

- আপনার আপলোড করা `README.json` ফাইলের **৫১৩টি** চ্যানেল রেকর্ড `assets/channels.json` হিসেবে যোগ করা হয়েছে।
- প্রথমবার অ্যাপ চালু করলে আগে এই চ্যানেল তালিকা দেখাবে; তারপর GitHub লিংক থেকে নতুন তালিকা আনার চেষ্টা করবে।
- GitHub কাজ না করলে পুরোনো বা অ্যাপের ভেতরের তালিকা থাকবে। তালিকা offline দেখা গেলেও ভিডিও দেখতে কার্যকর ইন্টারনেট স্ট্রিম প্রয়োজন।
- **Manage TV channels → Use bundled README.json channels (513)** দিয়ে ফাইলটি পুনরায় লোড করা যাবে।
- `file_picker` v13 API পরিবর্তনের কারণে আগের `pickFiles` ব্যবহার সংশোধন করা হয়েছে।
- Android-এর `minSdk` 24 করা হয়েছে (`video_player` সমর্থনের জন্য)।
- ৫০টি URL-এ `e=` মেয়াদ টোকেন জুলাই ২০২৬-এর; এগুলো আর কাজ নাও করতে পারে। এই অ্যাপ নতুন টোকেন তৈরি/DRM বাইপাস করে না।
- বিস্তারিত দেখুন `CHANGES_README_JSON.md`।

## ২১ অক্টোবর ২০২৬: GitHub Actions Gradle Build Fix

GitHub run `logs_107174983477.zip` এ ১১টি unit test পাস করলেও APK বিল্ড ব্যর্থ হয়েছিল:
`Gradle 8.11.1 is lower than Flutter 3.47.7 minimum supported version 8.14.0`।

- `android/gradle/wrapper/gradle-wrapper.properties` → Gradle **8.14.5**।
- `android/settings.gradle.kts` → Android Gradle Plugin **8.11.1** (API 36 compatible, AGP 9 নয়)।
- Java 17 অপরিবর্তিত; Kotlin Gradle Plugin **2.1.20 → 2.2.21** (Gradle 8.14 / AGP 8.11.1 compatibility)।
- GitHub Actions-এ Build-এর আগে `tools/check_android_toolchain.py` সংস্করণ যাচাই করবে।
- `actions/checkout@v5` ও `actions/setup-java@v5` দিয়ে Node.js 20 warning কমানো হয়েছে।
- Log-এ দেখা ৭টি Dart lint info সংশোধন করা হয়েছে।

**নোট:** এখানে Flutter/Android SDK না থাকায় নতুন APK বিল্ড করে যাচাই করা যায়নি। GitHub Actions workflow চালিয়ে চূড়ান্ত যাচাই করুন।

## ২১ অক্টোবর ২০২৬: R8 Missing Class Fix (নতুন বিল্ড লগ)

`logs_107179239559.zip` অনুযায়ী Gradle সংস্করণের সমস্যা আর নেই। ১১টি test পাস, `flutter analyze`-এ কোনো issue নেই; কিন্তু Release APK R8 Minify ধাপে `androidx.window.extensions` এবং `androidx.window.sidecar`-এর ঐচ্ছিক OEM ক্লাস না পাওয়ায় ব্যর্থ।

- `android/app/proguard-rules.pro`-এ শুধু এই দুই ঐচ্ছিক package-এর `-dontwarn` নিয়ম যুক্ত হয়েছে।
- `android/app/build.gradle.kts`-এর `release` অংশ থেকে নিয়মটি লোড হবে।
- GitHub Actions-এ নিয়মের উপস্থিতি যাচাই এবং ভবিষ্যতে বিল্ড ব্যর্থ হলে `missing_rules.txt` artifact হিসেবে রাখার ব্যবস্থা যুক্ত হয়েছে।
- অ্যাপের চ্যানেল তালিকা ও প্লেয়ার অপরিবর্তিত।

সংশোধিত ফাইল GitHub-এ আপলোড করে **Actions → Android TV APK → Run workflow** চালান। এটি এখনো এখানে APK build করে পরীক্ষা করা হয়নি। বিস্তারিত `BUILD_FIX_R8_2026-10-21.md`।
