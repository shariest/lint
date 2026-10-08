# Kotlin lint 표준

## 선택

Java에서 사용하는 Spotless에 ktlint를 연결하고, 소비 프로젝트의 Kotlin compiler로 타입과
warning을 검사한다. 규칙과 버전은 `config/kotlin/`에만 두며 프로젝트마다 복사하지 않는다.

```text
Spotless Gradle 8.8.0 (프로젝트에 이미 있으면 해당 plugin 재사용)
ktlint 1.8.0, ktlint_official
4 spaces, max_line_length 120, UTF-8, LF
allWarningsAsErrors = true, suppressWarnings = false
```

JDK 17+, Gradle 8+, Kotlin Gradle plugin 2.x 프로젝트가 대상이다. compiler 버전, JVM target,
toolchain은 소비 프로젝트가 정한다. Kotlin DSL(`build.gradle.kts`)과 Groovy DSL,
루트가 집계만 담당하는 멀티모듈 구조를 지원한다.
Android 앱·라이브러리에는 [Android 정책](android.md)도 함께 적용된다. AGP 9의 내장 Kotlin은
별도의 Kotlin Android plugin 선언 없이 사용하며, Android의 Java 검사에는 JDK 21+가 필요하다.

## 설치 후 일반 빌드로 실행

```bash
git submodule add http://192.168.220.222:8089/ploonet/lint.git docs/lint
./docs/lint/scripts/install.sh
./gradlew build
```

설치 스크립트는 언어와 Gradle DSL을 감지하고 `settings.gradle(.kts)`에 공통 정책 연결을
자동으로 추가한다. 설정 파일이 없으면 생성하며 반복 설치해도 같은 연결을 중복 추가하지 않는다.
settings와 submodule을 함께 커밋하면 다른 개발자는 `git clone --recurse-submodules` 후
일반 `./gradlew build`를 사용하면 된다. plugin 선언, 옵션 전달, 로컬 Gradle 설정이 필요 없다.
최초 빌드에서는 Maven Central 등의 의존성 다운로드가 필요하다.

`config/gradle/lint.settings.gradle`이 각 모듈에 Spotless와 `config/kotlin/lint.gradle`을
적용한다. 해당 모듈의 Kotlin compile task를 `lintKotlin`에 연결하고 `check`/`build`에서
실행한다. 테스트 컴파일도 포함하며, 컴파일 전에 formatter check를 실행한다.
Java 소스가 있는 모듈에는 기존 Java 정책과 Error Prone도 자동으로 적용한다.
Android의 `lintKotlin`은 모든 활성 variant의 Android Lint도 실행한다.

```bash
./gradlew build
./gradlew check
./gradlew lintKotlin
```

configuration cache와 configuration on demand를 켜 둔 프로젝트도 같은 명령을 사용한다.
각 모듈을 구성할 때 정책을 연결하므로 옵션에 따라 컴파일 검사가 빠지지 않는다.

설치 전에 lint만 실행하려면 기존 CLI 진입점을 사용할 수 있다.

```bash
./docs/lint/scripts/lint.sh kotlin
```

이 명령은 같은 공통 정책을 init script로 불러온다. 이미 설치된 프로젝트에서도 중복 적용하지
않으며, 일반 빌드에 연결하려면 위의 일회성 설치를 사용한다.

## 검사 대상과 blocking 규칙

Git이 추적하거나 ignore하지 않은 `*.kt`와 `*.kts`를 검사한다. main/test 소스뿐 아니라
Gradle Kotlin DSL도 포함한다. 하위 Gradle 모듈은 자기 정책으로 검사하며 Git submodule 안의
소스는 순회하지 않는다.
`build`, `.gradle`, `.kotlin`, `node_modules`, `vendor`, `generated` 디렉터리는 제외한다.

- ktlint 표준 규칙: 포맷, 명명, import 정렬, 사용하지 않는 import, wildcard import
- `config/kotlin/.editorconfig`와 다른 들여쓰기·개행·줄 길이
- Kotlin main/test 및 프로젝트가 등록한 추가 compilation의 오류와 warning

자동 수정은 명시적으로 요청할 때만 실행한다. 기본 lint와 build는 소스를 수정하지 않는다.

```bash
./gradlew spotlessKotlinApply
```

ktlint 억제나 `@Suppress`는 오탐 또는 외부 API 경계에만 정확한 규칙과 이유를 남긴다.
파일 전체 baseline이나 compiler warning의 일괄 무시는 허용하지 않는다.

## 설정 검증

이 표준 저장소에서 `bash tests/kotlin.sh`를 실행한다. Git, Kotlin 2.4.20과 호환되는 Gradle,
Java 검사에 필요한 JDK 21+가 필요하다. 임시 저장소에 실제 submodule을 등록하고 설치한 뒤
옵션 없는 `./gradlew build`로 정상 코드와 포맷·컴파일·warning 실패를 검증한다.
반복 설치, check-only 동작, 기존 Spotless, 혼합 언어, 멀티모듈, 캐시와 경로의 공백도 확인한다.
