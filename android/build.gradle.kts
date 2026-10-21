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

// tflite_flutter compiles its Java for 11 and its Kotlin for whichever JDK is
// running Gradle, and Gradle refuses a plugin whose two disagree. Hold its
// Kotlin to the same 11 its Java uses. Nothing else is touched.
subprojects {
    if (project.name == "tflite_flutter") {
        afterEvaluate {
            tasks
                .withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    compilerOptions.jvmTarget.set(
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11,
                    )
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
