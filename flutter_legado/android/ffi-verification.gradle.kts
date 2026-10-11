import groovy.json.JsonSlurper
import java.util.Base64
import javax.inject.Inject
import org.gradle.process.ExecOperations

// 声明任务属性和进程服务，避免执行动作捕获脚本对象而破坏配置缓存。
abstract class LegadoVerifyRustFfi : DefaultTask() {
    @get:Input abstract val rustProfile: Property<String>
    @get:Input abstract val abis: Property<String>
    @get:Input abstract val python: Property<String>
    @get:Input abstract val skipRust: Property<String>
    @get:Input abstract val ciValues: ListProperty<String>
    @get:Input abstract val dartDefines: Property<String>
    @get:Internal abstract val repository: DirectoryProperty
    @get:Inject abstract val processes: ExecOperations

    @TaskAction
    fun verify() {
        if (skipRust.get() == "1") {
            val isCi = ciValues.get().any { it.isNotEmpty() && it.lowercase() != "false" && it != "0" }
            val mock = try {
                dartDefines.get().split(",").filter { it.isNotEmpty() }.map {
                    String(Base64.getDecoder().decode(it), Charsets.UTF_8)
                }.filter { it.startsWith("USE_MOCK=") } == listOf("USE_MOCK=true")
            } catch (failure: IllegalArgumentException) {
                throw GradleException("dart-defines 编码无效，不能跳过 FFI 校验", failure)
            }
            if (rustProfile.get() != "debug" || isCi || !mock) {
                throw GradleException("LEGADO_SKIP_RUST_BUILD=1 仅允许本地 Debug 且 USE_MOCK=true；Release/Profile/CI 必须校验")
            }
            logger.lifecycle("[Legado] 本地 Debug Mock 模式，跳过 Rust FFI 校验")
            return
        }
        val interpreter = python.get()
        val root = repository.get().asFile
        logger.lifecycle("[Legado] Python 3.11+ 校验器：$interpreter；可用 PYTHON 或 -PlegadoPython 指定解释器")
        processes.exec {
            workingDir(root)
            commandLine(interpreter, root.resolve("scripts/dev.py").absolutePath,
                "verify", "ffi", "android", "--profile", rustProfile.get(), "--abis", abis.get())
            environment("PYTHONIOENCODING", "utf-8")
        }
    }
}

// 薄适配：读取同一 ABI 策略，参数化调用 Python；不编译或修复 Rust 产物。
val repositoryRoot = rootProject.projectDir.parentFile.parentFile
val policyText = providers.fileContents(rootProject.layout.projectDirectory.file("../../scripts/tooling/android-policy.json"))
    .asText.get()
val targets = (JsonSlurper().parseText(policyText)
    as Map<*, *>)["targets"] as Map<*, *>
val requestedPlatforms = providers.gradleProperty("target-platform").orNull
val pythonExecutable = providers.gradleProperty("legadoPython")
    .orElse(providers.environmentVariable("PYTHON"))
    .orElse(if (System.getProperty("os.name").lowercase().contains("windows")) "python" else "python3")
    .get()
val skipRustValue = providers.environmentVariable("LEGADO_SKIP_RUST_BUILD").orElse("").get()
val ciEnvironment = listOf("CI", "GITHUB_ACTIONS").map { providers.environmentVariable(it).orElse("").get() }
val encodedDefines = providers.gradleProperty("dart-defines").orElse("").get()

fun requestedAbis(profile: String): List<String> {
    if (requestedPlatforms == null) {
        return targets.filterValues { profile in ((it as Map<*, *>)["features"] as Map<*, *>) }
            .keys.map { it as String }
    }
    val platforms = requestedPlatforms.split(",")
    require(platforms.all { it.isNotBlank() } && platforms.distinct().size == platforms.size) {
        "target-platform 不能包含空项或重复平台"
    }
    return platforms.map { platform ->
        targets.entries.singleOrNull { (it.value as Map<*, *>)["flutterPlatform"] == platform }?.key as? String
            ?: throw GradleException("Rust FFI 不支持 Flutter 平台：$platform")
    }
}

val abisByProfile = listOf("debug", "release").associateWith { requestedAbis(it) }
extra["legadoFfiAbisByProfile"] = abisByProfile

for ((variant, profile) in listOf("Debug" to "debug", "Release" to "release", "Profile" to "release")) {
    val requested = abisByProfile.getValue(profile).joinToString(",")
    val verifier = tasks.register<LegadoVerifyRustFfi>("verify${variant}RustFfiLibs") {
        group = "legado"
        description = "只读校验 $variant 的 Rust FFI 库和来源元数据"
        repository.set(repositoryRoot)
        rustProfile.set(profile)
        abis.set(requested)
        python.set(pythonExecutable)
        skipRust.set(skipRustValue)
        ciValues.set(ciEnvironment)
        dartDefines.set(encodedDefines)
        // 不声明输出或启用任务缓存；每次构建都重新检查当前库和源码。
    }
    tasks.matching { it.name == "pre${variant}Build" }.configureEach { dependsOn(verifier) }
}

// 保留手动入口；构建时由对应 variant 的 preBuild 选择 Debug/Release/Profile。
tasks.register("verifyRustFfiLibs") {
    group = "legado"
    description = "手动校验 Debug Rust FFI；Release 使用 verifyReleaseRustFfiLibs"
    dependsOn("verifyDebugRustFfiLibs")
}
