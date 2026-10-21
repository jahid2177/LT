# Live TV Remote v1.1.5 — আপনার দুই ছবির সমস্যার সংশোধন

## প্রথম ছবি — Diagnostic Start Screen বাদ

- অপ্রয়োজনীয় `START LIVE TV` ও `OPEN CRASH FINDER` স্ক্রিন সরানো হয়েছে।
- `AndroidManifest.xml`-এ TV/mobile launcher সরাসরি `.MainActivity`।
- Native `CrashFinderActivity`-এর error logging রাখা হয়েছে; এখন সেটি কেবল Channel Guide-এর Bug আইকন অথবা ADB থেকে পাওয়া যাবে।

## দ্বিতীয় ছবি — উপরের আইকন রিমোট দিয়ে ব্যবহার

| রিমোট | Guide-এর চ্যানেল তালিকায় | Guide-এর ওপরের Toolbar-এ |
|---|---|---|
| UP | আগের চ্যানেল, প্রথমটি থেকে Toolbar-এ | Toolbar-এ থাকে |
| DOWN | পরের চ্যানেল | চ্যানেল তালিকায় ফেরে |
| RIGHT | Toolbar-এ যায় | পরের আইকন |
| LEFT | Guide বন্ধ হয় | আগের আইকন |
| OK | চ্যানেল চালায় | নির্বাচিত আইকনের কাজ চালায় |
| BACK | Guide বন্ধ | Guide বন্ধ |

Toolbar-এর আইকনগুলোর ক্রম: **Favorites → Refresh GitHub → Crash Finder → Settings → Close**।
নির্বাচিত আইকনের চারপাশে বড় **সাদা বর্ডার ও নীল হাইলাইট** দেখা যাবে।

- Header এখন দুই সারিতে; ছোট রিমোট/TV-তে আইকন চেপে যাওয়ার সমস্যা কমবে।
- `ExcludeFocus`-এর মাধ্যমে Flutter-এর স্বয়ংক্রিয় focus stealing রোধ করা হয়েছে; হার্ডওয়্যার D-pad event একই Focus widget থেকে নিয়ন্ত্রিত হবে।
- Favorites ফিল্টারে শূন্য চ্যানেল থাকলেও Toolbar-এ গিয়ে `Show all` বেছে নেওয়া সম্ভব।
- Favorites আইকন চ্যানেলভিত্তিক সঠিকভাবে দেখানোর একটি বাগ সংশোধিত।

## অপরিবর্তিত

- GitHub-এর প্রধান JSON URL: `https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json`
- অ্যাপ খোলার সময়, অ্যাপে ফিরে এলে এবং প্রতি ২ মিনিটে অনলাইন চেক।
- ৫১৩টি bundled fallback, Favorites, Player, CH+/CH−, system volume।
- ARM32+ARM64 Release APK build workflow ও Native Crash log।

## পরীক্ষা

- `python3 tools/check_crash_finder.py`
- `flutter analyze --no-fatal-infos`
- `flutter test` (Guide remote navigation tests সহ)
- `flutter build apk --release --target-platform android-arm,android-arm64`

**দ্রষ্টব্য:** এখানে Flutter SDK নেই; APK compile বা বাস্তব Haier TV-তে পরীক্ষা করা সম্ভব হয়নি। GitHub Actions দিয়ে Build করে TV রিমোটে পরীক্ষা করুন।
