plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ma.ueuromed.euromed_studios"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ma.ueuromed.euromed_studios"
        // Android 7.0 and newer (camera and file plugins need it).
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // DEMO signing key, kept in the repo on purpose: every build (GitHub,
    // Android Studio on any laptop) is signed the same way, so a new APK
    // installs over the old one. Its password is public. Before a Play Store
    // release, replace it with a private key kept outside the repo.
    signingConfigs {
        create("demo") {
            storeFile = file("demo-signing.keystore")
            storePassword = "euromed-demo"
            keyAlias = "euromed-demo"
            keyPassword = "euromed-demo"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("demo")
        }
        release {
            signingConfig = signingConfigs.getByName("demo")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
