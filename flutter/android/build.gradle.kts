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

// ponytail: some plugins (e.g. file_picker 9.x) hardcode an old compileSdk
// that's lower than what their own transitive deps require. afterEvaluate
// (not plugins.withType) so this runs after the plugin's own `android {}`
// block, and skip :app since evaluationDependsOn above already evaluates it.
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let {
                it.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
