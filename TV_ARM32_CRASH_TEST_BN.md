# Live TV Remote v1.1.5 — ARM32 Android TV পরীক্ষা

Android TV (Haier CANDY, Android 11, `armeabi-v7a`) সমর্থন বজায় আছে। এই সংস্করণে **Native diagnostic Start Screen নেই**। অ্যাপ আইকনে চাপলেই Flutter Live TV সরাসরি শুরু হবে।

## রিমোট দিয়ে ওপরের আইকন নির্বাচন

1. অ্যাপ খুলে `OK` বা `MENU` দিয়ে Channel Guide খুলুন।
2. প্রথম চ্যানেল নির্বাচিত থাকলে `UP` অথবা তালিকার যেকোনো চ্যানেল থেকে `RIGHT` চাপুন।
3. ওপরের Favorites আইকনে ফোকাস দেখা যাবে। `LEFT/RIGHT` দিয়ে Refresh, Crash Finder, Settings, Close বেছে নিন।
4. `OK` চাপলে নির্বাচিত আইকনের কাজ হবে। `DOWN` চাপলে চ্যানেল তালিকায় ফিরবে।
5. ভলিউমের বাটন Android-এর সিস্টেমের মাধ্যমেই কাজ করবে।

## ক্র্যাশ হলে

অ্যাপের ওপরের **Bug** আইকন থেকে Crash Finder চালানো যাবে। অ্যাপ একেবারেই চালু না হলে PC-তে ADB সংযোগ দিয়ে এই কমান্ড ব্যবহার করুন:

```powershell
adb shell am start -n com.example.live_tv_remote/.CrashFinderActivity
```

পূর্ণ runtime log প্রয়োজন হলে:

```powershell
adb logcat -c
adb shell am start -n com.example.live_tv_remote/.MainActivity
adb logcat -d -v threadtime > live_tv_crash_logcat.txt
```

GitHub Actions-এর `Live-TV-Remote-AndroidTV-ARM32-ARM64-Universal` Artifact থেকে release APK ইনস্টল করুন। এই পরিবেশে Flutter SDK/TV না থাকায় প্রকৃত APK বিল্ড ও রিমোটের আচরণ পরীক্ষা করা যায়নি।
