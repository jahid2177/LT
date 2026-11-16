plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Stable release signing. GitHub Actions decodes the keystore from repository
// secrets and passes its location here. Every release must be signed with the
// SAME key, otherwise Android refuses to install it over the previous version
// (and in-app updates cannot work). Without the key, the debug key is used so
// local/diagnostic builds still succeed.
val releaseKeystoreFile = System.getenv("ANDROID_KEYSTORE_PATH")
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }
val releaseKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: ""
val hasReleaseKeystore = releaseKeystoreFile?.exists() == true &&
    releaseKeystorePassword.isNotEmpty()

android {
    namespace = "com.example.live_tv_remote"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
    defaultConfig {
        applicationId = "com.example.live_tv_remote"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = releaseKeystorePassword
                keyAlias = "livetv"
                keyPassword = releaseKeystorePassword
                storeType = "pkcs12"
            }
        }
    }
    buildTypes {
        debug {
            // Diagnostic build can coexist with the normal release installation.
            applicationIdSuffix = ".diagnostic"
        }
        release {
            // Sideload distribution through GitHub Releases, not the Play Store.
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKeystore) "release" else "debug"
            )
            // R8 is active in Flutter release builds. The rules below tell it that
            // AndroidX WindowManager's OEM-provided optional APIs may be absent.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
