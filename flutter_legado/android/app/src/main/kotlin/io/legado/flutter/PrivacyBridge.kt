package io.legado.flutter

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** 逐次生物认证绑定 Keystore 加密操作，系统成功回调本身不授予权限。— Codex + UI */
class PrivacyBridge(private val activity: FragmentActivity) {
    private val alias = "openlegado.privacy.biometric"
    private val prefs get() = activity.getSharedPreferences("privacy_biometric", 0)
    private val token = "OpenLegadoPrivacyCredential".toByteArray(Charsets.UTF_8)
    private var pending: MethodChannel.Result? = null

    private fun store() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private fun clear() {
        store().deleteEntry(alias)
        if (!prefs.edit().clear().commit()) throw IllegalStateException("快捷凭据清理失败")
    }
    private fun status(): String = when (BiometricManager.from(activity).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
        BiometricManager.BIOMETRIC_SUCCESS -> "available"
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "notEnrolled"
        BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "noHardware"
        else -> "unavailable"
    }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "capabilities" -> result.success(mapOf("biometric" to status(), "enrolled" to (store().containsAlias(alias) && prefs.contains("ciphertext"))))
                "enrollBiometric" -> authenticate(true, result)
                "authenticateBiometric" -> authenticate(false, result)
                "clearBiometric" -> { clear(); result.success(true) }
                "permissions" -> result.success(mapOf("notifications" to NotificationManagerCompat.from(activity).areNotificationsEnabled(),
                    "batteryUnrestricted" to activity.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(activity.packageName)))
                "openNotificationSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= 26)
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                    else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
                    activity.startActivity(intent)
                    result.success(true)
                }
                "openBatterySettings" -> { activity.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)); result.success(true) }
                else -> result.notImplemented()
            }
        } catch (_: Exception) { result.error("privacy_unavailable", "系统隐私功能暂不可用", null) }
    }
    private fun authenticate(enroll: Boolean, result: MethodChannel.Result) {
        if (pending != null || status() != "available") { result.success(false); return }
        try {
            if (enroll) {
                clear()
                val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
                generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setUserAuthenticationRequired(true).setInvalidatedByBiometricEnrollment(true).build())
                generator.generateKey()
            }
            val key = store().getKey(alias, null) as? SecretKey ?: run { result.success(false); return }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            if (enroll) cipher.init(Cipher.ENCRYPT_MODE, key)
            else cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, Base64.decode(prefs.getString("iv", ""), Base64.NO_WRAP)))
            pending = result
            val prompt = BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) { finish(false, enroll) }
                override fun onAuthenticationSucceeded(authentication: BiometricPrompt.AuthenticationResult) {
                    try {
                        val authenticated = authentication.cryptoObject?.cipher ?: throw IllegalStateException("缺少认证加密对象")
                        if (enroll) {
                            val encrypted = authenticated.doFinal(token)
                            val written = prefs.edit().putString("ciphertext", Base64.encodeToString(encrypted, Base64.NO_WRAP))
                                .putString("iv", Base64.encodeToString(authenticated.iv, Base64.NO_WRAP)).commit()
                            finish(written, true)
                        } else {
                            val decoded = authenticated.doFinal(Base64.decode(prefs.getString("ciphertext", ""), Base64.NO_WRAP))
                            finish(MessageDigest.isEqual(decoded, token), false)
                        }
                    } catch (_: Exception) { finish(false, enroll) }
                }
            })
            val info = BiometricPrompt.PromptInfo.Builder().setTitle("验证隐私身份")
                .setSubtitle("验证后查看私密内容").setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("使用隐私密码").build()
            prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
        } catch (_: Exception) {
            if (pending != null) finish(false, enroll)
            else { if (enroll) runCatching { clear() }; result.success(false) }
        }
    }
    private fun finish(success: Boolean, enroll: Boolean) {
        val response = pending ?: return
        pending = null
        if (!success && enroll) runCatching { clear() }
        response.success(success)
    }
}
