# Rust lint 표준

## 현재 상태와 선택

현재 저장소에는 first-party Rust 소스나 Cargo manifest가 없다. 따라서 거짓 성공을 만들기
위해 빈 crate를 추가하지 않고, toolchain과 formatter/Clippy 정책을 먼저 고정한다.
first-party `*.rs`가 추가되면 Cargo manifest와 실제 fmt/Clippy gate가 반드시 함께 추가되어야
한다. SENA root의 `Cargo.toml`을 workspace entry point로 사용하고 하위 crate를 member로
등록한다. 독립 manifest를 root script가 추측해서 순회하지 않는다.

실행 설정의 단일 원본은 `docs/lint/config/rust/`의 `rust-toolchain.toml`, `rustfmt.toml`,
`clippy.toml`이다. rustup, rustfmt, Clippy의 표준 자동 탐색을 유지하기 위해 루트의 같은 이름
파일은 canonical 설정을 가리키는 상대 symlink로만 둔다.

```text
Rust 1.97.1
edition = 2024
rustfmt style_edition = 2024
rustfmt max_width = 100, Unix newline
Clippy MSRV = 1.97.1
```

Rust 공식 Style Guide와 rustfmt를 canonical formatting으로 사용하고, Clippy warning은 모두
error로 처리한다. Google의 공개 Rust 저장소와 OpenAI Codex, Anthropic의 공개 Rust 저장소가
사용하는 fmt check, all-target/all-feature Clippy, deny warnings 패턴을 참고한다.

## 기본 gate

각 first-party workspace에서 다음 명령이 통과해야 한다.

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-targets --all-features
```

root gate는 clean 임시 target에서 Clippy를 실행한 뒤 compiler dep-info 입력 집합을 검사한다.
Git이 추적하거나 아직 untracked인 first-party `*.rs`가 실제 workspace compile dependency로
하나라도 나타나지 않으면 orphan source로 실패한다. 단순히 Cargo target 디렉터리 아래에
있다는 이유만으로 검사 대상으로 인정하지 않는다. `include_str!`처럼 `.rs` 파일을 코드가 아닌
데이터 입력으로 사용하는 특수 사례도 dep-info에는 나타나므로 review에서 의도를 확인한다.
Cargo metadata의 모든 workspace package는
`edition = "2024"`와 `rust-version = "1.97.1"`을 명시해야 한다.
저장소 내부의 path dependency도 root workspace member여야 하며, 그렇지 않으면 workspace
Clippy/test를 우회하는 crate로 간주해 실패한다.

`clippy::all`의 기본 warning과 compiler warning을 차단한다. `pedantic`, `nursery`,
`restriction` 전체를 일괄 활성화하지 않는다. 프로젝트 성격과 오탐 비용을 확인한 lint만
workspace의 `[workspace.lints]`에 추가한다. `unsafe`가 필요한 FFI나 성능 경계는 안전성
불변식과 범위를 문서화한다.

## 예외

`modules/**`, `vendor/**`, generated binding, `target/**`는 root gate에서 제외한다. generated
binding을 사람이 수정하지 못하게 하고 generator 및 drift check를 함께 둔다. test code도
기본 검사 대상이며, `unwrap` 같은 test 전용 허용이 필요하면 test module의 최소 범위에서
이유와 함께 설정한다.

Rust 도입 변경에는 root Cargo workspace, Docker Rust lint/build stage, `scripts/build.sh`의
artifact build를 함께 포함한다. 이 셋 중 하나가 없으면 도입이 완료된 것으로 보지 않는다.
