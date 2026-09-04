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

// flutter_reactive_ble 5.x still declares compileSdk 33, but the androidx
// libraries it pulls in now require 34+ and the AAR-metadata check refuses
// the build. Lift every plugin to the app's compileSdk; this changes what
// they compile against, not their minSdk or behaviour.
subprojects {
    val lift = Action<Project> {
        (extensions.findByName("android") as? com.android.build.api.dsl.LibraryExtension)?.let {
            if ((it.compileSdk ?: 0) < 36) it.compileSdk = 36
        }
    }
    // :app is already evaluated here (evaluationDependsOn above), and
    // afterEvaluate on an evaluated project throws.
    if (state.executed) lift.execute(this) else afterEvaluate(lift)
}
