# Java lint 표준

## 선택

Java 25 코드는 Spotless로 Palantir Java Format을 검사하고, 모든 `JavaCompile`에
Error Prone과 javac `-Xlint`를 적용한다. compile 전에 formatter check가 실행되며 warning도
`-Werror`로 빌드를 실패시킨다.

실행 규칙의 단일 원본은 `docs/lint/config/java/lint.gradle`이다. `install.sh`가 Gradle settings에
`config/gradle/lint.settings.gradle`을 연결하고, 공통 설정이 각 Java 모듈의 plugin과 정책을
자동으로 준비한다. 기존 build script에서 이 정책을 직접 적용하던 방식도 유지된다.

```text
Spotless 8.8.0
Palantir Java Format 2.96.0
Error Prone Gradle plugin 5.1.0
Error Prone core 2.50.0
javac -Xlint:all,-processing -Werror
```

Palantir formatter는 SENA의 기존 4칸 들여쓰기와 긴 식의 가독성을 보존하면서,
OpenAI Java SDK 공개 설정과 같은 formatter 버전을 사용한다. Google Java Style의 의미적
원칙은 따르지만 2칸 들여쓰기와 100자 제한을 그대로 가져오지는 않는다.

## blocking 규칙

- formatter 결과와 다른 파일
- Error Prone이 보고하는 correctness, concurrency, API misuse 문제
- wildcard import
- annotation processor 탐색 외의 모든 javac warning
- platform 기본 charset 또는 기본 locale에 의존하는 변환
- 빈 catch, 사용하지 않는 지역 변수·메서드, 잘못된 문서 주석
- production 및 test compile 실패

Lombok, MapStruct 등 annotation processor가 정상 동작하면서 내는 processor discovery
warning만 `-Xlint:-processing`으로 제외한다. generated 경로는 Error Prone과 formatter에서
제외하지만, 생성기를 직접 작성한 first-party Java 코드는 검사한다.

`UnicodeInCode`는 표준에서 끈다. 테스트 메서드명을 한글 문장으로 쓰는 저장소가 있고
(`void 서비스가_던진_예외는_INTERNAL로_감싼다()`), 그 이름 자체가 테스트 문서다.
동형이의 유니코드 문자로 인한 혼동 위험보다 의도가 그대로 읽히는 이점이 크다고 봤다.
주석·문자열의 한글은 이 검사 대상이 아니므로 원래 문제되지 않는다.

## 사용법

```bash
./docs/lint/scripts/install.sh  # 저장소에 처음 도입할 때 한 번 실행
./gradlew lintJava
./gradlew spotlessJavaApply
./gradlew build
```

`spotlessJavaApply`는 포맷만 고친다. Error Prone 문제는 의미를 확인하여 코드로 수정한다.
CI나 build task에서 apply를 실행해 작업 트리를 몰래 바꾸지 않는다.

## 억제 정책

파일이나 package 전체 `@SuppressWarnings`는 허용하지 않는다. 오탐일 때만 가장 작은 선언에
정확한 검사 이름과 이유를 기록한다. `all`, 빈 문자열, 원인을 설명하지 않는 전역
Error Prone disable은 허용하지 않는다. generated 코드는 경로 예외로 관리한다.
