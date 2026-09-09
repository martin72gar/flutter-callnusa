plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.callnusa.callnusa_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.callnusa.mobile"
        // Liblinphone and the Telecom APIs used here require Android 6.0+.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Flavors mirror lib/main_<flavor>.dart and .env.<flavor>, so all three can
    // be installed side by side on one device.
    flavorDimensions += "env"
    productFlavors {
        create("development") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "CallNusa Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "CallNusa Staging")
        }
        create("production") {
            dimension = "env"
            resValue("string", "app_name", "CallNusa")
        }
    }

    signingConfigs {
        create("release") {
            // Populated from android/key.properties, which is git-ignored.
            val props = java.util.Properties()
            val propsFile = rootProject.file("key.properties")
            if (propsFile.exists()) {
                propsFile.inputStream().use { props.load(it) }
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storeFile = props.getProperty("storeFile")?.let { file(it) }
                storePassword = props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing when key.properties is absent, so a
            // fresh clone can still run `flutter build apk --release`.
            signingConfig = if (rootProject.file("key.properties").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        // The Liblinphone AAR ships several .so variants; keep them all so the
        // universal APK works on every ABI.
        jniLibs.useLegacyPackaging = false
    }
}

dependencies {
    // Liblinphone — AGPL-3.0. This is the dependency that makes the whole app
    // GPL-3.0-only; see NOTICE.
    implementation("org.linphone:linphone-sdk-android:5.4.+")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
