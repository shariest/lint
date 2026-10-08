# SENA lint 표준

상태: 적용

조사 기준일: 2026-08-12

이 디렉터리는 SENA가 직접 소유하고 수정하는 Java, Kotlin, TypeScript, Python, Rust 코드의
정적 검사 표준을 정의한다. 공개된 Google 스타일 가이드와 OpenAI·Anthropic의 공식
오픈 소스 저장소 설정을 참고하되, 각 회사의 비공개 사내 표준이라고 추정하지 않는다.
SENA의 기존 구조, 런타임 버전, 코드 관례와 충돌하는 항목은 근거를 남기고 조정한다.

## 적용 원칙

1. formatter, lint, type check의 warning과 error는 모두 빌드를 차단한다.
2. 기존 코드도 예외 baseline 없이 현재 표준을 통과해야 한다.
3. 대상은 경로 blacklist보다 first-party 경로 allowlist로 관리한다.
4. 테스트와 팀이 유지보수하는 복사 코드는 first-party 코드로 본다.
5. generated, vendored, upstream mirror는 lint 대신 생성 재현성 또는 원본 무결성을 검증한다.
6. 자동 수정 명령은 개발자가 명시적으로 실행한다. CI와 빌드는 check만 실행한다.
7. 규칙 억제는 가장 좁은 문장이나 선언에만 적용하고, 이유를 같은 위치에 기록한다.
8. 개발자가 언어별 설정을 직접 작성하지 않도록 설치를 자동화한다. 새 언어 지원에는 자동 감지,
   설치, 해당 생태계의 일반 개발 명령 연결과 실제 실행 검증을 함께 포함한다.

## 실행 설정의 단일 원본

Markdown 문서는 기준을 설명하고, 실제 도구가 읽는 설정은 모두 `docs/lint/config/`에 둔다.
루트나 언어 디렉터리의 파일은 plugin bootstrap, 상대경로 adapter 또는 symlink일 뿐이며 규칙을
중복해서 정의하지 않는다.

| 언어 | canonical 설정 | 프로젝트 연결 방식 |
| --- | --- | --- |
| Java | `config/java/lint.gradle` | `install.sh`가 Gradle settings에 공통 정책을 자동 연결. 기존 build script 연결도 지원 |
| Kotlin | `config/kotlin/lint.gradle`, `.editorconfig` | 같은 Gradle settings 연결로 모듈마다 `check`/`build`에 자동 적용 |
| TypeScript | `config/typescript/eslint.config.mjs`, `prettier.json` | 각 TS 프로젝트의 `eslint.config.js` dependency adapter(프론트엔드 factory / Node factory), `.prettierrc.cjs` IDE adapter, pnpm의 `--config` |
| Python | `config/python/pyproject.toml`, `requirements.txt` | `scripts/lint.sh`와 Docker의 `--config`, `--config-file`, `-r` |
| Rust | `config/rust/{rust-toolchain,rustfmt,clippy}.toml` | 루트의 같은 이름 파일이 canonical 파일을 가리키는 상대 symlink |

따라서 다른 저장소에 표준을 이식할 때는 `docs/lint/config/`를 복사하고 각 언어의 얇은 연결
파일과 source inventory만 프로젝트 구조에 맞게 조정한다. source inventory는 canonical 파일
전체와 Rust 상대 symlink의 정확한 target을 fail-closed로 검증한다.

## 코드 소유권과 대상

| 언어 | 검사 대상 | 기본 예외 |
| --- | --- | --- |
| Java | `src/main/java/**`, `src/test/java/**` | `src/main/generated/**`, `build/**` |
| Kotlin | Git tracked/untracked `*.kt`, `*.kts`; main/test 및 하위 프로젝트 compilation | Git submodule, ignore된 untracked 파일, `build`, `.gradle`, `.kotlin`, `node_modules`, `vendor`, `generated` 디렉터리 |
| TypeScript | `frontend/src/**/*.{ts,tsx,mts,cts}`, `frontend/vite.config.ts` | `frontend/{node_modules,dist}/**` |
| Python | `tool-runner/runner.py`, `tool-runner/tools/_example.py`, `docs/build_pptx.py`, `docs/build_architecture.py`, `src/main/resources/extension-bundle/bundle_server.py` | 런타임 생성 `tool-runner/tools/**` 중 `_example.py` 외 파일, cache/build 산출물 |
| Rust | 앞으로 추가되는 first-party Cargo workspace의 추적 중인 `*.rs` | `modules/**`, `vendor/**`, `target/**`, generated 코드 |

`modules/**`는 별도 저장소인 Git submodule이므로 이 저장소의 lint가 검사하거나
수정하지 않는다. 각 submodule은 자기 저장소의 gate를 가져야 한다. `components/ui/**`처럼
외부 도구로 시작했더라도 SENA가 추적하고 수정하는 코드는 예외가 아니다.
통합 lint는 Git의 tracked 및 아직 untracked인 언어 파일을 inventory하여 Java/TypeScript가
표에 없는 source root에 놓이거나 Python/Rust가 각 언어 gate에서 빠지면 실패한다.

새 예외는 다음 정보를 포함한 명시적 설정 변경으로만 추가한다.

- 정확한 경로와 소유자
- upstream 또는 generator 출처
- 사람이 직접 수정하지 않는다는 근거
- 재생성 또는 무결성 검사 방법
- 제거 조건이나 재검토 시점

