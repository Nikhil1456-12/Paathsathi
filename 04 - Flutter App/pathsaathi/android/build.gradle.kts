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
subprojects {
    if (project.name != "app") {
        val configureAndroid: () -> Unit = {
            if (project.hasProperty("android")) {
                val android = project.extensions.findByName("android")
                if (android != null) {
                    var set = false
                    for (methodName in listOf("compileSdkVersion", "setCompileSdkVersion", "setCompileSdk")) {
                        for (paramType in listOf(Int::class.javaPrimitiveType, java.lang.Integer::class.java)) {
                            if (!set && paramType != null) {
                                try {
                                    val method = android.javaClass.getMethod(methodName, paramType)
                                    method.invoke(android, 36)
                                    set = true
                                } catch (_: Exception) {}
                            }
                        }
                    }
                }
            }
        }
        if (project.state.executed) {
            configureAndroid()
        } else {
            project.afterEvaluate {
                configureAndroid()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
