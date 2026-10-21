# Live TV Remote — Keep Screen Awake (v1.1.6)

## সমস্যাটি
লাইভ টিভি দেখার সময় রিমোটে বোতাম না চাপলে TV-র সাধারণ inactivity/ambient timeout চালু হয়।

## প্রজেক্টে সমাধান
- Kotlin `MainActivity`-এর `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON` ব্যবহার করা হয়েছে।
- Flutter থেকে Native MethodChannel `livetv_remote/screen_awake`-এ `setKeepAwake(true/false)` পাঠায়।
- কোনো চ্যানেল প্লে বা বাফারিং চললে স্ক্রিন জেগে থাকবে, চ্যানেল বদলানোর সময়ও থাকবে।
- অ্যাপ ব্যাকগ্রাউন্ডে/বন্ধ হলে, কোনো চ্যানেল না থাকলে, অথবা প্লেব্যাক error হলে flag বন্ধ হয়ে যাবে।
- আলাদা WAKE_LOCK permission বা নতুন Flutter plugin প্রয়োজন নেই।
- Crash Finder লগে `SCREEN_AWAKE` ইভেন্ট যুক্ত হয়েছে।

## Android 11 TV-র সীমাবদ্ধতা
কিছু TV-র `Inattentive Sleep`, `Sleep Timer`, `No Signal Auto Power Off`, `Eco Mode` অথবা নির্মাতার Auto Standby সেটিং `FLAG_KEEP_SCREEN_ON`-কেও অগ্রাহ্য করতে পারে। এগুলো TV-র Settings > Power/Energy Saver/Sleep Timer থেকে বন্ধ বা বাড়াতে হতে পারে। বিশেষত টিভি নিজে যদি Sleep/Power Off timer ব্যবহার করে, অ্যাপের পক্ষে সেটি সবসময় বন্ধ করা যায় না।

## APK বিল্ড
1. ZIP-এর ফাইল GitHub-এ আপডেট করুন।
2. Actions > Android TV APK > Run workflow।
3. Artifact: Live-TV-Remote-AndroidTV-ARM32-ARM64-Universal থেকে APK নিন।
4. TV-তে install/update করে Live Channel চালিয়ে আগে যে সময়ের পর sleep হতো, তার চেয়ে বেশি সময় পরীক্ষা করুন।

## যাচাই
Flutter SDK না থাকায় এখানে Android APK build চালানো সম্ভব হয়নি। `flutter analyze`, `flutter test` এবং বাস্তব TV পরীক্ষা GitHub Actions/TV-তে করতে হবে।

## রেফারেন্স
- https://developer.android.com/develop/background-work/background-tasks/awake/screen-on
- https://source.android.google.cn/docs/core/power/tv-standby?hl=en
