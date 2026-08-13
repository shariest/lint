# Python lint 표준

## 선택

Ruff가 formatter, import 정렬, 일반 lint를 담당하고 mypy strict가 타입 경계를 검사한다.
Google Python Style의 가독성·명시성 원칙과 OpenAI·Anthropic Python SDK의 Ruff 및 type checker
조합을 현재 네 개 first-party Python 파일에 맞게 적용한다.

```text
runtime/target: Python 3.14
Ruff 0.16.2, target-version py314, line-length 88
mypy 2.3.0, python_version 3.14, strict
```

표준은 현재 stable 최신인 Python 3.14를 분석 target으로 고정한다. mypy 2.x는 3.10 이상
분석 target만 받으므로, 3.14 target에서는 최신 2.x 라인을 그대로 쓸 수 있다. lint 환경과
분석 target이 같은 버전이라 `.lint-venv`를 만드는 interpreter가 곧 target 검증이 된다.

이 표준을 채택하는 저장소는 코드를 **실제로 실행하는** 환경도 Python 3.14여야 한다.
`target-version = py314`는 `UP` rule이 `Optional[X]`를 `X | None`처럼 3.10+ 전용 문법으로
바꾸도록 요구하기 때문에, runtime이 더 낮으면 lint는 통과하면서 import 시점에
`TypeError`가 난다. runtime을 먼저 올리고 submodule pointer를 옮긴다.

실행 설정과 직접 dependency pin의 단일 원본은 각각
`docs/lint/config/python/pyproject.toml`과 `requirements.txt`다. 설정 파일의 위치와 무관하게
동작하도록 검사 대상 네 파일은 `scripts/lint.sh`가 명시적으로 전달한다.

## 프로파일

소비 저장소가 코드로 회피할 수 없는 framework 경계를 갖거나 분석 target이 다르면
`config/python/<name>/pyproject.toml`에 프로파일을 둔다. rule family·line-length·format
정책은 `[tool.ruff] extend`로 기본 프로파일을 그대로 상속하고 필요한 항목만 덮어쓴다.
기본 프로파일은 손대지 않으므로 다른 저장소에 영향이 없다.

| 프로파일 | 분석 target | 사용처 | 덮어쓰는 항목 |
| --- | --- | --- | --- |
| `config/python/pyproject.toml` | 3.14 | SENA | — |
| `config/python/py314/pyproject.toml` | 3.14 | document-parser (`python-service`) | FastAPI 인자 선언, 테스트 double의 ARG |

분석 target은 소비 저장소가 코드를 **실제로 실행하는** Python 버전과 같아야 한다.
`UP` rule이 그 버전 전용 문법으로 코드를 다시 쓰기 때문에, target이 runtime보다 높으면
lint는 통과하면서 runtime에서 `SyntaxError`가 난다. 반대로 낮으면 통과는 하지만 표준이
요구하는 최신 문법으로 올라가지 않는다.

새 프로파일을 추가할 때는 이 표와 `[tool.mypy]` 블록(mypy는 설정 상속이 없어 복제해야
한다)을 같은 변경에서 갱신한다.

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
제외한다. 테스트 파일의 `N802`도 제외한다 — 테스트 함수명을 한글 문장으로 쓰는 저장소가
있고 그 이름이 곧 테스트 문서다. 한글은 대소문자가 없어 규칙을 만족시킬 방법이 없다.
제품 코드의 `N802`는 그대로 blocking이다. 같은 판단의 Java 쪽 대응은 [java.md](java.md)의
`UnicodeInCode` 항목이다. 줄 길이는 formatter가 구조적으로 다룰 수 없는 URL·문자열 때문에 E501을 별도
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
python3.14 -m venv .lint-venv
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

무거운 런타임 의존성(torch·transformers·peft·trl·sentence-transformers·huggingface-hub·
datasets·PyYAML)은 lint 환경에 설치하지 않고 `ignore_missing_imports`로 둔다. CUDA torch
스택만 수 GB라 lint 한 번에 그 비용을 치를 이유가 없다. 이 예외는 **해당 모듈의 타입만**
Any로 만든다 — first-party 함수의 인자·반환 타입 누락은 그대로 blocking이다.

`# noqa`와 `# type: ignore`는 코드로 타입을 표현할 수 없는 외부 라이브러리 경계에만 검사
코드와 이유를 명시하여 사용한다.
