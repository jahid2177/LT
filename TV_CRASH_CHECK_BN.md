> **v1.1.5 তথ্য:** আগের Native Start Screen ও `OPEN CRASH FINDER` বাটন সরানো হয়েছে। TV এখন সরাসরি Live TV খুলবে। Crash Finder পাওয়া যাবে Channel Guide-এর ওপরের Bug আইকন থেকে বা ADB কমান্ডে।

# Android TV-তে অ্যাপ খুললেই ক্র্যাশ — করণীয়

এই সংস্করণে প্রথমে ৫১৩টি চ্যানেলের গাইড দেখাবে; নিজে থেকে প্রথম চ্যানেল চালাবে না। রিমোটের Up/Down দিয়ে চ্যানেল বেছে OK চাপলে ভিডিও শুরু হবে। এটি TV-র দুর্বল ভিডিও ডিকোডারের startup crash এড়ানোর পরীক্ষামূলক ব্যবস্থা।

GitHub Actions > Android TV APK > Run workflow চালিয়ে দুটি Artifact পাবেন:

- `Live-TV-Remote-AndroidTV-ARM32-ARM64-Universal` — স্বাভাবিক Release APK
- `Live-TV-Remote-AndroidTV-ARM32-Diagnostic-debug` — সমস্যা পরীক্ষার Debug APK (পৃথক অ্যাপ হিসেবে ইনস্টল হবে)।

TV-এর Native start screen থেকে START LIVE TV চাপুন; বন্ধ হলে OPEN CRASH FINDER চাপুন। Release খোলামাত্র ক্র্যাশ করলে Debug APK চালিয়ে দেখুন। দুটিই ক্র্যাশ করলে TV-এর crash log দরকার।

Windows PC-তে ADB কানেক্ট করে PowerShell-এ নিচের কমান্ড দিন:

```powershell
adb devices
adb logcat -c
adb shell am force-stop com.example.live_tv_remote
adb shell monkey -p com.example.live_tv_remote -c android.intent.category.LAUNCHER 1
adb logcat -d -v time > live_tv_crash.txt
```

`live_tv_crash.txt` আপলোড করলে প্রকৃত stack trace দিয়ে সমস্যা শনাক্ত করা যাবে।

**সতর্কতা:** এখানে Flutter/Android SDK নেই; APK বিল্ড ও TV-তে চালিয়ে পরীক্ষা করা হয়নি।
