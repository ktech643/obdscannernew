package com.torque.torque_obd2

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Vendor battery-optimisation screens. SPEC §9.3.
 *
 * Xiaomi/MIUI, Oppo/Realme ColorOS, Vivo Funtouch, Huawei EMUI, Samsung,
 * OnePlus, and the HiOS brands (Tecno/Infinix/itel) all kill foreground
 * services regardless of Android policy. These dominate the PK/IN/MENA market,
 * so the app must be able to open the right screen instead of just telling the
 * user "your phone is killing the app".
 *
 * Each entry is a best-effort ComponentName. A manufacturer can rename a screen
 * between ROM releases, so an intent is only returned when its package is
 * actually installed — the "Fix this" button never opens a dead screen. When
 * nothing resolves, the UI falls back to dontkillmyapp.com/{brand}.
 */
object BatteryOptimization {

    /** A vendor screen that may or may not exist on this ROM. */
    data class VendorIntent(
        val packageName: String,
        val label: String,
        val component: ComponentName?,
        val rawAction: String?,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "package" to packageName,
            "label" to label,
            "component" to component?.flattenToString(),
            "action" to rawAction,
        )

        fun toIntent(): Intent? {
            val i = when {
                component != null -> Intent().setComponent(component)
                rawAction != null -> Intent(rawAction)
                else -> return null
            }
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return i
        }
    }

    /** Returns the vendor intent for this device, or null when none applies. */
    fun intentFor(context: Context): VendorIntent? {
        val info = when {
            Build.MANUFACTURER.contains("xiaomi") -> xiaomi()
            Build.MANUFACTURER.contains("redmi") -> xiaomi()
            Build.MANUFACTURER.contains("oppo") -> colorOs()
            Build.MANUFACTURER.contains("realme") -> colorOs()
            Build.MANUFACTURER.contains("vivo") -> vivo()
            Build.MANUFACTURER.contains("huawei") -> huawei()
            Build.MANUFACTURER.contains("honor") -> huawei()
            Build.MANUFACTURER.contains("samsung") -> samsung()
            Build.MANUFACTURER.contains("oneplus") -> oneplus()
            Build.MANUFACTURER.contains("tecno") -> hios()
            Build.MANUFACTURER.contains("infinix") -> hios()
            Build.MANUFACTURER.contains("itel") -> hios()
            else -> null
        } ?: return null

        // Only offer a screen whose package is present on this ROM.
        return if (isInstalled(context, info.packageName)) info else null
    }

    private fun isInstalled(context: Context, pkg: String): Boolean =
        try {
            context.packageManager.getPackageInfo(pkg, 0) != null
        } catch (_: Exception) {
            false
        }

    private fun xiaomi() = VendorIntent(
        "com.miui.securitycenter",
        "Xiaomi — Autostart",
        ComponentName(
            "com.miui.securitycenter",
            "com.miui.permcenter.autostart.AutoStartManagementActivity",
        ),
        null,
    )

    private fun colorOs() = VendorIntent(
        "com.coloros.safecenter",
        "Oppo/Realme — Startup manager",
        ComponentName(
            "com.coloros.safecenter",
            "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        ),
        null,
    )

    private fun vivo() = VendorIntent(
        "com.vivo.permissionmanager",
        "Vivo — Background startup",
        ComponentName(
            "com.vivo.permissionmanager",
            "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        ),
        null,
    )

    private fun huawei() = VendorIntent(
        "com.huawei.systemmanager",
        "Huawei — Startup manager",
        ComponentName(
            "com.huawei.systemmanager",
            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        ),
        null,
    )

    private fun samsung() = VendorIntent(
        "com.samsung.android.lool",
        "Samsung — App battery",
        ComponentName(
            "com.samsung.android.lool",
            "com.samsung.android.sm.ui.battery.BatteryActivity",
        ),
        null,
    )

    private fun oneplus() = VendorIntent(
        "com.oneplus.security",
        "OnePlus — Background apps",
        ComponentName(
            "com.oneplus.security",
            "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
        ),
        null,
    )

    private fun hios() = VendorIntent(
        "com.transsion.phonemanager",
        "Tecno/Infinix — Autostart",
        ComponentName(
            "com.transsion.phonemanager",
            "com.transsion.phonemanager.clean.activity.autostart.AutoStartActivity",
        ),
        null,
    )
}
