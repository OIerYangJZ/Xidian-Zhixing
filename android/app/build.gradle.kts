import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val debugSigningProperties = Properties()
val debugSigningFile = rootProject.file("debug-signing.properties")
val hasTeamDebugSigning = debugSigningFile.exists()
if (hasTeamDebugSigning) {
    debugSigningProperties.load(FileInputStream(debugSigningFile))
}

val releaseSigningProperties = Properties()
val releaseSigningFile = rootProject.file("key.properties")
val hasReleaseSigning = releaseSigningFile.exists()
if (hasReleaseSigning) {
    releaseSigningProperties.load(FileInputStream(releaseSigningFile))
}

android {
    namespace = "com.xdutreehole.xdu_treehole_web"
    compileSdk = 36

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.xdutreehole.xdu_treehole_web"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasTeamDebugSigning) {
            create("teamDebug") {
                keyAlias = debugSigningProperties["keyAlias"] as String
                keyPassword = debugSigningProperties["keyPassword"] as String
                storeFile = rootProject.file(debugSigningProperties["storeFile"] as String)
                storePassword = debugSigningProperties["storePassword"] as String
            }
        }
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseSigningProperties["keyAlias"] as String
                keyPassword = releaseSigningProperties["keyPassword"] as String
                storeFile = rootProject.file(releaseSigningProperties["storeFile"] as String)
                storePassword = releaseSigningProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            if (hasTeamDebugSigning) {
                signingConfig = signingConfigs.getByName("teamDebug")
            }
        }
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else if (hasTeamDebugSigning) {
                signingConfigs.getByName("teamDebug")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
