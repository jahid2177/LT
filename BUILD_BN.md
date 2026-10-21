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
