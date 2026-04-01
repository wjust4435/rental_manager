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
        // Updated to use the correct string format to resolve the jvmTarget deprecation
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
        // Use create() to explicitly define the release configuration in Kotlin DSL
        create("release") {
            // Check for CI environment variable properly to fix the Boolean type mismatch
            if (System.getenv("CI") != null) {
                val projectDir = System.getenv("CI_PROJECT_DIR")
                // Use '=' for assignments to fix the "Expecting an element" errors
                storeFile = file("$projectDir/.gitlab/secure_files/rental_manager_release.jks")
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            } else {
                // Local Build Path [cite: 8]
                storeFile = file("your_local_path_here")
                storePassword = "your_local_password"
                keyAlias = "rental_manager_alias"
                keyPassword = "your_local_password"
            }
        }
    }

    buildTypes {
        release {
            // Fixes the unresolved reference for signingConfigs [cite: 9]
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