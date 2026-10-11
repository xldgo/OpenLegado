plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

apply(from = "../ffi-verification.gradle.kts")

@Suppress("UNCHECKED_CAST")
val ffiAbisByProfile = extra["legadoFfiAbisByProfile"] as Map<String, List<String>>
val splitPerAbi = providers.gradleProperty("split-per-abi").orNull == "true"

android {
    namespace = "io.legado.flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 通知插件要求消费者启用 core library desugaring。
        isCoreLibraryDesugaringEnabled = true
    }

    sourceSets {
        getByName("main") {
            // Rust FFI .so 动态库（由独立 Python 构建命令生成）
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    defaultConfig {
        applicationId = "io.legado.flutter_legado"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // 与校验请求保持一致，避免将其他模式的 armv7 库装入 Debug 包。
            if (!splitPerAbi) {
                ndk { abiFilters += ffiAbisByProfile.getValue("debug") }
            }
        }
        release {
            // 分 ABI 构建由 Flutter splits 选择，避免与 NDK 过滤器冲突。
            if (!splitPerAbi) {
                ndk { abiFilters += ffiAbisByProfile.getValue("release") }
            }
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("profile") {
            if (!splitPerAbi) {
                ndk { abiFilters += ffiAbisByProfile.getValue("release") }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // AndroidX Media（MediaSessionCompat + 音频焦点管理）
    implementation("androidx.media:media:1.7.0")
    // [V-B3] 视频悬浮窗服务自建播放器（VideoPlayService）：
    // Flutter video_player 的纹理归 Flutter 引擎渲染面，无法进入系统 overlay，
    // 故原生 side 直接使用 Media3 ExoPlayer + SurfaceView（对齐原版 GSYVideoPlayer 形态）。
    // 版本与工程解析图一致（与 video_player_android 2.12.2 声明的 1.9.2 完全一致）。
    implementation("androidx.media3:media3-exoplayer:1.9.2")
    // 通知插件的 core library desugaring 依赖。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // [P1-2] 本地 JVM 单测（StorageBridge bytes 参数解析回归）：
    // ./gradlew :app:testDebugUnitTest --tests "io.legado.flutter.StorageBridgeBytesArgumentTest"
    testImplementation("junit:junit:4.12")
}
