allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 强制所有 Android 子模块（含第三方插件）使用 compileSdk = 36。
// 部分旧插件（file_picker / share_plus / flutter_secure_storage / jni /
// jni_flutter / alibabacloud_rum 等）把 compileSdk 硬编码为低于 36 的值，
// 而 Flutter 3.44 的 flutter_plugin_android_lifecycle 要求 ≥ 36（其 AAR 带
// minCompileSdk=36），否则 `flutter run` 在变体创建阶段报
// "minSdkVersion ... cannot be smaller than 36" 而失败。这里统一强制，避免
// 改插件源码或在 pub 缓存里临时打补丁。
//
// 实现要点：
// - 用 `subprojects { afterEvaluate { ... } }` 而非 `finalizeDsl`：AGP 9 的
//   finalizeDsl 必须在子工程自身的 androidComponents {} 块内调用，根脚本用
//   不了；且本仓库 android 模板原含 `evaluationDependsOn(":app")`，会让子工程
//   先于根脚本评估完毕，导致根脚本里的 afterEvaluate/finalizeDsl 要么抛
//   "already evaluated"、要么 "too late"。已移除 evaluationDependsOn，恢复
//   默认评估顺序：根脚本在子工程评估前注册 afterEvaluate，故本回调早于 AGP
//   自身的变体创建 afterEvaluate 执行，能在 AGP 读取 compileSdk 前注入 36。
// - `CommonExtension` 同时是 LibraryExtension / ApplicationExtension 的父类型，
//   一次 as? 即可覆盖 library 与 application 两类模块。
subprojects {
    afterEvaluate {
        (extensions.findByName("android") as? com.android.build.api.dsl.CommonExtension)
            ?.compileSdk = 36
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
