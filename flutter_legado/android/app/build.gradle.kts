plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

apply(from = "../ffi-verification.gradle.kts")

@Suppress("UNCHECKED_CAST")
val ffiAbisByProfile = extra["legadoFfiAbisByProfile"] as Map<String, List<String>>
val splitPerAbi = providers.gradleProperty("split-per-abi").orNull == "true"

// CI通过环境注入，本地读取已忽略的配置；Debug不依赖发行密钥。
val releaseProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) {
        propertiesFile.reader(Charsets.UTF_8).use { load(it) }
    }
}
fun releaseSigningValue(environment: String, property: String): String? =
    (providers.environmentVariable(environment).orNull
        ?: releaseProperties.getProperty(property))?.takeIf { it.isNotEmpty() }

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

    signingConfigs {
        create("release") {
            storeFile = releaseSigningValue("ANDROID_KEYSTORE_PATH", "storeFile")?.let { file(it) }
            storePassword = releaseSigningValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
            keyAlias = releaseSigningValue("ANDROID_KEY_ALIAS", "keyAlias")
            keyPassword = releaseSigningValue("ANDROID_KEY_PASSWORD", "keyPassword")
        }
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
            // 发行构建使用固定证书，不回退到Debug证书。
            signingConfig = signingConfigs.getByName("release")
        }
        getByName("profile") {
            if (!splitPerAbi) {
                ndk { abiFilters += ffiAbisByProfile.getValue("release") }
            }
        }
    }
}

// AGP会把不完整配置视作无签名构建，只在Release入口检查必填项。
val releaseSigningConfigured = android.signingConfigs.getByName("release").let {
    it.storeFile?.isFile == true && !it.storePassword.isNullOrEmpty() &&
        !it.keyAlias.isNullOrEmpty() && !it.keyPassword.isNullOrEmpty()
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        check(releaseSigningConfigured) {
            "Release缺少签名配置或密钥文件，请填写android/key.properties或对应ANDROID_KEY*环境变量。"
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
    // 生物识别逐次认证与 Keystore 绑定，沿用参考版稳定依赖。
    implementation("androidx.biometric:biometric:1.1.0")
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
