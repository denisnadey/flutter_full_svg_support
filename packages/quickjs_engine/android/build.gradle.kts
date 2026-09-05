group = "io.quickjs_engine"
version = "0.1.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:9.3.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

if (agpMajor < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    //if (project.hasProperty("namespace")) {
        namespace = "io.quickjs_engine"
    //}
    compileSdk = flutter.compileSdkVersion

//    sourceSets {
//        getByName("main").java.srcDirs("src/main/kotlin")
//    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        externalNativeBuild {
            cmake {
                cppFlags("-std=c++17", "-DCONFIG_VERSION=\\\"ng-0.14.0\\\"")
                cFlags(
                    "-std=c11", "-DCONFIG_VERSION=\\\"ng-0.14.0\\\"",
                    "-Wno-unused-function", "-Wno-unused-variable",
                    "-Wno-unused-parameter", "-Wno-unused-but-set-variable"
                )
                arguments("-DANDROID_STL=c++_static")
            }
        }
        ndk {
            abiFilters.addAll(setOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64"))
        }
    }
    externalNativeBuild {
        cmake {
            path("../native/CMakeLists.txt")
        }
    }
}

project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
}
