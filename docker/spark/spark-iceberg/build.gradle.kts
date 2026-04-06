plugins {
    `java-library`
    id("org.openprojectx.spark.platform.base-image") version "0.1.0"
    id("com.google.cloud.tools.jib") version "3.5.3"
}

group = "org.openprojectx.spark.docker"
version = (findProperty("platformVersion") as String?) ?: "0.1.0"

val sparkVersion = (findProperty("sparkVersion") as String?) ?: "4.1.1"
val scalaBinary = (findProperty("scalaBinary") as String?) ?: "2.13"
val platformVersion = project.version.toString()
val os = "ubuntu"

repositories {
    mavenLocal()
    mavenCentral()
}


dependencies {
//    sparkRuntime("org.apache.iceberg:iceberg-spark-runtime-4.0_${scalaBinary}")

    sparkRuntime(platformCatalog.bundles.spark.iceberg)

}

sparkBaseImage {
    imageOS = os
}


