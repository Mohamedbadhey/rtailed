import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.kobciye.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Manually set the NDK version - supports 16 KB pages

    compileOptions {
        isCoreLibraryDesugaringEnabled = true // Correct Kotlin DSL property
        sourceCompatibility = JavaVersion.VERSION_11 // Use Java 11 for better compatibility
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
       jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.kobciye.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        
        // Support for 16 KB memory page sizes (required by Google Play from Nov 1, 2025)
        // NDK r27+ includes 16 KB page size support
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64"))
        }
    }
    
    // Configure for 16 KB page size support
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
        resources {
            // Exclude unnecessary files to reduce APK size
            excludes += listOf("/META-INF/{AL2.0,LGPL2.1}")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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