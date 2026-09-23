import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import java.io.File

plugins {
    kotlin("jvm") version "2.2.20"
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20"
    id("org.jetbrains.compose") version "1.8.2"
}

group = "com.maxstream"
version = "0.1.0"

// Windows laptop app — its own desktop UX. Shares the com.maxstream.app package
// with the TV/mobile clients but does NOT use Google services (unavailable on
// desktop); the data layer is a swappable interface so a real backend (the same
// REST API the phone/Chromecast clients use) can be wired in later.
kotlin {
    jvmToolchain(17)
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

dependencies {
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation(compose.materialIconsExtended)
    implementation(compose.ui)
    implementation(compose.foundation)
    implementation(compose.runtime)

    // Stream extraction (shared with the TV app): OkHttp + org.json.
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.json:json:20240303")

    // Coroutines incl. Swing (Dispatchers.Main) for the shared extractors.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.9.0")

    // Playback engine (VLCJ — requires libvlc from the VLC desktop install).
    implementation("uk.co.caprica:vlcj:4.8.3")

    // Async image loading for TMDB posters/backdrops (Coil 3 = KMP/desktop).
    // Pin to 3.2.x: newer Coil ships kotlin-stdlib 2.4+ metadata, which the
    // Kotlin 2.2 compiler here cannot read.
    implementation("io.coil-kt.coil3:coil-compose:3.2.0")
    implementation("io.coil-kt.coil3:coil-network-okhttp:3.2.0")
}

// Promotes the packaged app to the user's Desktop (shortcut) and launches it.
// Run after a successful `packageMsi` / manual MSI install:
//   gradlew desktop:promoteAndLaunch
tasks.register<DefaultTask>("promoteAndLaunch") {
    group = "maxstream"
    description = "Places a MaxStream shortcut on the Desktop and launches the app."
    doLast {
        val exeCandidates = listOf(
            "C:\\Program Files\\MaxStream\\MaxStream.exe",
            System.getenv("LOCALAPPDATA") + "\\Programs\\MaxStream\\MaxStream.exe",
        )
        val exe = exeCandidates.firstOrNull { File(it).exists() }
            ?: throw GradleException("MaxStream.exe not found after install. Run packageMsi (or the MSI) first.")
        val script = layout.projectDirectory.file("..\\scripts\\desktop-shortcut.ps1").asFile
        require(script.exists()) { "Missing scripts/desktop-shortcut.ps1 — required by promoteAndLaunch" }
        val proc = ProcessBuilder(
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", script.absolutePath, exe,
        )
            .directory(layout.projectDirectory.asFile)
            .redirectErrorStream(true)
            .start()
        val output = proc.inputStream.bufferedReader().readText()
        proc.waitFor()
        if (proc.exitValue() != 0) throw GradleException("Shortcut script failed:\n$output")
        println("Shortcut placed on Desktop and app launched: $exe")
        println("Shortcut placed on Desktop and app launched: $exe")
    }
}

compose.desktop {
    application {
        mainClass = "com.maxstream.app.MainKt"
        nativeDistributions {
            targetFormats(TargetFormat.Msi, TargetFormat.Dmg, TargetFormat.Deb)
            packageName = "MaxStream"
            // Must be MAJOR>0 for the macOS Dmg packager (0.1.0 is rejected).
            packageVersion = "1.0.1"
            description = "MaxStream for Windows — desktop catalog & playback client"
            vendor = "MaxStream"
            windows {
                // Start Menu + Desktop/launch shortcuts so the app is easy to find.
                menu = true
                shortcut = true
                menuGroup = "MaxStream"
                upgradeUuid = "d07b3db8-2e2a-4a27-8e0f-1f0dc37f1f4c"
            }
        }
    }
}