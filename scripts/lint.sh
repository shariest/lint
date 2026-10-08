#!/usr/bin/env bash
# Runs the language gates that the consuming repository actually has, in
# check-only mode. Nothing is auto-fixed and the first failure stops the run.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

TS_DIR='frontend'
PY_SOURCES=()
LANGS=()

usage() {
    cat <<'EOF'
Usage: lint.sh [-t DIR] [-s FILE]... [LANG...]

  -t DIR    TypeScript project directory (default: frontend)
  -s FILE   Python source to check; repeatable
            omitted: tracked and untracked *.py / *.pyi are collected
  -h        show this help

  LANG      java | kotlin | android | typescript | python | rust
            omitted: detected from the repository layout

Run from anywhere inside the consuming Git repository.
EOF
}

info() { printf '\n\033[36m==> %s\033[0m\n' "$*"; }
skip() { printf '\033[90m    skip: %s\033[0m\n' "$*"; }
die() {
    printf '\033[31mERROR\033[0m %s\n' "$*" >&2
    exit 1
}

while getopts ':t:s:h' opt; do
    case "$opt" in
        t) TS_DIR=${OPTARG%/} ;;
        s) PY_SOURCES+=("$OPTARG") ;;
        h)
            usage
            exit 0
            ;;
        :) die "option -$OPTARG requires an argument" ;;
        *) die "unknown option -$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))

for lang in "$@"; do
    case "$lang" in
        java | kotlin | android | typescript | python | rust) LANGS+=("$lang") ;;
        *) die "unknown language: $lang" ;;
    esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'not inside a Git repository'
cd "$ROOT"

if [ "${#LANGS[@]}" -eq 0 ]; then
    kotlin_sources=$(git ls-files --cached --others --exclude-standard '*.kt' '*.kts')
    java_sources=$(git ls-files --cached --others --exclude-standard '*.java')
    if [ -x ./gradlew ] && { [ -n "$java_sources" ] || [ -z "$kotlin_sources" ]; }; then LANGS+=(java); fi
    if [ -n "$kotlin_sources" ]; then LANGS+=(kotlin); fi
    if [ -f "$TS_DIR/package.json" ]; then LANGS+=(typescript); fi
    if [ -n "$(git ls-files '*.py' | head -n 1)" ]; then LANGS+=(python); fi
    if [ -f Cargo.toml ]; then LANGS+=(rust); fi
    if [ "${#LANGS[@]}" -eq 0 ]; then die 'no language detected; pass them explicitly'; fi
fi

lint_java() {
    info 'Java: Spotless + Error Prone'
    if [ ! -x ./gradlew ]; then
        skip 'no ./gradlew'
        return
    fi
    ./gradlew --console=plain --init-script "$CONFIG_DIR/gradle/lint.init.gradle" lintJava
}

lint_kotlin() {
    info 'Kotlin: Spotless + ktlint + compiler warnings as errors'
    [ -x ./gradlew ] || die 'Kotlin requires an executable ./gradlew in the repository root'
    ./gradlew --console=plain --init-script "$CONFIG_DIR/gradle/lint.init.gradle" lintKotlin
}

lint_android() {
    info 'Android: Android Lint + Java/Kotlin gates'
    [ -x ./gradlew ] || die 'Android requires an executable ./gradlew in the repository root'
    ./gradlew --console=plain --init-script "$CONFIG_DIR/gradle/lint.init.gradle" lintAndroid
}

lint_typescript() {
    info 'TypeScript: Prettier + ESLint + tsc'
    if [ ! -f "$TS_DIR/package.json" ]; then
        skip "no $TS_DIR/package.json"
        return
    fi
    command -v pnpm >/dev/null 2>&1 || die 'pnpm not found; the TypeScript gate requires pnpm'

    if grep -q '"lint"[[:space:]]*:' "$TS_DIR/package.json"; then
        pnpm --dir "$TS_DIR" run lint
        return
    fi
    local targets=('src/**/*.{ts,tsx,mts,cts}')
    if [ -f "$TS_DIR/vite.config.ts" ]; then targets+=('vite.config.ts'); fi
    pnpm --dir "$TS_DIR" exec prettier \
        --config "$CONFIG_DIR/typescript/prettier.json" \
        --check "${targets[@]}"
    pnpm --dir "$TS_DIR" exec eslint . --max-warnings 0
    pnpm --dir "$TS_DIR" exec tsc -b
}

collect_python_sources() {
    {
        git ls-files '*.py' '*.pyi'
        git ls-files --others --exclude-standard '*.py' '*.pyi'
    } | grep -Ev '(^|/)(\.lint-venv|\.venv|venv|node_modules|build|dist|target|__pycache__)/' | sort -u
}

lint_python() {
    info 'Python: Ruff + mypy'
    if [ "${#PY_SOURCES[@]}" -eq 0 ]; then
        local collected
        collected=$(collect_python_sources)
        if [ -z "$collected" ]; then
            skip 'no Python source'
            return
        fi
        while IFS= read -r line; do PY_SOURCES+=("$line"); done <<<"$collected"
        printf '    collected %d file(s); pass -s to pin the allowlist\n' "${#PY_SOURCES[@]}"
    fi

    local venv=.lint-venv
    if [ ! -x "$venv/bin/ruff" ]; then
        die "$venv is not provisioned; run install.sh or create it from $CONFIG_DIR/python/requirements.txt"
    fi
    "$venv/bin/ruff" format --config "$CONFIG_DIR/python/pyproject.toml" --check "${PY_SOURCES[@]}"
    "$venv/bin/ruff" check --config "$CONFIG_DIR/python/pyproject.toml" "${PY_SOURCES[@]}"
    "$venv/bin/mypy" --config-file "$CONFIG_DIR/python/pyproject.toml" "${PY_SOURCES[@]}"
}

lint_rust() {
    info 'Rust: rustfmt + Clippy'
    if [ ! -f Cargo.toml ]; then
        skip 'no root Cargo.toml'
        return
    fi
    cargo fmt --all --check
    cargo clippy --workspace --all-targets --all-features -- -D warnings
}

for lang in "${LANGS[@]}"; do
    "lint_$lang"
done

printf '\n\033[32m==> all gates passed\033[0m\n'
