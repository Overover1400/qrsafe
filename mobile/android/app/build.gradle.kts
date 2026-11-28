import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties, which is never committed.
// CI writes that file from repository secrets before a Play build. Without it the
// release build falls back to the debug key, so `flutter build apk --release`
// still produces an APK she can sideload for testing — it just cannot go to Play.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasUploadKey = keystorePropertiesFile.exists()

android {
    namespace = "com.qrsafe.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.qrsafe.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 is off for release, and that is not laziness. Shrinking broke
            // the scanner: starting the camera died with a NullPointerException
            // inside obfuscated plugin code ("g5.e.a(c5.b)"), because R8 strips
            // classes ML Kit and the camera plugin only reach by reflection.
            // Keep rules could carve out an exception, but they would have to be
            // guessed one CI round at a time against a device we cannot attach a
            // debugger to, and a working scanner is worth about 4 MB.
            isMinifyEnabled = false
            isShrinkResources = false
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

dependencies {
    // Google Play rejects every update whose native libraries are not 16 KB
    // page aligned. The two that were not are Google's own, pulled in by
    // mobile_scanner: libimage_processing_util_jni.so from CameraX (4 KB until
    // camera-core 1.4.0) and libbarhopper_v3.so from the bundled ML Kit
    // barcode model. Naming newer versions here wins the Gradle version
    // conflict without forking the plugin. Check alignment after any bump:
    // tool/check_16kb.py reads the ELF program headers out of the .aab.
    implementation("androidx.camera:camera-core:1.7.0")
    implementation("androidx.camera:camera-camera2:1.7.0")
    implementation("androidx.camera:camera-lifecycle:1.7.0")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
}
