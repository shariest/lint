# Android lint 표준

## 적용 방식

`com.android.application`과 `com.android.library` 모듈을 감지해
`config/android/lint.gradle`을 적용한다. Kotlin은 기존 ktlint와 compiler 정책을,
Java는 기존 Palantir formatter, Error Prone, javac 정책을 재사용한다.
소비 프로젝트의 AGP·Kotlin 버전, SDK, JVM target은 변경하지 않는다.

```bash
./docs/lint/scripts/install.sh android
./gradlew build
./gradlew lintAndroid
```

언어 인자를 생략한 자동 설치도 같은 Gradle settings 연결을 만든다. 설치된 프로젝트에서는
`check`와 `build`에 검사가 포함된다. Android Studio의 Run이나 `assembleDebug`만으로는
전체 Android Lint를 보장하지 않으므로 CI에서는 `build` 또는 `lintAndroid`를 실행한다.

설치 전에도 공통 init script로 같은 검사를 실행할 수 있다.

```bash
./docs/lint/scripts/lint.sh android
```

통합 `lint.sh`, `lint.sh java`, `lint.sh kotlin`도 해당 Android 모듈의 Android Lint를
포함한다. 기존 JVM 모듈과 Android 모듈이 섞여 있어도 각각의 정책을 적용한다.
`android`를 명시하면 Android 모듈만 선택한다.

## 검사와 차단 기준

| 검사 | 대상과 동작 |
| --- | --- |
| Android Lint | 활성화된 모든 build type·product flavor의 소스, manifest, XML resource, 테스트 소스 |
| Kotlin | Git tracked/untracked `*.kt`, `*.kts`의 ktlint + main/test 및 variant compilation |
| Java | Git tracked/untracked `*.java`의 포맷 + 모든 `JavaCompile`의 Error Prone 및 javac warning |

Android Lint는 소비 프로젝트 AGP에 포함된 버전을 사용한다. `abortOnError`와
`warningsAsErrors`를 켜고, `ignoreWarnings`와 `ignoreTestSources`는 끈다.
API 수준 위반, permission 누락, resource·접근성 문제 등 기본 활성 규칙의 warning과 error가
모두 실패를 만든다. test 소스에도 일반 규칙을 적용한다. baseline 설정이 있으면 구성 단계에서
오류를 내며, 기존 baseline 파일을 수정하거나 삭제하지 않는다.

Android의 ktlint는 `@Composable` 함수에 한해 PascalCase 이름을 허용한다. Compose UI의
명명 관례를 위한 설정이며, 일반 Kotlin 함수의 이름 규칙은 유지한다.

Java/Kotlin formatter는 Git submodule과 ignore된 untracked 파일을 순회하지 않는다.
`build`, `.gradle`, `.kotlin`, `node_modules`, `vendor`, `generated` 디렉터리도 제외한다.
Java는 `src/debug`, `src/release`, flavor, unit test, instrumented test 파일도 포함한다.
Error Prone은 AGP의 annotation processor configuration에 추가하므로 기존 processor를
제거하지 않는다. 테스트용 Java compilation에는 test 전용 검사 모드를 지정한다.

검사 명령은 소스를 자동 수정하지 않는다. 포맷 수정은 명시적으로 실행한다.

```bash
./gradlew spotlessJavaApply spotlessKotlinApply
```

오탐이나 외부 API 경계의 예외는 가장 좁은 선언에 정확한 규칙과 이유를 남긴다.
프로젝트 전체에서 규칙을 끄거나 baseline으로 기존 문제를 숨기는 것은 표준 경로가 아니다.

## 실행 검증

Java의 Error Prone 검사에 JDK 21+가 필요하며, Gradle과 Android SDK는 소비 프로젝트 AGP의
요구 버전을 사용한다. AGP 9.4.1, Gradle 9.8, JDK 21, SDK platform 37에서 검증했다.
AGP 8.x, dynamic feature, standalone test 및 Kotlin Multiplatform Android 플러그인은
이 통합 테스트의 지원 범위에 포함하지 않는다.

```bash
ANDROID_HOME=/path/to/android-sdk bash tests/android.sh
bash tests/kotlin.sh
```

Android 테스트는 실제 submodule을 가진 임시 앱·라이브러리를 만든다. 설치 전 CLI,
반복 설치, 일반 build, 내장 Kotlin, Java 전용 라이브러리, flavor/release 검사,
configuration cache, Compose 함수 명명, 포맷·Error Prone·Kotlin warning·Android Lint 실패를 확인한다.
테스트가 끝나면 임시 저장소를 삭제한다. JVM 회귀 검사는 기존 `tests/kotlin.sh`로 수행한다.
