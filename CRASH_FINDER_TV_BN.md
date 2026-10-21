# Live TV Remote — Android TV Crash Finder (v1.1.5)

## কেন এই সংস্করণ

Android মোবাইলে চললেও Android TV-তে অ্যাপ চালু করামাত্র বন্ধ হয়ে যাচ্ছে। TV-এর প্রকৃত crash log এখনো পাওয়া যায়নি, তাই শুধু অনুমান করে সেটিকে সমাধান হয়েছে বলা যাবে না। এই সংস্করণে ডিভাইস থেকেই রিপোর্ট বের করার ব্যবস্থা রয়েছে।

## Android TV-তে যেভাবে ব্যবহার করবেন (v1.1.5)

1. অ্যাপ আইকন থেকে **Live TV Remote** সরাসরি খুলুন। আগের Diagnostic Start Screen নেই।
2. Channel Guide-এ প্রথম চ্যানেল থেকে **UP** অথবা তালিকা থেকে **RIGHT** চাপুন।
3. ওপরের Bug আইকনে **LEFT/RIGHT** দিয়ে গিয়ে **OK** চাপুন: Native **Crash Finder** খুলবে।
4. **Refresh → Save TXT** ব্যবহার করুন। Clear চাপার আগে রিপোর্ট সংরক্ষণ করুন।
5. অ্যাপ চালুই না হলে নিচে দেওয়া ADB কমান্ড দিয়ে Crash Finder সরাসরি খুলুন।

রিপোর্ট মূল অ্যাপের local storage-এ থাকে। Debug APK-এর package আলাদা (`com.example.live_tv_remote.diagnostic`), তাই সেটির Crash Finder release অ্যাপের রিপোর্ট দেখতে পাবে না। **Release APK-এর Crash Finder** ব্যবহার করবেন।

## ADB দিয়ে Crash Finder সরাসরি খুলুন

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

Live TV শুরু হলে, অ্যাপে ফিরে এলে এবং সচল অবস্থায় প্রায় প্রতি ২ মিনিটে sync চেক। সর্বশেষ সফল তালিকার cache/৫১৩টি bundled fallback, রিমোট CH+/CH-, D-pad, OK, Volume এবং Favorites আগের মতো আছে।

## যাচাইয়ের অবস্থা

ম্যানিফেস্ট, সরাসরি Flutter launcher, error-handler wiring, source paths ও GitHub URL-এর structural check চালানো হয়েছে। এই environment-এ Flutter SDK ও Android TV ডিভাইস নেই—APK build ও TV-তে runtime যাচাই করা হয়নি।
