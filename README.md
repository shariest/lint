# lint

Java, TypeScript, Python, Rust 정적 검사 표준의 단일 원본 저장소.

각 프로젝트는 이 저장소를 Git submodule로 등록해서 `config/` 아래의 canonical 설정 파일을
그대로 참조한다. 규칙을 프로젝트마다 복사해두지 않으므로, 표준이 바뀌면 submodule
포인터만 옮기면 된다.

- 표준 정의: [standards.md](standards.md)
- 언어별 문서: [Java](java.md) · [TypeScript](typescript.md) · [Python](python.md) · [Rust](rust.md)
- 공개 근거: [sources.md](sources.md)

## 구성

```
config/
  java/lint.gradle                  # Spotless + Error Prone + javac 정책
  typescript/eslint.config.mjs      # ESLint flat config factory
  typescript/prettier.json          # Prettier 설정
  python/pyproject.toml             # Ruff + mypy 설정
  python/requirements.txt           # lint 도구 버전 pin
  rust/rust-toolchain.toml          # toolchain 고정
  rust/rustfmt.toml                 # rustfmt 설정
  rust/clippy.toml                  # Clippy MSRV
scripts/
  install.sh                        # submodule 등록 + 언어별 adapter 생성
  lint.sh                           # 존재하는 언어 gate 실행 (check only)
```

## submodule 등록

권장 마운트 경로는 `docs/lint`다. 언어별 문서가 설정 파일을 `docs/lint/config/...`로
참조하므로, 이 경로를 쓰면 문서의 명령을 그대로 복사해 쓸 수 있다.

```bash
git submodule add http://192.168.220.222:8089/ploonet/lint.git docs/lint
git commit -m "chore: add lint standard as submodule"
```

이미 submodule이 등록된 저장소를 clone할 때는 다음 중 하나를 쓴다.

```bash
git clone --recurse-submodules <repo-url>
# 또는 이미 clone 했다면
git submodule update --init --recursive
```

표준이 갱신되면 소비 저장소에서 포인터를 옮기고 커밋한다.

```bash
git submodule update --remote docs/lint
git add docs/lint
git commit -m "chore: bump lint standard"
```

## 자동 설치

submodule을 등록한 뒤 소비 저장소의 루트에서 실행하면, 언어별 얇은 연결 파일을 만들어
준다. 설치할 언어는 저장소 구조에서 자동 감지한다.

```bash
./docs/lint/scripts/install.sh          # 무엇이 바뀌는지 먼저 보려면 -n
```

이 스크립트를 저장소 밖에서 단독으로 받아 실행하면 submodule 등록부터 수행한다.

```bash
bash install.sh -u http://192.168.220.222:8089/ploonet/lint.git -p docs/lint
```

주요 옵션:

| 옵션 | 기본값 | 설명 |
| --- | --- | --- |
| `-p PATH` | `docs/lint` | submodule 마운트 경로 |
| `-u URL` | 사내 GitLab 주소 | submodule 원본 URL |
| `-t DIR` | `frontend` | TypeScript adapter를 생성할 디렉터리 |
| `-f` | off | 기존 adapter 파일 덮어쓰기 |
| `-n` | off | dry-run. 실행할 작업만 출력 |
| `LANG...` | 자동 감지 | `java typescript python rust` 중 선택 |

언어를 지정하지 않으면 `build.gradle`, `<target>/package.json`, `*.py`, `Cargo.toml` 존재
여부로 감지한다.

## 언어별 연결 방식

`install.sh`가 만드는 파일과 동일한 내용을 직접 만들어도 된다. 어느 쪽이든 규칙 자체는
`config/` 밖에서 다시 정의하지 않는다.

### Java

루트 `build.gradle`에서 plugin만 bootstrap하고 canonical 파일을 불러온다.

```groovy
plugins {
    id 'com.diffplug.spotless' version '8.8.0'
    id 'net.ltgt.errorprone' version '5.1.0'
}

apply from: "$rootDir/docs/lint/config/java/lint.gradle"
```

```bash
./gradlew lintJava
```

### TypeScript

`frontend/eslint.config.js`는 frontend가 소유한 npm dependency를 canonical factory에 주입하는
adapter다.

```js
import js from '@eslint/js'
import prettierConfig from 'eslint-config-prettier'
import unusedImports from 'eslint-plugin-unused-imports'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import tseslint from 'typescript-eslint'
import { defineConfig, globalIgnores } from 'eslint/config'
import { createFrontendEslintConfig } from '../docs/lint/config/typescript/eslint.config.mjs'

export default createFrontendEslintConfig({
  js,
  prettierConfig,
  unusedImports,
  globals,
  reactHooks,
  reactRefresh,
  tseslint,
  defineConfig,
  globalIgnores,
  tsconfigRootDir: import.meta.dirname,
})
```

같은 디렉터리의 `frontend/.prettierrc.cjs`는 IDE 자동 탐색용 adapter이며, CLI는 canonical
JSON을 `--config`로 직접 읽는다.

```js
module.exports = require('../docs/lint/config/typescript/prettier.json')
```

필요한 dev dependency:

```bash
pnpm --dir frontend add -D eslint @eslint/js typescript-eslint eslint-config-prettier \
  eslint-plugin-unused-imports eslint-plugin-react-hooks eslint-plugin-react-refresh \
  globals prettier
```

### Python

설정 파일 위치와 무관하게 동작하도록 검사 대상은 명령에서 명시적으로 전달한다.

```bash
python3.10 -m venv .lint-venv
./.lint-venv/bin/pip install -r docs/lint/config/python/requirements.txt
./.lint-venv/bin/ruff format --config docs/lint/config/python/pyproject.toml --check <sources>
./.lint-venv/bin/ruff check  --config docs/lint/config/python/pyproject.toml <sources>
./.lint-venv/bin/mypy --config-file docs/lint/config/python/pyproject.toml <sources>
```

### Rust

rustup·rustfmt·Clippy의 표준 자동 탐색을 유지하기 위해, 루트에 같은 이름의 상대 symlink만
둔다.

```bash
ln -s docs/lint/config/rust/rust-toolchain.toml rust-toolchain.toml
ln -s docs/lint/config/rust/rustfmt.toml rustfmt.toml
ln -s docs/lint/config/rust/clippy.toml clippy.toml
```

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
```

## 검사 실행

```bash
./docs/lint/scripts/lint.sh
```

존재하는 언어 gate만 골라 check-only로 실행하고, 하나라도 실패하면 즉시 종료한다.
자동 수정은 실행하지 않는다.

| 옵션 | 설명 |
| --- | --- |
| `-p PATH` | submodule 경로. 기본값은 스크립트 위치에서 유도 |
| `-t DIR` | TypeScript 디렉터리. 기본 `frontend` |
| `-s FILE` | Python 검사 대상. 반복 지정 가능. 생략 시 tracked `*.py` 자동 수집 |
| `LANG...` | 실행할 언어. 생략 시 자동 감지 |

Python 검사 대상을 자동 수집하면 프로젝트가 의도한 allowlist와 달라질 수 있다. 실제
gate에서는 `-s`로 대상을 고정하거나, 프로젝트의 lint script에서 명시적으로 넘긴다.

## 주의

- 이 저장소는 표준의 단일 원본이다. 소비 저장소에서 규칙을 재정의하거나 rule을 끄지 않는다.
- 예외가 필요하면 이 저장소를 고치고 근거를 [standards.md](standards.md)의 정책에 맞춰 남긴다.
- submodule은 특정 commit에 고정된다. 표준 갱신은 소비 저장소의 명시적 커밋으로만 반영된다.
