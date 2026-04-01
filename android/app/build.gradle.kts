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
        // Updated to use the recommended string format for jvmTarget
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.wjust4435.rental_manager"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Fix: Kotlin requires explicit null check for String to Boolean conversion
            if (System.getenv("CI") != null) {
                // Fix: Use '=' for assignments in Kotlin DSL
                val projectDir = System.getenv("CI_PROJECT_DIR")
                storeFile = file("$projectDir/.gitlab/secure_files/rental_manager_release.jks")
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            } else {
                // Local Build Path
                storeFile = file("your_local_path_here")
                storePassword = "your_local_password"
                keyAlias = "rental_manager_alias"
                keyPassword = "your_local_password"
            }
        }
    }

    buildTypes {
        release {
            // Fix: Use the correct reference to the signingConfig created above
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
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