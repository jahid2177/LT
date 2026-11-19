# Windows EXE (Live TV Remote for Windows)

এই প্রজেক্টটি Flutter-এ লেখা, তাই একই কোড থেকে Windows (x64) অ্যাপ তৈরি হয়।
Windows EXE শুধু Windows মেশিনে (Visual Studio C++ টুলচেইন দিয়ে) বিল্ড করা যায়,
তাই এটি GitHub Actions-এর `windows-latest` মেশিনে স্বয়ংক্রিয়ভাবে বিল্ড হয়।

## কীভাবে EXE পাবেন

1. এই ফাইলগুলো রিপোতে আপলোড করুন (main ব্রাঞ্চে)।
2. **Android TV APK** ওয়ার্কফ্লো সফল হলে **Windows EXE** ওয়ার্কফ্লো নিজে থেকেই চলবে।
   চাইলে হাতে চালাতে পারেন: **Actions → Windows EXE → Run workflow**।
3. রান শেষ হলে (~১৫–২৫ মিনিট) রানের পেজের নিচে **Artifacts** থেকে ডাউনলোড করুন:
   - `LiveTVRemote-Windows-Setup` → `LiveTVRemote-Setup-<version>.exe` (ইনস্টলার, Start menu + Desktop শর্টকাট)
   - `LiveTVRemote-Windows-x64-Portable` → ZIP; আনজিপ করে `LiveTVRemote.exe` চালান (ইনস্টল ছাড়া)
4. ওই কমিট/ভার্সনের GitHub Release থাকলে এই দুটি ফাইল Release-এও যুক্ত হয়ে যাবে।

> Setup.exe সাইন করা নয়, তাই প্রথমবার Windows SmartScreen "Windows protected your PC" দেখাতে পারে →
> **More info → Run anyway**।

## Windows-এ কী কী কাজ করে

| ফিচার | Windows |
|---|---|
| GitHub `channels.json` (প্রাইমারি সোর্স), ২ মিনিট পরপর রিফ্রেশ | ✅ একই রকম |
| HLS `.m3u8` / MP4 / DASH প্লেব্যাক | ✅ libmpv (media_kit) দিয়ে |
| ফেভারিট, সার্চ, শেষ চ্যানেল মনে রাখা, M3U/JSON ইমপোর্ট | ✅ |
| Keep Screen Awake (চ্যানেল চলার সময় স্ক্রিন বন্ধ হবে না) | ✅ Windows API দিয়ে |
| Crash Finder | ✅ লগ ফাইল: `%LOCALAPPDATA%\LiveTvRemote\crash_log.txt` (Notepad-এ খোলে) |
| অটো-আপডেট | ❌ (Android APK-এর জন্য); Windows-এ নতুন Setup.exe চালিয়ে আপডেট করুন |

## কিবোর্ড

| কী | কাজ |
|---|---|
| ↑ / ↓ | আগের / পরের চ্যানেল (গাইড খোলা থাকলে লিস্টে নড়াচড়া) |
| Page Up / Page Down | চ্যানেল + / চ্যানেল − |
| ← / → | গাইড খোলা / চ্যানেল ইনফো |
| Enter / Space | গাইড / চ্যানেল চালু |
| Esc | পেছনে (দুবার চাপলে অ্যাপ বন্ধ) |
| 0–9 | চ্যানেল নম্বর |
| F | ফেভারিট |
| M | সেটিংস |
| **F11** বা **Alt+Enter** | ফুল স্ক্রিন চালু/বন্ধ |

## ফাইলগুলো

- `windows_app/main_windows.dart` — Windows এন্ট্রি পয়েন্ট (ভিডিও ব্যাকএন্ড, স্ক্রিন জাগিয়ে রাখা, ফুল স্ক্রিন, লগ)
- `windows_app/prepare_windows.py` — জেনারেট হওয়া Windows runner ঠিক করে (exe নাম `LiveTVRemote.exe`, টাইটেল, আইকন, ম্যাক্সিমাইজড উইন্ডো)
- `windows_app/installer.iss` — Inno Setup ইনস্টলার স্ক্রিপ্ট
- `.github/workflows/windows-exe.yml` — বিল্ড ওয়ার্কফ্লো
- `lib/main.dart` — স্টার্টআপ কোড `runLiveTvApp()`-এ সরানো হয়েছে যাতে Windows এন্ট্রি পয়েন্ট একই কোড ব্যবহার করতে পারে (Android আচরণ অপরিবর্তিত)
- `analysis_options.yaml` — Android বিল্ডের analyze থেকে `windows_app/` বাদ

Android APK বিল্ডে কোনো নতুন প্যাকেজ যোগ হয়নি; Windows-এর প্যাকেজগুলো
(`video_player_media_kit`, `media_kit_libs_windows_video`, `ffi`) শুধু Windows ওয়ার্কফ্লোতে যোগ হয়।
