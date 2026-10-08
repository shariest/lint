#!/usr/bin/env bash
# Integration smoke check: Git, Gradle 9.8, JDK 21+, Android SDK platform 37.
set -euo pipefail

POLICY=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
[ -d "$SDK" ] || { printf 'Set ANDROID_HOME to the Android SDK directory\n' >&2; exit 1; }
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
printf '.gradle/\n.kotlin/\nbuild/\nlocal.properties\n' >.gitignore
printf 'sdk.dir=%s\n' "$SDK" >local.properties
printf 'org.gradle.configureondemand=true\n' >gradle.properties
cat >settings.gradle <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = 'android-smoke'
include 'app', 'library'
EOF
cat >build.gradle <<'EOF'
plugins {
    id 'com.android.application' version '9.4.1' apply false
    id 'com.android.library' version '9.4.1' apply false
}
EOF
mkdir -p app/src/main/kotlin/example app/src/main/java/example app/src/test/kotlin/example
mkdir -p library/src/main/java/example library/src/test/java/example
cat >app/build.gradle <<'EOF'
plugins {
    id 'com.android.application'
}
android {
    namespace = 'example.app'
    compileSdk = 37
    defaultConfig {
        applicationId = 'example.app'
        minSdk = 23
        targetSdk = 37
        versionCode = 1
        versionName = '1.0'
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    flavorDimensions += 'edition'
    productFlavors {
        demo { dimension = 'edition' }
        full { dimension = 'edition' }
    }
    // Consumer flags must not bypass the canonical warning/test policy.
    lint {
        abortOnError = false
        warningsAsErrors = false
        ignoreWarnings = true
        checkTestSources = false
        ignoreTestSources = true
    }
}
dependencies {
    implementation project(':library')
}
tasks.withType(Test).configureEach {
    failOnNoDiscoveredTests = false
}
EOF
cat >library/build.gradle <<'EOF'
plugins {
    id 'com.android.library'
}
android {
    namespace = 'example.library'
    compileSdk = 37
    enableKotlin = false
    defaultConfig { minSdk = 23 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
tasks.withType(Test).configureEach {
    failOnNoDiscoveredTests = false
}
EOF
printf '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Smoke" /></manifest>\n' >app/src/main/AndroidManifest.xml
printf '<manifest />\n' >library/src/main/AndroidManifest.xml
printf 'package example\n\nfun answer() = 42\n' >app/src/main/kotlin/example/Answer.kt
# A local annotation suffices to exercise ktlint's Compose naming convention without a UI dependency.
printf 'package example\n\nannotation class Composable\n\n@Composable\nfun Screen() {}\n' >app/src/main/kotlin/example/Screen.kt
printf 'package example\n\nfun checkAnswer() = check(answer() == 42)\n' >app/src/test/kotlin/example/AnswerTest.kt
printf 'package example;\n\nclass JavaSource {}\n' >app/src/main/java/example/JavaSource.java
printf 'package example;\n\npublic class Library {}\n' >library/src/main/java/example/Library.java
printf 'package example;\n\nclass LibraryTest {}\n' >library/src/test/java/example/LibraryTest.java
mkdir -p app/src/main/generated
printf 'invalid generated java\n' >app/src/main/generated/Generated.java
git add .

# Both CLI entry points work before installation, including the old init-script path.
printf 'Android: CLI, installation, build and configuration cache\n'
check bash "$LINT" android
grep -q ':app:lintFullRelease' "$WORK/output"
grep -q ':library:lintAndroid' "$WORK/output"
check ./gradlew --init-script 'tools/lint rules/config/kotlin/lint.init.gradle' :app:lintKotlin
check bash "$INSTALL" -n -p 'tools/lint rules'
check git diff --exit-code -- settings.gradle
check bash "$INSTALL" -p 'tools/lint rules'
cp settings.gradle "$WORK/installed-settings"
check bash "$INSTALL" -p 'tools/lint rules' android
check cmp settings.gradle "$WORK/installed-settings"
check ./gradlew build
grep -q ':app:lintAndroid' "$WORK/output"
grep -q ':library:lintJava' "$WORK/output"
grep -q ':app:compileDemoDebugUnitTestKotlin' "$WORK/output"
check git diff --exit-code -- app/build.gradle library/build.gradle
check bash "$LINT"
grep -q ':app:lintFullRelease' "$WORK/output"
check ./gradlew lintAndroid --configuration-cache
check ./gradlew lintAndroid --configuration-cache
grep -q 'Reusing configuration cache' "$WORK/output"

# Android Java formatting includes variant sources, and adding a file invalidates the cache.
printf 'Android: Java/Kotlin format and compiler failures\n'
mkdir -p app/src/full/java/example
printf 'package example; class Flavor {}\n' >app/src/full/java/example/Flavor.java
reject 'spotlessJavaCheck FAILED' ./gradlew lintAndroid --configuration-cache
grep -qx 'package example; class Flavor {}' app/src/full/java/example/Flavor.java
rm app/src/full/java/example/Flavor.java
printf 'package example\n\nfun answer()=42\n' >app/src/main/kotlin/example/Answer.kt
reject 'spotlessKotlinCheck FAILED' ./gradlew build
printf 'package example\n\nfun answer() = 42\n' >app/src/main/kotlin/example/Answer.kt
printf 'package example\n\nfun InvalidFunction() {}\n' >app/src/main/kotlin/example/Invalid.kt
reject 'spotlessKotlinCheck FAILED' ./gradlew lintAndroid
rm app/src/main/kotlin/example/Invalid.kt

# Error Prone actually runs for Android Java, including a Java-only library's test source.
cat >library/src/test/java/example/LibraryTest.java <<'EOF'
package example;

class LibraryTest {
    boolean same(int value) {
        return value == value;
    }
}
EOF
reject '[IdentityBinaryExpression]' bash "$LINT" java
printf 'package example;\n\nclass LibraryTest {}\n' >library/src/test/java/example/LibraryTest.java
cat >app/src/test/kotlin/example/AnswerTest.kt <<'EOF'
package example

@Deprecated("Use answer")
fun oldAnswer() = 42

fun checkAnswer() = oldAnswer()
EOF
reject 'warnings found and -Werror specified' bash "$LINT" kotlin
printf 'package example\n\nfun checkAnswer() = check(answer() == 42)\n' >app/src/test/kotlin/example/AnswerTest.kt

# The default variant is clean: a release/flavor-only Android API violation must still fail.
printf 'Android: native Lint for release/flavor and test sources\n'
mkdir -p app/src/fullRelease/kotlin/example
printf 'package example\n\nfun newColor() = android.graphics.Color.valueOf(0)\n' >app/src/fullRelease/kotlin/example/NewApi.kt
reject '[NewApi]' bash "$LINT"
grep -q ':app:lintFullRelease FAILED' "$WORK/output"
rm app/src/fullRelease/kotlin/example/NewApi.kt
printf 'package example\n\nfun testColor() = android.graphics.Color.valueOf(0)\n' >app/src/test/kotlin/example/NewApiTest.kt
reject '[NewApi]' bash "$LINT" android
grep -q 'src/test/kotlin/example/NewApiTest.kt' "$WORK/output"
rm app/src/test/kotlin/example/NewApiTest.kt

# Native Android warnings are blocking, and the source is never rewritten.
printf 'Android: native warnings and baseline rejection\n'
mkdir -p app/src/main/res/layout
cat >app/src/main/res/layout/screen.xml <<'EOF'
<TextView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="wrap_content" android:layout_height="wrap_content"
    android:text="Hardcoded text" />
EOF
printf 'package example\n\nfun screenLayout() = example.app.R.layout.screen\n' >app/src/main/kotlin/example/ScreenLayout.kt
reject '[HardcodedText]' bash "$LINT" android
grep -q 'Error:.*\[HardcodedText\]' "$WORK/output"
rm app/src/main/res/layout/screen.xml app/src/main/kotlin/example/ScreenLayout.kt

cp app/build.gradle "$WORK/app.gradle"
printf '\nandroid.lint.baseline = file("lint-baseline.xml")\n' >>app/build.gradle
reject 'Android Lint baselines are not allowed' ./gradlew lintAndroid
mv "$WORK/app.gradle" app/build.gradle
check bash "$LINT" android
chmod -x gradlew
reject 'executable ./gradlew' bash "$LINT" android
printf 'Android integration checks passed\n'