`eslint-disable`, `# noqa`, `# type: ignore`, `@SuppressWarnings`, Clippy `allow`는 규칙을
전역으로 끄는 대안이 아니다. 도구 오탐이나 경계 어댑터처럼 코드로 해결할 수 없는 경우에만
최소 범위와 설명을 사용한다. 이 설명 의무는 review 정책이며 현재 도구가 comment 존재까지
자동 검증하지는 않는다.

## 표준 명령

모든 언어를 한 번에 검사한다.

```bash
./scripts/lint.sh
```

언어별 명령은 다음과 같다.

```bash
./gradlew lintJava
./docs/lint/scripts/lint.sh kotlin
pnpm --dir frontend run lint
./.lint-venv/bin/ruff format --config docs/lint/config/python/pyproject.toml --check <sources>
./.lint-venv/bin/ruff check --config docs/lint/config/python/pyproject.toml <sources>
./.lint-venv/bin/mypy --config-file docs/lint/config/python/pyproject.toml <sources>
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-targets --all-features
```

Python 검사 환경은 `scripts/lint.sh`가 Python 3.14와 `config/python/requirements.txt`에 직접
고정한 Ruff/mypy 버전으로 `.lint-venv`에 구성하고, 코드도 같은 Python 3.14를 target으로
분석한다. 채택 저장소의 실제 runtime이 3.14보다 낮으면 `UP` rule이 요구하는 3.10+ 문법이
runtime에서 깨지므로, runtime을 먼저 올린 뒤 표준을 채택한다. transitive dependency까지
hash-lock한 환경은 아니므로 lock 갱신 시 `pip check`와 전체 lint를 다시 검증한다.
고정 allowlist 밖의 새 Python source는 검사 대상과 Docker stage를 함께 갱신할 때까지 실패한다.
Rust first-party 소스가 아직 없으므로 Rust 검사는 현재 명시적인 no-op이다. first-party
`*.rs`가 추가되면 root Cargo workspace manifest 및 clean compile dep-info 입력 소속 없이
통과할 수 없다. `.rs`를 데이터로 include하는 특수 사례는 review에서 별도로 확인한다.

## 빌드 gate

- `./gradlew build`: Java 언어 gate다. Spotless check 뒤 Java compile을 실행하고 Error Prone 및 javac warning을
  error로 처리한다.
- Kotlin은 `install.sh`로 한 번 연결하면 일반 `./gradlew build`에서 모듈별 ktlint와
  main/test compilation을 검사한다. 추가 Gradle 옵션이 필요 없다. 설치 전의 독립 실행은
  `./docs/lint/scripts/lint.sh kotlin`을 사용한다.
- `pnpm --dir frontend run build`: TypeScript 언어 gate다. Prettier, ESLint, `tsc -b`가 성공한 뒤에만 Vite build를
  실행한다.
- Docker image build: source inventory, frontend, backend, Python lint stage가 모두 성공해야
  runtime image를 만들 수 있다. 현재 Rust 소스가 없으므로 Rust stage는 없으며, first-party
  Rust 추가는 같은 변경에서 Docker Rust lint/build stage를 만들기 전까지 inventory가 차단한다.
- 저장소 전체 개발 빌드: `./scripts/build.sh`가 통합 lint 성공 뒤 backend와 frontend를
  빌드하며, root Cargo workspace가 생기면 Rust target도 함께 빌드한다.

현재 저장소에는 별도 CI pipeline 설정이 없다. CI가 추가되면 merge/build의 필수 job에서
`./scripts/build.sh`를 호출해야 저장소 전체 gate와 동일한 정책이 적용된다.

빌드에서 `lint`를 제외하는 옵션은 표준 경로가 아니다. 긴 테스트를 생략할 수는 있어도
formatter, lint, type check는 생략하지 않는다.

## 도구 버전

| 영역 | 고정 버전 |
| --- | --- |
| Spotless Gradle | `8.8.0` |
| ktlint | `1.8.0` |
| Palantir Java Format | `2.96.0` |
| Error Prone Gradle / core | `5.1.0` / `2.50.0` |
| ESLint / typescript-eslint | lockfile의 `10.5.0` / `8.61.1` |
| Prettier | `3.9.6` |
| pnpm | `10.32.1` |
| Ruff | `0.16.2` |
| mypy | `2.3.0` |
| Rust | `1.97.1`, edition/style edition 2024 |

기존 프로젝트이므로 무조건 최신 버전으로 올리지 않는다. 공식 release와 Java 25,
TypeScript 6, Python 3.14 runtime, Rust MSRV 호환성을 확인하고 한 번에 한 도구군씩
업데이트한다.

TS 7로 빌드하는 소비 저장소는 `typescript`를 `@typescript/typescript6`로 alias하고 `tsc`만
TS 7 native로 받는다. typescript-eslint가 아직 TS 7 API를 지원하지 않기 때문이며, lint가
읽는 언어 버전은 그대로 TS 6이다. 자세한 배선은 [TypeScript](typescript.md)에 있다.

## 세부 문서

- [Java](java.md)
- [Kotlin](kotlin.md)
- [TypeScript](typescript.md)
- [Python](python.md)
- [Rust](rust.md)
- [공개 근거와 SENA 결정](sources.md)
