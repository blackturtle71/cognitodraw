plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bcnai.cognitodraw"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.bcnai.cognitodraw"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            proguardFiles("proguard-rules.pro")
            // Controlled pilot builds still use the debug signing config.
            // Replace this before any public or production distribution.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    testOptions.unitTests.all {
        it.systemProperty("mobile.bundle", rootProject.projectDir.parentFile.resolve("assets/models/dinov2").absolutePath)
        providers.gradleProperty("mobileReferenceDir").orNull?.let { reference ->
            it.systemProperty("mobile.references", reference)
        }
    }
}

val mobileReferenceDir = providers.gradleProperty("mobileReferenceDir").orNull
if (mobileReferenceDir != null) {
    android.sourceSets.getByName("androidTest").assets.srcDir(mobileReferenceDir)
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.31.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}
