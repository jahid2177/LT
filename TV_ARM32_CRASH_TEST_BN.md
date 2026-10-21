# Android TV Crash Finder v1.1.4 — Haier CANDY Android TV (ARM32)

## ছবিতে যা পাওয়া গেছে

- TV: Haier CANDY Android TV DVB2K, Android 11 / API 30
- CPU ABI: `armeabi-v7a`, `armeabi` — **32-bit ARM only**, no `arm64-v8a`
- `No TV launch recorded` — Crash Finder চলেছে, কিন্তু Flutter-এর MainActivity launch রেকর্ড পায়নি।
- `No process exits recorded` — এই রিপোর্ট থেকে crash-এর কারণ নিশ্চিত করা যাচ্ছে না।

## এই আপডেটে কী পরিবর্তন

1. GitHub Actions-এর **universal release APK**-তে `android-arm` এবং `android-arm64` উভয় ABI থাকবে। build job এখন `lib/armeabi-v7a/libflutter.so`, `lib/armeabi-v7a/libapp.so`, এবং `lib/arm64-v8a/libflutter.so` নিশ্চিত করে।
2. **একটিমাত্র TV launcher**—`Live TV Remote`—প্রথমে Native Start Screen খুলবে; এটি Flutter প্লাগইন চালায় না।
3. রিমোটে `START LIVE TV` চাপলেই Flutter MainActivity খুলবে এবং diagnostic log-এ ধাপ রেকর্ড হবে।
4. রিমোটে `OPEN CRASH FINDER` চাপলে রিপোর্ট দেখা যাবে। Finder-এ `Try Live TV` বাটনও আছে।
5. আপনার GitHub `channels.json` source ও ২-মিনিট auto refresh অপরিবর্তিত।

## TV-তে পরীক্ষার ধাপ

1. GitHub Actions থেকে `Live-TV-Remote-AndroidTV-ARM32-ARM64-Universal` artifact-এর `app-release.apk` ইনস্টল করুন।
2. TV-তে `Live TV Remote` খুলুন। Native start screen দেখা উচিত।
3. `START LIVE TV` চাপুন। যদি বন্ধ হয়, TV home থেকে `Live TV Remote` আবার খুলুন।
4. `OPEN CRASH FINDER` → `REFRESH` → `SAVE TXT`।
5. `Downloads/LiveTVRemote/` থেকে রিপোর্টটি দিন। **CLEAR চাপবেন না**।

## রিপোর্টে কীভাবে বুঝবেন

- `TV_HOME_OPENED`: Native app শুরু হয়েছে
- `START_TV_BUTTON_PRESSED`: TV চালাতে রিমোটের OK চাপা হয়েছে
- `TV_MAIN_ACTIVITY_START`: MainActivity-এর `super.onCreate()`-এর আগে পৌঁছেছে
- `FLUTTER_ENGINE_REGISTER_BEGIN`: Flutter engine plugin setup শুরু
- `FLUTTER_ENGINE_REGISTERED`: registration সম্পন্ন
- `FLUTTER_FIRST_FRAME`: প্রথম Flutter UI frame দেখা গেছে
- `FATAL_JAVA_CRASH`: native Java/Kotlin stack trace আছে
- `NATIVE_CRASH`: system exit history-তে native crash আছে (Android 11+)

### ADB ছাড়া ক্র্যাশের লগ পুরোপুরি পাওয়া না গেলে

TV-তে Developer Options / USB debugging সক্ষম করে `adb connect <TV-IP>:5555` (যদি TV network ADB সমর্থন করে) বা USB debugging ব্যবহার করুন। তারপর PC-তে:

```powershell
adb logcat -c
adb shell am start -n com.example.live_tv_remote/.TvHomeActivity
adb logcat -d -v time > live_tv_tv_crash.txt
```

ADB সংযোগ পদ্ধতি TV firmware অনুযায়ী আলাদা হতে পারে।

**সীমাবদ্ধতা:** Native SIGSEGV/MediaCodec crash ও অতি-প্রাথমিক Android loader failure সর্বদা Crash Finder দিয়ে ধরা যায় না। Flutter SDK ও আসল Haier TV-তে রানটাইম যাচাই এখানে হয়নি।
