# Python lint 표준

## 선택

Ruff가 formatter, import 정렬, 일반 lint를 담당하고 mypy strict가 타입 경계를 검사한다.
Google Python Style의 가독성·명시성 원칙과 OpenAI·Anthropic Python SDK의 Ruff 및 type checker
조합을 현재 네 개 first-party Python 파일에 맞게 적용한다.

```text
runtime/target: Python 3.9
Ruff 0.16.2, target-version py39, line-length 88
mypy 1.20.0, python_version 3.9, strict
```

mypy 2.x는 Python 3.9 분석 target을 지원하지 않으므로, 현재 Corretto runtime이 제공하는
Python 3.9를 유지하는 동안 호환되는 최신 1.x인 1.20.0을 고정한다. mypy 1.20 자체는
Python 3.10 이상에서 실행하고, `python_version = 3.9`로 runtime 코드를 분석한다. runtime을
3.10 이상으로 올릴 때 이 결정을 다시 검토한다.

실행 설정과 직접 dependency pin의 단일 원본은 각각
`docs/lint/config/python/pyproject.toml`과 `requirements.txt`다. 설정 파일의 위치와 무관하게
동작하도록 검사 대상 네 파일은 `scripts/lint.sh`가 명시적으로 전달한다.

## blocking 규칙

Ruff는 다음 rule family를 검사한다.

```text
E4 E7 E9 F I N UP B C4 SIM PTH ARG RUF
```

- syntax/import/name 오류와 사용하지 않는 코드
- Python upgrade 가능 문법과 pathlib 사용
- bugbear, comprehension, simplify 계열 correctness 문제
- 인자와 반환값을 포함한 strict typing
- formatting, import ordering, LF newline

한국어 설명문에 정상적으로 쓰이는 Unicode 문장부호를 오탐하는 `RUF001`~`RUF003`만
제외한다. 줄 길이는 formatter가 구조적으로 다룰 수 없는 URL·문자열 때문에 E501을 별도
선택하지 않고 formatter의 88자 정책으로 관리한다.

## 대상과 생성 도구

`tool-runner/tools/`는 런타임에 생성되므로 기본 제외한다. 단, 생성 도구의 계약 예제인
`_example.py`는 팀이 유지보수하는 template이라 검사한다. `__pycache__`, `*.pyc`, Ruff/mypy
cache는 소스가 아니며 Git에 저장하지 않는다. `scripts/lint.sh`는 추적 중이거나 아직
untracked인 `*.py`/`*.pyi`를 inventory하고, 문서화된 네 파일 외 first-party source가 생기면
조용히 제외하지 않고 실패한다. 새 파일 추가 시 `docs/lint/config/python`, lint script,
Docker lint stage의 allowlist를 같은 변경에서 갱신한다.

## 사용법

```bash
python3.10 -m venv .lint-venv
./.lint-venv/bin/pip install -r docs/lint/config/python/requirements.txt
./.lint-venv/bin/ruff format \
  --config docs/lint/config/python/pyproject.toml --check <sources>
./.lint-venv/bin/ruff check \
  --config docs/lint/config/python/pyproject.toml <sources>
./.lint-venv/bin/mypy \
  --config-file docs/lint/config/python/pyproject.toml <sources>
```

자동 수정은 검토 가능한 작업 트리에서 다음처럼 수행한다.

```bash
./.lint-venv/bin/ruff check \
  --config docs/lint/config/python/pyproject.toml --fix <sources>
./.lint-venv/bin/ruff format \
  --config docs/lint/config/python/pyproject.toml <sources>
```

`# noqa`와 `# type: ignore`는 코드로 타입을 표현할 수 없는 외부 라이브러리 경계에만 검사
코드와 이유를 명시하여 사용한다.
