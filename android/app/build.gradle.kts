plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.wjust4435.rental_manager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.wjust4435.rental_manager"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        release {
            // This logic allows local building AND GitLab CI building
            if (System.getenv("CI")) {
                // GitLab CI Path (Standard for Secure Files)
                storeFile file("${System.getenv("CI_PROJECT_DIR")}/.gitlab/secure_files/rental_manager_release.jks")
                storePassword System.getenv("KEYSTORE_PASSWORD")
                keyAlias System.getenv("KEY_ALIAS")
                keyPassword System.getenv("KEY_PASSWORD")
            } else {
                // Local Build Path (Optional: only if you keep a key.properties locally)
                storeFile file("your_local_path_here")
                storePassword "your_local_password"
                keyAlias "rental_manager_alias"
                keyPassword "your_local_password"
            }
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release // Switched from debug to release
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}