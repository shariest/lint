#!/usr/bin/env bash
# Integration smoke check: Git, Gradle compatible with Kotlin 2.4.20, JDK 21+.
set -euo pipefail

POLICY=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
trap 'cat "$WORK/output" >&2' ERR

check() {
    if ! "$@" >"$WORK/output" 2>&1; then
        cat "$WORK/output"
        exit 1
    fi
}

reject() {
    local message=$1
    shift
    if "$@" >"$WORK/output" 2>&1; then
        printf 'expected failure: %s\n' "$*" >&2
        exit 1
    fi
    grep -qF "$message" "$WORK/output" || { cat "$WORK/output"; exit 1; }
}

# Use an actual submodule containing the working copy, including uncommitted changes.
mkdir -p "$WORK/policy" "$WORK/consumer"
cp -R "$POLICY/config" "$POLICY/scripts" "$WORK/policy/"
git -C "$WORK/policy" init -q
git -C "$WORK/policy" add .
git -C "$WORK/policy" -c user.name=Lint -c user.email=lint@example.invalid commit -qm policy
cd "$WORK/consumer"
git init -q
check git -c protocol.file.allow=always submodule add "$WORK/policy" 'tools/lint rules'
LINT="$PWD/tools/lint rules/scripts/lint.sh"
INSTALL="$PWD/tools/lint rules/scripts/install.sh"
printf '#!/usr/bin/env bash\nexec gradle "$@"\n' >gradlew
chmod +x gradlew
printf '.gradle/\nbuild/\n' >.gitignore
printf 'org.gradle.configureondemand=true\n' >gradle.properties
printf 'rootProject.name = "smoke"\n' >settings.gradle.kts
cat >build.gradle.kts <<'EOF'
plugins {
    kotlin("jvm") version "2.4.20"
}

repositories {
    mavenCentral()
}

kotlin {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

// These sample test functions check compilation without a test framework.
tasks.test {
    failOnNoDiscoveredTests = false
}
EOF
mkdir -p src/main/kotlin src/test/kotlin src/main/generated
printf 'fun answer() = 42\n' >src/main/kotlin/Answer.kt
printf 'fun checkAnswer() = check(answer() == 42)\n' >src/test/kotlin/AnswerTest.kt
# Generated and nested submodule sources must never be formatted.
printf 'invalid kotlin\n' >src/main/generated/Generated.kt
printf 'invalid kotlin\n' >'tools/lint rules/Foreign.kt'
git add build.gradle.kts settings.gradle.kts src/main/kotlin src/test/kotlin
check bash "$INSTALL" -n -p 'tools/lint rules'
grep -q 'detected: kotlin' "$WORK/output"
check git diff --exit-code -- settings.gradle.kts
reject 'submodule path must be relative' bash "$INSTALL" -n -p '../outside'
check bash "$INSTALL" -p 'tools/lint rules'
cp settings.gradle.kts "$WORK/installed-settings"
check bash "$INSTALL" -p 'tools/lint rules'
check cmp settings.gradle.kts "$WORK/installed-settings"
check ./gradlew build
grep -q ':lintKotlin' "$WORK/output"
grep -q ':compileTestKotlin' "$WORK/output"
check bash "$LINT"
grep -q ':compileTestKotlin' "$WORK/output"
check git diff --exit-code -- build.gradle.kts
# A new developer only clones the committed adapters and runs the normal build.
git add .gitignore .gitmodules gradlew gradle.properties settings.gradle.kts build.gradle.kts src 'tools/lint rules'
git -c user.name=Lint -c user.email=lint@example.invalid commit -qm 'adopt lint'
check git -c protocol.file.allow=always clone --recurse-submodules "$PWD" "$WORK/clone"
check bash -c 'cd "$1" && ./gradlew build' _ "$WORK/clone"
grep -q ':lintKotlin' "$WORK/output"

printf 'fun answer()=42\n' >src/main/kotlin/Answer.kt
reject 'spotlessKotlinCheck FAILED' ./gradlew build
grep -qx 'fun answer()=42' src/main/kotlin/Answer.kt
printf 'fun answer() = 42\n' >src/main/kotlin/Answer.kt
printf 'val wrong: String = answer()\n' >src/test/kotlin/AnswerTest.kt
reject 'compileTestKotlin FAILED' ./gradlew build
cat >src/test/kotlin/AnswerTest.kt <<'EOF'
@Deprecated("Use answer")
fun oldAnswer() = 42

fun checkAnswer() = oldAnswer()
EOF
reject 'warnings found and -Werror specified' ./gradlew build
printf 'fun checkAnswer() = check(answer() == 42)\n' >src/test/kotlin/AnswerTest.kt
mv build.gradle.kts "$WORK/build.gradle.kts"
reject 'no Kotlin Gradle plugin' bash "$LINT" kotlin
mv "$WORK/build.gradle.kts" build.gradle.kts

# Aggregator root, Groovy subproject, and an existing Java/Spotless gate coexist.
mkdir library
mv src library/
rm build.gradle.kts
cat >build.gradle <<'EOF'
plugins {
    id 'com.diffplug.spotless' version '8.8.0'
}
EOF
cat >library/build.gradle <<'EOF'
plugins {
    id 'org.jetbrains.kotlin.jvm' version '2.4.20'
}
repositories {
    mavenCentral()
}
kotlin {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
tasks.withType(JavaCompile).configureEach {
    options.release = 17
}
tasks.withType(Test).configureEach {
    failOnNoDiscoveredTests = false
}
EOF
printf '\ninclude("library")\n' >>settings.gradle.kts
mkdir -p library/src/main/java/example
printf 'package example;\n\nclass JavaSource {}\n' >library/src/main/java/example/JavaSource.java
check ./gradlew build
grep -q ':library:lintJava' "$WORK/output"
grep -q ':library:lintKotlin' "$WORK/output"
printf 'class JavaSource {}\n' >library/src/main/java/example/JavaSource.java
reject 'DefaultPackage' ./gradlew build
printf 'package example;\n\nclass JavaSource {}\n' >library/src/main/java/example/JavaSource.java
check bash "$LINT"
grep -q ':library:compileTestKotlin' "$WORK/output"
check ./gradlew build --configuration-cache
check ./gradlew build --configuration-cache
grep -q 'Reusing configuration cache' "$WORK/output"
printf 'fun added()=43\n' >library/src/main/kotlin/Added.kt
reject 'spotlessKotlinCheck FAILED' ./gradlew build --configuration-cache
rm library/src/main/kotlin/Added.kt
# Settings-only dependency repositories (also common in Android projects).
cat >>settings.gradle.kts <<'EOF'

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
}
EOF
sed '/^repositories {/,/^}/d' library/build.gradle >"$WORK/library.gradle"
mv "$WORK/library.gradle" library/build.gradle
# The runner must also work when invoked below the repository root.
cd library
check bash "$LINT" kotlin
check ../gradlew build
cd ..
# Groovy settings use the same automatic installation for Java and Kotlin.
rm settings.gradle.kts
cat >settings.gradle <<'EOF'
rootProject.name = 'smoke'
include 'library'
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
}
EOF
check bash "$INSTALL" -p 'tools/lint rules' java
cp settings.gradle "$WORK/groovy-settings"
check bash "$INSTALL" -p 'tools/lint rules' kotlin
check cmp settings.gradle "$WORK/groovy-settings"
check ./gradlew build
grep -q ':library:lintJava' "$WORK/output"
grep -q ':library:lintKotlin' "$WORK/output"
chmod -x gradlew
reject 'executable ./gradlew' bash "$LINT" kotlin
printf 'Kotlin integration checks passed\n'
