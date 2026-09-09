allprojects {
    repositories {
        google()
        mavenCentral()
        // Liblinphone is not on Maven Central.
        maven {
            url = uri("https://download.linphone.org/maven_repository")
            content { includeGroupByRegex("org\\.linphone.*") }
        }
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
