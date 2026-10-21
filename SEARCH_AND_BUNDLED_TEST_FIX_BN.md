# Live TV Remote v1.1.7 — Search Bar + Bundled JSON Test Diagnostics

## নতুন TV Search Bar

চ্যানেল গাইড খোলার পর: প্রথম চ্যানেলে `↑` চাপলে Search Bar নির্বাচন হবে; `OK` চাপলে TV keyboard দিয়ে লিখুন। Search Bar নির্বাচন থেকে `↑` চাপলে ওপরের action toolbar-এ যাবেন। Toolbar থেকে `↓` চাপলে Search Bar-এ এবং আবার `↓` চাপলে channel results-এ যাবেন।

- Search `name`, `group`, এবং 1-based channel number দিয়ে কাজ করে।
- `Deepto`, `Sports`, `News`, বা বাংলা নাম লিখে খুঁজতে পারবেন।
- একাধিক শব্দ দিলে সবগুলো মিলে এমন চ্যানেল দেখাবে।
- Favorites-only filter এবং Search একইসঙ্গে ব্যবহার করা যাবে।
- TV keyboard-এ Search/Done দিলে remote focus আবার Search Bar-এ ফিরবে।
- Search Bar-এ থাকাকালে Backspace/Delete দিয়ে query মুছে দিতে পারবেন (keyboard খোলা না থাকলে)।
- Search শুধু অ্যাপে লোড হওয়া চ্যানেল ফিল্টার করে, GitHub JSON-এ কিছু পরিবর্তন করে না।
- GitHub Auto Sync ও Keep Screen Awake পূর্বের মতো থাকবে।

## ব্যর্থ হওয়া দুইটি bundled_channels_test সম্পর্কে

আপনার দেওয়া লগের সংক্ষিপ্ত summary-তে `2 failed` আছে, কিন্তু expected/actual values নেই। তাই কী কারণে টেস্ট দুটি ফেল করেছে, তা নিশ্চিতভাবে বলা সম্ভব নয়। এই সংশোধনে:

1. Flutter-এর `rootBundle.loadString('assets/channels.json')` থেকে asset পড়া হচ্ছে; working-directory নির্ভর `File('assets/channels.json')` বাদ।
2. JSON snapshot ৫১৩টি, stream URL ৫১৩টি, সবগুলো distinct — CI-তে Python preflight verify করা হবে।
3. দুইটি Flutter test-এ actual channel count ও URL order-এর নির্দিষ্ট check যুক্ত আছে; ভবিষ্যতে কোনো entry বাদ পড়লে বিস্তারিত কারণ পাওয়া সহজ হবে।
4. `JsonChannelParser`-এ `source: /home/runner/...` local provenance path কখনো HTTP stream হিসেবে ব্যবহার হবে না। মূল absolute URL-এর লেখা অক্ষত থাকবে।
5. GitHub Actions এখন `flutter test -r expanded` চালাবে, তাই full failure output পাওয়া যাবে।

## GitHub APK Build

সম্পূর্ণ ZIP-এর ভেতরের `live_tv_remote` ফোল্ডারের ফাইলগুলো GitHub repo root-এ দিন (ZIP-এর বাইরে আলাদা nested folder তৈরি করবেন না)।

Actions → Android TV APK → Run workflow

Unit test ব্যর্থ হলে Actions logs থেকে **প্রথম failure message + Expected/Actual** পাঠাবেন। শুধু `2 tests failed` সারসংক্ষেপ যথেষ্ট নয়।

## পরীক্ষা সীমাবদ্ধতা

এই environment-এ Flutter/Dart SDK নেই। Python preflight, asset count, ZIP integrity এবং সোর্সের statically check করা হয়েছে; বাস্তবে `flutter test` / `flutter build apk` রান করা যায়নি।
