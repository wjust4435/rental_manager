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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- NEW: Safely fix missing namespaces for older plugins ---
subprojects {
    fun applyNamespace(proj: Project) {
        proj.extensions.findByName("android")?.let { androidExt ->
            try {
                val namespaceProp = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
                if (namespaceProp == null) {
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, proj.group.toString())
                }
            } catch (e: Exception) {
                // Safely ignore if the plugin structure doesn't match
            }
        }
    }

    // Check if the project is already evaluated to prevent Gradle crashes
    if (state.executed) {
        applyNamespace(this)
    } else {
        afterEvaluate { applyNamespace(this) }
    }
}

// android/build.gradle.kts (Root Level) - Place this at the very end
subprojects {
    // 1. Force Java compiler tasks to 17 directly (Bypasses AGP compileOptions lockdown)
    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    // 2. Force Kotlin compiler tasks to 17
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}