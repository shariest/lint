#!/usr/bin/env bash
# Registers the lint standard as a Git submodule and creates the thin adapter
# files each language toolchain auto-discovers. All executable rules stay in
# <submodule>/config; nothing is redefined in the consuming repository.
set -euo pipefail

DEFAULT_URL='http://192.168.220.222:8089/ploonet/lint.git'
SUB_PATH='docs/lint'
SUB_URL="$DEFAULT_URL"
TS_DIR='frontend'
FORCE=0
DRY=0
LANGS=()

usage() {
    cat <<'EOF'
Usage: install.sh [-p PATH] [-u URL] [-t DIR] [-f] [-n] [LANG...]

  -p PATH   submodule mount path (default: docs/lint)
  -u URL    submodule source URL
  -t DIR    TypeScript project directory (default: frontend)
  -f        overwrite existing adapter files
  -n        dry run; print actions only
  -h        show this help

  LANG      java | kotlin | typescript | python | rust
            omitted: detected from the repository layout

Run from the root of the consuming Git repository.
EOF
}

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok() { printf '    %s\n' "$*"; }
warn() { printf '\033[33m !\033[0m %s\n' "$*" >&2; }
die() {
    printf '\033[31mERROR\033[0m %s\n' "$*" >&2
    exit 1
}

run() {
    if [ "$DRY" -eq 1 ]; then
        printf '    [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# Writes stdin to $1 unless the file exists and -f was not given.
write_file() {
    local path=$1
    if [ -e "$path" ] && [ "$FORCE" -ne 1 ]; then
        warn "keep existing $path (use -f to overwrite)"
        cat >/dev/null
        return
    fi
    if [ "$DRY" -eq 1 ]; then
        printf '    [dry-run] write %s\n' "$path"
        cat >/dev/null
        return
    fi
    mkdir -p "$(dirname "$path")"
    cat >"$path"
    ok "wrote $path"
}

# Relative path from directory $2 to path $1, both given from the repo root.
relpath() {
    local target=$1 base=${2%/} up=''
    base=${base#./}
    if [ -z "$base" ] || [ "$base" = '.' ]; then
        printf '%s' "$target"
        return
    fi
    local IFS='/'
    # shellcheck disable=SC2086
    set -- $base
    while [ "$#" -gt 0 ]; do
        up="../$up"
        shift
    done
    printf '%s%s' "$up" "$target"
}

while getopts ':p:u:t:fnh' opt; do
    case "$opt" in
        p) SUB_PATH=${OPTARG%/} ;;
        u) SUB_URL=$OPTARG ;;
        t) TS_DIR=${OPTARG%/} ;;
        f) FORCE=1 ;;
        n) DRY=1 ;;
        h)
            usage
            exit 0
            ;;
        :) die "option -$OPTARG requires an argument" ;;
        *) die "unknown option -$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))

# The path is embedded in Gradle and JavaScript string literals below.
case "$SUB_PATH" in
    '' | /* | .. | ../* | */../* | */.. | *\"* | *\'* | *'$'* | *\\* | *$'\n'* | *$'\r'*)
        die 'submodule path must be relative and contain no quotes, backslashes, dollar signs or newlines'
        ;;
esac

for lang in "$@"; do
    case "$lang" in
        java | kotlin | typescript | python | rust) LANGS+=("$lang") ;;
        *) die "unknown language: $lang" ;;
    esac
done

command -v git >/dev/null 2>&1 || die 'git not found'
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'not inside a Git repository'
cd "$ROOT"

if [ "${#LANGS[@]}" -eq 0 ]; then
    kotlin_sources=$(git ls-files --cached --others --exclude-standard '*.kt' '*.kts')
    java_sources=$(git ls-files --cached --others --exclude-standard '*.java')
    if { [ -x ./gradlew ] || [ -f build.gradle ] || [ -f build.gradle.kts ]; } && { [ -n "$java_sources" ] || [ -z "$kotlin_sources" ]; }; then LANGS+=(java); fi
    if [ -n "$kotlin_sources" ]; then LANGS+=(kotlin); fi
    if [ -f "$TS_DIR/package.json" ]; then LANGS+=(typescript); fi
    if [ -n "$(git ls-files '*.py' | head -n 1)" ]; then LANGS+=(python); fi
    if [ -f Cargo.toml ]; then LANGS+=(rust); fi
    if [ "${#LANGS[@]}" -eq 0 ]; then die 'no language detected; pass them explicitly'; fi
    info "detected: ${LANGS[*]}"
fi

# --- submodule ------------------------------------------------------------
if [ -e "$SUB_PATH/config/java/lint.gradle" ]; then
    ok "submodule already present at $SUB_PATH"
elif [ -e "$SUB_PATH" ]; then
    die "$SUB_PATH exists but does not contain the lint standard"
