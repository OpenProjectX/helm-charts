pluginManagement {
    repositories {
        mavenLocal()
        maven(url = "https://maven.aliyun.com/repository/gradle-plugin/")
        mavenCentral()
//        gradlePluginPortal()
    }
}


dependencyResolutionManagement {
    @Suppress("UnstableApiUsage")
    repositories {
        mavenLocal()
        mavenCentral()
    }

    versionCatalogs {
        create("platformCatalog") {
            from("org.openprojectx.spark.platform:platform-version-catalog:0.1.0")
        }
    }
}


plugins {
    // Use the Foojay Toolchains plugin to automatically download JDKs required by subprojects.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
//    id("org.openprojectx.spark.platform.base-image") version "0.1.0"

}



rootProject.name = "spark-iceberg"


val excludeProjects: String? by settings

val buildFiles = fileTree(rootDir) {
    val excludes = excludeProjects?.split(",")
    include("**/*.gradle", "**/*.gradle.kts")
    exclude(
        "build",
        "**/gradle",
        "settings.gradle",
        "settings.gradle.kts",
        "buildSrc",
        "build-logic",
        "/build.gradle",
        "/build.gradle.kts",
        ".*",
        "out"
    )
    exclude("**/grails3")
    if (!excludes.isNullOrEmpty()) {
        exclude(excludes)
    }
}

val rootDirPath = rootDir.absolutePath + File.separator
buildFiles.forEach { buildFile ->
    val isDefaultName = buildFile.name.startsWith("build.gradle")
    val isKotlin = buildFile.name.endsWith(".kts")

    if (isDefaultName) {
        val buildFilePath = buildFile.parentFile.absolutePath
        val projectPath = buildFilePath
            .replace(rootDirPath, "")
            .replace(File.separator, ":")

        println("Adding project $projectPath")
        include(projectPath)
    } else {
        val projectName = if (isKotlin) {
            buildFile.name.removeSuffix(".gradle.kts")
        } else {
            buildFile.name.removeSuffix(".gradle")
        }

        val projectPath = ":$projectName"
        println("Adding project $projectPath")
        include(projectPath)

        val project = findProject(projectPath)
        project?.name = projectName
        project?.projectDir = buildFile.parentFile
        project?.buildFileName = buildFile.name
    }
}

//gradle.beforeProject {
//    if (this != rootProject) {
//        group = "org.openprojectx.ttyd4j"
//        version = "0.1.0-SNAPSHOT"
//    }
//}


gradle.extra["isCi"] = System.getenv().containsKey("CI") ||
        System.getenv().containsKey("GITHUB_ACTIONS") ||
        System.getenv().containsKey("JENKINS_HOME")
