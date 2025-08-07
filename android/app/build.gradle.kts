import java.util.Properties // Don't forget this import!
import java.io.File // Also needed for File operations

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.app.viperwallet"
    // Use .toInt() for Flutter SDK versions in Kotlin DSL
    compileSdk = flutter.compileSdkVersion.toInt()
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.app.viperwallet"
        // Use .toInt() for Flutter SDK versions in Kotlin DSL
        minSdk = flutter.minSdkVersion.toInt()
        targetSdk = flutter.targetSdkVersion.toInt()
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    // --- You MUST add this signingConfigs block back! ---
    // Load properties from key.properties
    // Define the path to your key.properties file.
    // Adjust this path based on where you placed your key.properties file.
    //
    // Option 1 (Recommended): If key.properties is in your Flutter project root (e.g., next to pubspec.yaml)
    val flutterProjectRoot = rootProject.projectDir.parentFile
    val keyPropertiesFile = File(flutterProjectRoot, "key.properties")

    // Option 2 (Alternative): If key.properties is inside the 'android/' directory
    // val keyPropertiesFile = File(rootProject.projectDir, "key.properties")


    val keyProperties = Properties()
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { keyProperties.load(it) }
    } else {
        // IMPORTANT: For release builds, this is a critical error.
        // You might want to make this a hard failure or ensure the file exists.
        println("WARNING: key.properties file not found at ${keyPropertiesFile.absolutePath}")
        println("Ensure your key.properties is in the Flutter project root or adjust the path.")
    }

    signingConfigs {
        create("release") {
            // These property names must match exactly what's in your key.properties file.
            val storeFilePath = keyProperties.getProperty("MYAPP_RELEASE_STORE_FILE")
            val storePass = keyProperties.getProperty("MYAPP_RELEASE_STORE_PASSWORD")
            val keyAliasName = keyProperties.getProperty("MYAPP_RELEASE_KEY_ALIAS")
            val keyPass = keyProperties.getProperty("MYAPP_RELEASE_KEY_PASSWORD")

            // Ensure all properties are available before applying them
            if (storeFilePath != null && storePass != null && keyAliasName != null && keyPass != null) {
                storeFile = file(storeFilePath)
                storePassword = storePass
                keyAlias = keyAliasName
                keyPassword = keyPass
            } else {
                // If release signing properties are missing, this will likely cause a build failure
                // later if a signing config cannot be fully applied.
                println("ERROR: Missing one or more release signing properties in key.properties.")
                // You could throw a GradleException here to fail early if properties are mandatory:
                // throw GradleException("Release signing properties are missing. Cannot build release APK.")
            }
        }
    }
    // --- End of re-added signingConfigs block ---

    buildTypes {
        release {
            isDebuggable = false
            // This line is now correct, assuming the 'release' signingConfig is defined above
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            isDebuggable = true
            // debug builds usually use the default debug signingConfig automatically
            // You can explicitly set it if needed, but it's often not necessary.
            // signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}