plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bd_nid_ocr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bd_nid_ocr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    dependencies {
        // google_mlkit_text_recognition ships every non-Latin script recognizer
        // (chinese/devanagari/japanese/korean) as `compileOnly` in its own
        // android/build.gradle — the classes are on the compile classpath but
        // NOT bundled into the APK. bd_nid_ocr's MLKitTextDataSource uses
        // TextRecognitionScript.devanagiri (closest ML Kit script to Bengali),
        // so the consuming app must add the runtime artifact itself, or the
        // app crashes with NoClassDefFoundError on
        // DevanagariTextRecognizerOptions$Builder the moment scan() runs.
        implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