else
    info "adding submodule $SUB_URL -> $SUB_PATH"
    run git submodule add "$SUB_URL" "$SUB_PATH"
    run git submodule update --init --recursive "$SUB_PATH"
fi

install_gradle() {
    [ -x ./gradlew ] || die 'Gradle lint requires an executable ./gradlew in the repository root'
    local marker="$SUB_PATH/config/gradle/lint.settings.gradle"
    local settings_file=settings.gradle line
    if [ ! -f settings.gradle ] && { [ -f settings.gradle.kts ] || [ -f build.gradle.kts ]; }; then
        settings_file=settings.gradle.kts
    fi
    if [ "$settings_file" = settings.gradle.kts ]; then
        line="apply(from = \"\$rootDir/$marker\")"
    else
        line="apply from: \"\$rootDir/$marker\""
    fi
    if [ -f "$settings_file" ] && grep -qxF "$line" "$settings_file"; then
        ok "$settings_file already applies the canonical policy"
        return
    fi
    if [ "$DRY" -eq 1 ]; then
        ok "[dry-run] append to $settings_file: $line"
    else
        printf '\n// Shared lint policy; installed by %s/scripts/install.sh\n%s\n' "$SUB_PATH" "$line" >>"$settings_file"
        ok "wired $settings_file; ./gradlew build now includes lint"
    fi
}

install_java() {
    info 'java'
    install_gradle
}

install_kotlin() {
    info 'kotlin'
    install_gradle
}

install_typescript() {
    info 'typescript'
    if [ ! -d "$TS_DIR" ]; then
        warn "$TS_DIR not found; skipping"
        return
    fi
    local rel
    rel=$(relpath "$SUB_PATH" "$TS_DIR")

    write_file "$TS_DIR/eslint.config.js" <<EOF
import js from '@eslint/js'
import prettierConfig from 'eslint-config-prettier'
import unusedImports from 'eslint-plugin-unused-imports'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import tseslint from 'typescript-eslint'
import { defineConfig, globalIgnores } from 'eslint/config'
import { createFrontendEslintConfig } from '$rel/config/typescript/eslint.config.mjs'

// Dependency-resolution adapter. All executable rules live under $SUB_PATH/config.
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
EOF

    write_file "$TS_DIR/.prettierrc.cjs" <<EOF
// IDE auto-discovery adapter. The canonical formatter policy lives under $SUB_PATH/config.
module.exports = require('$rel/config/typescript/prettier.json')
EOF

    ok 'required dev dependencies:'
    cat <<EOF

    pnpm --dir $TS_DIR add -D eslint @eslint/js typescript-eslint eslint-config-prettier \\
      eslint-plugin-unused-imports eslint-plugin-react-hooks eslint-plugin-react-refresh \\
      globals prettier

EOF
}

install_python() {
    info 'python'
    local py=''
    for cand in python3.14 python3; do
        command -v "$cand" >/dev/null 2>&1 || continue
        if "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 14) else 1)' 2>/dev/null; then
            py=$cand
            break
        fi
    done
    if [ -z "$py" ]; then
        warn 'no Python 3.14+ interpreter found; create .lint-venv manually'
        return
    fi
    if [ -x .lint-venv/bin/ruff ] && [ "$FORCE" -ne 1 ]; then
        ok '.lint-venv already provisioned'
    else
        ok "creating .lint-venv with $py"
        run "$py" -m venv .lint-venv
        run ./.lint-venv/bin/pip install --quiet --upgrade pip
        run ./.lint-venv/bin/pip install --quiet -r "$SUB_PATH/config/python/requirements.txt"
    fi
    add_gitignore '.lint-venv/'
}

install_rust() {
    info 'rust'
    local name
    for name in rust-toolchain.toml rustfmt.toml clippy.toml; do
        local target="$SUB_PATH/config/rust/$name"
        if [ -L "$name" ] && [ "$(readlink "$name")" = "$target" ]; then
            ok "symlink already correct: $name"
            continue
        fi
        if [ -e "$name" ] && [ "$FORCE" -ne 1 ]; then
            warn "keep existing $name (use -f to overwrite)"
            continue
        fi
        run rm -f "$name"
        run ln -s "$target" "$name"
        if [ "$DRY" -eq 0 ]; then ok "linked $name -> $target"; fi
    done
}

add_gitignore() {
    local entry=$1
    if [ -f .gitignore ] && grep -qxF "$entry" .gitignore; then
        return
    fi
    if [ "$DRY" -eq 1 ]; then
        printf '    [dry-run] append %s to .gitignore\n' "$entry"
        return
    fi
    printf '%s\n' "$entry" >>.gitignore
    ok "added $entry to .gitignore"
}

for lang in "${LANGS[@]}"; do
    "install_$lang"
done

info 'done'
cat <<EOF

Next:
  ./$SUB_PATH/scripts/lint.sh
  Commit .gitmodules, $SUB_PATH and the generated/updated adapter files.
EOF
