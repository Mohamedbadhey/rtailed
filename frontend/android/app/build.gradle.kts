plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.retail_management"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Manually set the NDK version

    compileOptions {
        isCoreLibraryDesugaringEnabled = true // Correct Kotlin DSL property
        sourceCompatibility = JavaVersion.VERSION_11 // Use Java 11 for better compatibility
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
       jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.retail_management"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}