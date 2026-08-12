# TypeScript lint 표준

## 선택

기존 React/Vite와 ESLint 구성을 유지하면서 typescript-eslint의 type-aware preset을 사용한다.
스타일은 Prettier에, 의미와 안전성은 ESLint와 `tsc -b`에 맡긴다. OpenAI Node SDK의
oxlint/oxfmt로 전환하면 현재 React 플러그인과 설정을 교체해야 하므로 이번 표준에는 도입하지
않는다. 검사 대상 확장자는 `.ts`, `.tsx`, `.mts`, `.cts`이며 선언 파일 변형도 같은 glob에
포함된다.

실행 규칙의 단일 원본은 `docs/lint/config/typescript/eslint.config.mjs`와
`prettier.json`이다. `frontend/eslint.config.js`는 frontend가 소유한 npm dependency를
canonical ESLint factory에 주입하는 adapter이고, `.prettierrc.cjs`는 IDE 자동 탐색을 위한
adapter다. CLI formatter는 canonical JSON을 `--config`로 직접 읽으며, 두 canonical 파일과
adapter 자체도 `format:check` 대상이다.

canonical 파일은 런타임별 factory 두 개를 export한다. 규칙 집합은 공유하며 런타임에
종속된 부분만 다르다.

| factory | 대상 | 차이 |
| --- | --- | --- |
| `createFrontendEslintConfig` | React/Vite 프론트엔드 | browser globals, React Hooks/Refresh 플러그인 |
| `createNodeEslintConfig` | Node 런타임 백엔드 | node globals, React 플러그인 없음, `files`/`ignores` 주입 |

`createNodeEslintConfig`의 `files`와 `ignores`는 검사 대상(source inventory)일 뿐이며
규칙이 아니다. 백엔드는 저장소마다 소스 배치가 달라서 프로젝트가 주입한다.

```text
typescript-eslint recommendedTypeChecked + projectService
no-floating-promises(ignoreVoid: false) / no-misused-promises
React Hooks recommended / React Refresh Vite
ESLint --max-warnings 0
Prettier 3.9.6
TypeScript solution build: tsc -b
```

## blocking 규칙

- 처리하지 않은 Promise, `void`로 숨긴 Promise와 잘못된 async callback
- `any`, unsafe assignment/call/member access/return
- 불필요한 type assertion과 non-null assertion
- 사용하지 않는 import, 변수, 인자
- exhaustive하지 않은 discriminated-union switch
- type-only import/export 불일치
- `eval`, implied eval, wrapper object 생성
- `==`/`!=` 사용. 단, 의도적인 nullish 비교는 허용
- React Hooks 규칙과 dependency 누락
- warning, Prettier drift, `tsc -b` 오류

React event 속성도 Promise를 직접 반환하지 않는다. 이벤트 callback은 동기 함수로 유지하고,
비동기 호출은 `await`, rejection handler가 있는 `.catch(...)`, 또는 성공·실패 handler를 모두
가진 `.then(...)` 중 하나로 종료한다. `void promise`는 실패를 숨길 수 있어 허용하지 않는다.
event 객체에서 비동기 경계 뒤에 필요한 값은 callback 안에서 먼저 읽는다.

## formatter

```json
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "printWidth": 110,
  "trailingComma": "all",
  "arrowParens": "always",
  "endOfLine": "lf"
}
```

Google TypeScript Style의 세미콜론 강제 대신 저장소의 기존 no-semicolon 규칙을 유지한다.
OpenAI와 Anthropic 공개 SDK처럼 single quote, trailing comma, arrow parentheses를 명시한다.

## Node 백엔드 연결

프론트엔드와 같은 방식으로 adapter만 둔다. React 플러그인은 주입하지 않고, 검사 대상과
generated 경로만 프로젝트가 넘긴다.

```js
import js from '@eslint/js'
import prettierConfig from 'eslint-config-prettier'
import unusedImports from 'eslint-plugin-unused-imports'
import globals from 'globals'
import tseslint from 'typescript-eslint'
import { defineConfig, globalIgnores } from 'eslint/config'
import { createNodeEslintConfig } from './docs/lint/config/typescript/eslint.config.mjs'

export default createNodeEslintConfig({
  js,
  prettierConfig,
  unusedImports,
  globals,
  tseslint,
  defineConfig,
  globalIgnores,
  tsconfigRootDir: import.meta.dirname,
  files: ['src/**/*.{ts,mts,cts}', 'tests/**/*.{ts,mts,cts}'],
  ignores: ['src/generated/**'],
})
```

필요한 dev dependency는 프론트엔드에서 React 플러그인 세 개를 뺀 것과 같다.

```bash
pnpm add -D eslint @eslint/js typescript-eslint eslint-config-prettier \
  eslint-plugin-unused-imports globals prettier
```

`projectService`는 파일마다 가장 가까운 `tsconfig.json`을 찾는다. 빌드 tsconfig가 테스트를
제외한다면 테스트 디렉터리에 자체 `tsconfig.json`을 두어 type-aware 검사 대상에 넣는다.

## TypeScript 7 프로젝트

typescript-eslint는 TS 7의 native API를 아직 지원하지 않고 `typescript` 패키지에서 TS 6
compiler API를 찾는다. TS 7로 빌드하는 프로젝트는 두 패키지를 alias로 나눠 받는다.

```json
{
  "devDependencies": {
    "@typescript/native": "npm:typescript@^7.0.2",
    "typescript": "npm:@typescript/typescript6@^6.0.2"
  }
}
```

`tsc`(빌드·typecheck)는 TS 7 native 바이너리 그대로이고, ESLint만 TS 6 API로 타입을 읽는다.
두 패키지의 언어 버전이 같아야 하므로 한쪽만 올리지 않는다.

## 사용법

```bash
pnpm --dir frontend run lint
pnpm --dir frontend run lint:fix
pnpm --dir frontend run typecheck
pnpm --dir frontend run build
```

직접 실행할 때도 canonical 설정을 명시할 수 있다.

```bash
pnpm --dir frontend exec prettier \
  --config ../docs/lint/config/typescript/prettier.json \
  --check 'src/**/*.{ts,tsx,mts,cts}' vite.config.ts
```

`tsc --noEmit`으로 대체하지 않는다. 이 저장소의 solution config는 `tsc -b`로 검사해야 한다.
generated 선언이나 upstream 코드를 예외로 추가할 때는 파일별 override와 생성 근거를 함께
남긴다.
