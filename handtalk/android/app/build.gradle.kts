plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.handtalk.handtalk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // TFLite model files should not be compressed
    aaptOptions {
        noCompress += "tflite"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.handtalk.handtalk"
        // minSdk 21 required for sqflite & flutter_tts
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex for large app
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Signing with debug keys for now
            signingConfig = signingConfigs.getByName("debug")
            
            // Enable shrinking & obfuscation for smaller APK
            isMinifyEnabled = true
            isShrinkResources = true
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
