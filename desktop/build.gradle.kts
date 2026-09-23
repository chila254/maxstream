import org.jetbrains.compose.desktop.application.dsl.TargetFormat

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
}

compose.desktop {
    application {
        mainClass = "com.maxstream.app.MainKt"
        nativeDistributions {
            targetFormats(TargetFormat.Msi, TargetFormat.Dmg, TargetFormat.Deb)
            packageName = "MaxStream"
            // Must be MAJOR>0 for the macOS Dmg packager (0.1.0 is rejected).
            packageVersion = "1.0.0"
            description = "MaxStream for Windows — desktop catalog & playback client"
            vendor = "MaxStream"
        }
    }
}