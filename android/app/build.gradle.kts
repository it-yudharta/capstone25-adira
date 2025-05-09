import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") 
}

android {
    val keystoreProperties = Properties()
    val keystorePropertiesFile = File("C:/Users/USER/resellerapp/android/key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    } else {
        throw GradleException("Keystore properties file not found!")
    }

    val keystoreFilePath = keystoreProperties["storeFile"] as String?
    if (keystoreFilePath.isNullOrEmpty()) {
        throw GradleException("Keystore file path is empty or null!")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = file("C:/Users/USER/resellerapp/android/app/release-key.keystore")
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    namespace = "com.fundrain.resellerapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
    applicationId = "com.fundrain.resellerapp"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = 5
    versionName = "1.0.4"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = false
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}
