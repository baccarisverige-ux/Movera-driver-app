plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "se.movera.driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "se.movera.driver"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] =
            System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
        // Owner 2026-11-12 (Test Lab device test): the on-phone checks in
        // integration_test/ run through Flutter's JUnit runner
        // (android/app/src/androidTest). Only the androidTest APK uses it;
        // the app APK is unchanged.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        create("release") {
            val storePath = System.getenv("MOVERA_UPLOAD_STORE_FILE")
            if (!storePath.isNullOrBlank()) {
                storeFile = file(storePath)
                storePassword = System.getenv("MOVERA_UPLOAD_STORE_PASSWORD") ?: ""
                keyAlias = System.getenv("MOVERA_UPLOAD_KEY_ALIAS") ?: ""
                keyPassword = System.getenv("MOVERA_UPLOAD_KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            val releaseStore = signingConfigs.getByName("release").storeFile
            val preview = System.getenv("MOVERA_ALLOW_DEBUG_SIGNED_PREVIEW") == "true"
            signingConfig = when {
                releaseStore != null -> signingConfigs.getByName("release")
                preview -> signingConfigs.getByName("debug")
                else -> signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val requestsRelease = allTasks.any { task ->
        task.project == project && (
            task.name == "assembleRelease" ||
            task.name == "bundleRelease" ||
            task.name == "packageRelease" ||
            task.name.startsWith("signRelease")
        )
    }
    if (!requestsRelease) {
        return@whenReady
    }
    val hasStore = !System.getenv("MOVERA_UPLOAD_STORE_FILE").isNullOrBlank()
    val preview = System.getenv("MOVERA_ALLOW_DEBUG_SIGNED_PREVIEW") == "true"
    if (!hasStore && !preview) {
        throw GradleException(
            "Production Android release refuses debug signing. " +
                "Set MOVERA_UPLOAD_STORE_FILE, MOVERA_UPLOAD_STORE_PASSWORD, " +
                "MOVERA_UPLOAD_KEY_ALIAS and MOVERA_UPLOAD_KEY_PASSWORD. " +
                "An internal preview must set MOVERA_ALLOW_DEBUG_SIGNED_PREVIEW=true " +
                "and is not a production artifact.",
        )
    }
    if (!hasStore && preview) {
        logger.lifecycle(
            "MOVERA: debug-signed INTERNAL PREVIEW. This is not a production release.",
        )
    }
    if (System.getenv("MOVERA_REQUIRE_MAPS_KEY") == "true" &&
        System.getenv("GOOGLE_MAPS_API_KEY").isNullOrBlank()
    ) {
        throw GradleException(
            "Native release requires GOOGLE_MAPS_API_KEY. Refusing to ship a maps build with an empty key.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Test APK only (assembleAndroidTest); never packed into the app.
    androidTestImplementation("androidx.test:runner:1.2.0")
    androidTestImplementation("androidx.test:rules:1.2.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.3.0")
}
