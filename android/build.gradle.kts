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
subprojects {
    plugins.withId("com.android.library") {
        if (name == "on_audio_query_android") {
            val androidExtension = extensions.getByName("android")
            val setNamespace =
                androidExtension.javaClass.methods.firstOrNull {
                    it.name == "setNamespace" && it.parameterCount == 1
                } ?: error("Android namespace setter not found for $name")
            setNamespace.invoke(androidExtension, "com.lucasjosino.on_audio_query")
        }
    }
    plugins.withId("org.jetbrains.kotlin.android") {
        if (name == "on_audio_query_android") {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    compilerOptions.jvmTarget.set(
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11,
                    )
                }
        }
    }
}
subprojects {
    afterEvaluate {
        if (name == "on_audio_query_android") {
            val androidExtension = extensions.getByName("android")
            val setCompileSdk =
                androidExtension.javaClass.methods.firstOrNull {
                    (it.name == "setCompileSdk" || it.name == "compileSdkVersion") &&
                        it.parameterCount == 1 &&
                        it.parameterTypes[0] == Int::class.javaPrimitiveType
                } ?: error("Android compileSdk setter not found for $name")
            setCompileSdk.invoke(androidExtension, 36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
