# GitHub Actions 513 vs 511 Channel Count Fix — v1.1.9

**আগের ব্যর্থতা:**
`tools/check_bundled_channels.py`-তে `assert len(channels) == 513` ছিল। আপনার GitHub Actions-এর `assets/channels.json`-এ ৫১১টি এন্ট্রি পাওয়া যাওয়ায় বিল্ড থেমে যায়।

**সমাধান:**
- ৫১৩-এর নির্দিষ্ট বাধ্যবাধকতা সরানো হয়েছে।
- JSON list ফাঁকা কিনা, এন্ট্রির `name` ও `url` আছে কি না, URL HTTP(S) কি না তা পরীক্ষা হবে।
- একই URL বারবার থাকলে সতর্ক বার্তা দেখানো হবে; Dart parser-এর ইচ্ছাকৃত de-duplication অনুযায়ী Flutter test-এ unique URL যাচাই হবে।
- `bundled_channels_test.dart` এখন ফাইলের প্রকৃত চ্যানেল সংখ্যা থেকে প্রত্যাশিত ফল নির্ধারণ করে।
- TV-এর Settings-এ `Use bundled offline channel list` লেখা থাকবে, নির্দিষ্ট সংখ্যা নয়।
- **কোনো চ্যানেল মুছে ফেলা বা পরিবর্তন করা হয়নি।**

**প্রধান চ্যানেল সোর্স:**
https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json

এই URL অ্যাপ চালুর সময় ও পরবর্তী Auto Sync-এ ব্যবহৃত হবে। `assets/channels.json` শুধুমাত্র অফলাইন fallback। বিল্ডের সময় লাইভ GitHub URL-এর বর্তমান সংখ্যা ৫১৩ হতে হবে এমন কোনো শর্ত নেই।

**GitHub-এ আপডেট করতে:** Changed-Files ZIP থেকে ফাইলগুলো Repository-এর একই পথ অনুযায়ী আপলোড করুন। বিদ্যমান `assets/channels.json` ৫১১টি হলে সেটি আগের মতো রাখুন। Actions → Android TV APK → Run workflow।

**যাচাইয়ের সীমা:** Python validator ৫১৩টি ও ৫১১টি উভয় JSON নিয়ে পরীক্ষা করা হয়েছে; Flutter SDK এখানে নেই, তাই `flutter test` ও APK build GitHub Actions-এ চালাতে হবে।
