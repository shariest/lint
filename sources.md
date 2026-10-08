# 공개 근거와 SENA 결정

이 문서는 2026-08-12에 확인한 공식 공개 자료의 snapshot이다. OpenAI와 Anthropic 항목은
해당 회사의 공개 SDK·제품 저장소 사례이며 회사 전체 또는 비공개 내부 표준이라는 뜻이
아니다. 저장소 파일 링크는 가능한 경우 commit SHA를 고정했고, release tag와 제품 문서는
조사일 기준 snapshot으로 구분한다.

## Google

- [Google Java Style Guide, `1809c769`](https://github.com/google/styleguide/blob/1809c769de31ba388c755ad15dd057a9ba8531fd/javaguide.html)
- [Google TypeScript Style Guide, `1809c769`](https://github.com/google/styleguide/blob/1809c769de31ba388c755ad15dd057a9ba8531fd/tsguide.html)
- [Google Python Style Guide, `1809c769`](https://github.com/google/styleguide/blob/1809c769de31ba388c755ad15dd057a9ba8531fd/pyguide.md)
- [Google Error Prone 2.50.0](https://github.com/google/error-prone/releases/tag/v2.50.0)
- [Google TypeScript Style 도구 GTS, `bd623c03`](https://github.com/google/gts/tree/bd623c03dc9f319b64564cac7478162734739599)
- [Google Cloud Rust의 Clippy 개발·CI 규칙, `b7163bf3`](https://github.com/googleapis/google-cloud-rust/blob/b7163bf3f433a77fe92c2dacbfb20eb7ac456536/GEMINI.md)
- [Spotless Gradle plugin 8.8.0](https://plugins.gradle.org/plugin/com.diffplug.spotless/8.8.0)
- [Palantir Java Format 2.96.0](https://github.com/palantir/palantir-java-format/releases/tag/2.96.0)

Google guide는 언어별 명명, 명시성, import, 타입 안전성 원칙의 기준으로 삼는다. Java 2칸
들여쓰기·100자 및 TypeScript 세미콜론처럼 기존 SENA 관례와 직접 충돌하는 스타일은 그대로
복사하지 않는다. GTS도 README가 밝히듯 Google Node.js 팀의 도구이지 모든 Google 제품의
단일 공식 설정으로 확대 해석하지 않는다.

## OpenAI

- [OpenAI Java SDK Gradle convention, `593f04c9`](https://github.com/openai/openai-java/blob/593f04c912d9331cd83c71ba7a4f6846e2e02fcc/buildSrc/src/main/kotlin/openai.java.gradle.kts)
- [OpenAI Java SDK lint script](https://github.com/openai/openai-java/blob/593f04c912d9331cd83c71ba7a4f6846e2e02fcc/scripts/lint)
- [OpenAI Node SDK oxlint, `a54014de`](https://github.com/openai/openai-node/blob/a54014deabbe8451745a91ea5945388f89455b8a/oxlint.config.ts)
- [OpenAI Node SDK oxfmt](https://github.com/openai/openai-node/blob/a54014deabbe8451745a91ea5945388f89455b8a/oxfmt.config.ts)
- [OpenAI Python SDK pyproject, `8bb0e14e`](https://github.com/openai/openai-python/blob/8bb0e14e58b537baa216fd483e2b950907063470/pyproject.toml)
- [OpenAI Codex workspace lint 설정, `4ef836f8`](https://github.com/openai/codex/blob/4ef836f883c38ba6d39e6920f335ce6452b7de33/codex-rs/Cargo.toml)
- [OpenAI Harness Engineering](https://openai.com/index/harness-engineering/)

Java SDK의 Palantir Java Format 2.96.0, dry-run gate, javac `-Werror`를 직접 반영했다.
Error Prone은 OpenAI Java 공개 설정이 아니라 Google 도구를 SENA가 추가 선택한 것이다.
TypeScript는 OpenAI의 현재 oxlint/oxfmt 전환을 확인했지만 기존 SENA 호환성을 우선해 ESLint와
Prettier를 유지한다.

## Anthropic

- [Anthropic Java SDK Gradle convention, `de1bd155`](https://github.com/anthropics/anthropic-sdk-java/blob/de1bd155b98263b09a5876251b9c44a66bbac662/buildSrc/src/main/kotlin/anthropic.java.gradle.kts)
- [Anthropic Java SDK version catalog](https://github.com/anthropics/anthropic-sdk-java/blob/de1bd155b98263b09a5876251b9c44a66bbac662/gradle/libs.versions.toml)
- [Anthropic TypeScript SDK ESLint, `ed02a89`](https://github.com/anthropics/anthropic-sdk-typescript/blob/ed02a89f5bad120c3191aa105820f33bfa14cef2/eslint.config.mjs)
- [Anthropic TypeScript SDK lint pipeline](https://github.com/anthropics/anthropic-sdk-typescript/blob/ed02a89f5bad120c3191aa105820f33bfa14cef2/scripts/lint)
- [Anthropic Python SDK pyproject, `009b0353`](https://github.com/anthropics/anthropic-sdk-python/blob/009b035305e0724ce108ebd796935f91711fc6e1/pyproject.toml)
- [Anthropic Claude Agent SDK Python pyproject, `be2d0dfb`](https://github.com/anthropics/claude-agent-sdk-python/blob/be2d0dfbd9ee884ff43efd44e5a3158aa09a6a34/pyproject.toml)
- [Anthropic Buffa CI, `fe5635fb`](https://github.com/anthropics/buffa/blob/fe5635fb63c9acf1b3ac017246bd4d51df5d5ce1/.github/workflows/ci.yml)

Anthropic 공개 저장소 여러 곳에서 확인한 관행을 종합했다. TypeScript SDK는 formatter check,
unused import lint와 별도 `tsc`를 사용하고, Claude Agent SDK Python은 strict mypy를 사용한다.
Java SDK의 Palantir formatting과 `-Werror`, Python SDK의 strict Pyright도 각각 참고했다. 이를
하나의 Anthropic 공통 preset으로 표현하지 않는다.

## Rust 공식 자료

- [Rust Style Guide](https://doc.rust-lang.org/style-guide/)
- [rustfmt](https://github.com/rust-lang/rustfmt)
- [Clippy](https://doc.rust-lang.org/clippy/)
- [Rust 1.97.1 release](https://blog.rust-lang.org/2026/07/16/Rust-1.97.1/)

## Kotlin 공식 자료

Kotlin 항목은 2026-10-08에 추가 확인했다.

- [ktlint 1.8.0 release](https://github.com/ktlint/ktlint/releases/tag/1.8.0)
- [ktlint code styles](https://ktlint.github.io/ktlint/latest/rules/code-styles/)
- [Spotless Kotlin 설정](https://github.com/diffplug/spotless/tree/main/plugin-gradle#kotlin)
- [Kotlin Gradle compiler options](https://kotlinlang.org/docs/gradle-compiler-options.html)
- [Gradle init scripts](https://docs.gradle.org/current/userguide/init_scripts.html)
- [Gradle script plugins](https://docs.gradle.org/current/userguide/plugins_intermediate.html)

기존 Spotless를 재사용하고 ktlint의 공식 스타일을 적용한다. Kotlin compiler의
`allWarningsAsErrors`를 활성화하며 compiler 버전과 target은 소비 프로젝트가 소유한다.
설치 스크립트가 Gradle settings에 공통 정책을 연결하고 일반 빌드에서 모듈별로 적용한다.
설치 전 CLI 검사에는 같은 정책을 init script로 불러온다. 수동 plugin 선언은 필요 없다.
이 항목은 Kotlin·Gradle 도구의 공개 문서에 근거한 SENA 선택이다.

## 종합 판단

frontier 회사마다 언어, 저장소 생성 방식, 공개 범위가 다르므로 하나의 설정을 복사하는 방식은
재현 가능하지 않다. SENA는 공통적으로 확인되는 네 가지 관행을 표준화한다.

1. deterministic formatter와 check-only CI
2. warning을 허용하지 않는 compiler/linter gate
3. type checker를 build 전에 실행
4. generated/vendor 경로를 출처 기반으로 좁게 분리
