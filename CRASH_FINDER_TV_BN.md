# Live TV Remote — Android TV Crash Finder (v1.1.3)

## কেন এই সংস্করণ

Android মোবাইলে চললেও Android TV-তে অ্যাপ চালু করামাত্র বন্ধ হয়ে যাচ্ছে। TV-এর প্রকৃত crash log এখনো পাওয়া যায়নি, তাই শুধু অনুমান করে সেটিকে সমাধান হয়েছে বলা যাবে না। এই সংস্করণে ডিভাইস থেকেই রিপোর্ট বের করার ব্যবস্থা রয়েছে।

## Android TV-তে যেভাবে ব্যবহার করবেন

1. নতুন `app-release.apk` ইনস্টল করুন। পুরোনো অ্যাপের একই application ID-তে আপডেট দিলে আগের ডেটা থাকবে (একই signing key লাগবে)।
2. TV-এর অ্যাপ তালিকায় দুটি আইকন দেখার কথা: **Live TV Remote** ও **Live TV Crash Finder**। কিছু TV launcher দ্বিতীয় আইকন দেখায় না; সে ক্ষেত্রে নিচে ADB দিয়ে খোলার বিকল্প আছে।
3. প্রথমে **Live TV Remote** চালান। যদি সঙ্গে সঙ্গে বন্ধ হয়ে যায়, **Live TV Crash Finder** খুলুন।
4. **Refresh** চাপুন। নিচের রিপোর্টে `FATAL_JAVA_CRASH`, `DART_ERROR`, `PREVIOUS_TV_STARTUP_INCOMPLETE` অথবা `ANDROID PROCESS EXIT HISTORY` দেখুন।
5. **Save TXT** চাপুন। Android 10+ TV-তে `Downloads/LiveTVRemote/live_tv_crash_....txt` তৈরি হওয়ার কথা। **Share** দিয়ে রিপোর্ট পাঠাতে পারেন। TV-তে শেয়ারিং অ্যাপ না থাকলে Save TXT বা Copy ব্যবহার করুন।
6. রিপোর্ট ফাইলটি ChatGPT-তে আপলোড করুন। **Clear** চাপলে আগের লগ মুছে যাবে—রিপোর্ট সংগ্রহের আগে Clear করবেন না।

রিপোর্ট মূল অ্যাপের local storage-এ থাকে। Debug APK-এর package আলাদা (`com.example.live_tv_remote.diagnostic`), তাই সেটির Crash Finder release অ্যাপের রিপোর্ট দেখতে পাবে না। **Release APK-এর Crash Finder** ব্যবহার করবেন।

## দ্বিতীয় আইকন না দেখালে ADB দিয়ে Crash Finder খুলুন

TV-তে Developer Options এবং ADB debugging চালু করে PC-এর সঙ্গে সংযুক্ত করুন:

```powershell
adb devices
adb shell am start -n com.example.live_tv_remote/.CrashFinderActivity
```

TV অ্যাপকে সরাসরি চালাতে:

```powershell
adb shell am start -n com.example.live_tv_remote/.MainActivity
```

## ক্র্যাশ Finder-এ FATAL_ERROR না এলে

অ্যান্ড্রয়েড টিভি firmware-এর native `SIGSEGV` / `SIGABRT`, Flutter engine লোড হওয়ার আগের failure, অথবা OS-এর low-memory kill সবসময় Java/Kotlin error handler-এ ধরা পড়ে না। Android 11+ ডিভাইসে Crash Finder-এর **ANDROID PROCESS EXIT HISTORY** native crash / memory kill শনাক্ত করতে সাহায্য করতে পারে, কিন্তু সম্পূর্ণ stack trace-এর জন্য ADB logcat সংগ্রহ করুন:

```powershell
adb logcat -c
adb shell am force-stop com.example.live_tv_remote
adb shell am start -n com.example.live_tv_remote/.MainActivity
adb logcat -d -v threadtime > live_tv_crash_logcat.txt
```

`live_tv_crash_logcat.txt`-ও পাঠান। `FATAL EXCEPTION`, `Fatal signal`, `AndroidRuntime`, `libflutter.so`, `MediaCodec`, `linker` ইত্যাদি অংশ গুরুত্বপূর্ণ।

## কী কী রেকর্ড হয়

- TV ডিভাইস/Android/ABI, process startup
- Flutter engine/plugin registration, Dart main, প্রথম Flutter frame
- চ্যানেল cache restore, GitHub sync, video player start
- Java/Kotlin uncaught fatal exceptions, Dart/Flutter uncaught errors
- Android 11+ হলে ঐ অ্যাপের সাম্প্রতিক process-exit reason

সমস্ত রিপোর্ট **ডিভাইসের ভেতরে** থাকে; কোনো তৃতীয় পক্ষের সার্ভারে স্বয়ংক্রিয়ভাবে পাঠানো হয় না। রিপোর্ট শেয়ার করার আগে নিজে দেখে নিন—stack trace-এ সংবেদনশীল স্ট্রিম/ডিভাইসের তথ্য থাকতে পারে।

## অপরিবর্তিত সুবিধা

চ্যানেলের **মূল সোর্স**:
`https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json`

অ্যাপ চালুতে, অ্যাপে ফিরে এলে এবং সচল অবস্থায় প্রায় প্রতি ২ মিনিটে sync চেক। সর্বশেষ সফল তালিকার cache/৫১৩টি bundled fallback, রিমোট CH+/CH-, D-pad, OK, Volume এবং Favorites আগের মতো আছে।

## যাচাইয়ের অবস্থা

ম্যানিফেস্ট, Native launcher, error-handler wiring, source paths ও GitHub URL-এর structural check চালানো হয়েছে। এই environment-এ Flutter SDK ও Android TV ডিভাইস নেই—APK build ও TV-তে runtime যাচাই করা হয়নি।
