// The executable rules live here. <project>/eslint.config.js only resolves the
// dependencies owned by that project's package.json and injects them into a factory.

// 프론트엔드와 Node 백엔드가 공유하는 규칙. 런타임(browser/node)과 React 플러그인만
// 각 factory에서 다르게 얹는다.
const sharedRules = {
  eqeqeq: ['error', 'always', { null: 'ignore' }],
  'no-eval': 'error',
  'no-implied-eval': 'error',
  'no-new-wrappers': 'error',
  '@typescript-eslint/consistent-type-exports': 'error',
  '@typescript-eslint/consistent-type-imports': [
    'error',
    { fixStyle: 'inline-type-imports', prefer: 'type-imports' },
  ],
  '@typescript-eslint/no-explicit-any': 'error',
  '@typescript-eslint/no-empty-function': 'error',
  '@typescript-eslint/no-non-null-assertion': 'error',
  '@typescript-eslint/no-misused-promises': 'error',
  '@typescript-eslint/no-floating-promises': ['error', { ignoreVoid: false }],
  '@typescript-eslint/no-unused-vars': [
    'error',
    {
      argsIgnorePattern: '^_',
      caughtErrorsIgnorePattern: '^_',
      varsIgnorePattern: '^_',
    },
  ],
  '@typescript-eslint/switch-exhaustiveness-check': 'error',
  'unused-imports/no-unused-imports': 'error',
}

export function createFrontendEslintConfig({
  js,
  prettierConfig,
  unusedImports,
  globals,
  reactHooks,
  reactRefresh,
  tseslint,
  defineConfig,
  globalIgnores,
  tsconfigRootDir,
}) {
  return defineConfig([
    globalIgnores(['dist/**', 'node_modules/**']),
    {
      files: ['src/**/*.{ts,tsx,mts,cts}', 'vite.config.ts'],
      extends: [
        js.configs.recommended,
        tseslint.configs.recommendedTypeChecked,
        reactHooks.configs.flat.recommended,
        reactRefresh.configs.vite,
      ],
      languageOptions: {
        ecmaVersion: 2023,
        parserOptions: {
          projectService: true,
          tsconfigRootDir,
        },
      },
      plugins: {
        'unused-imports': unusedImports,
      },
      rules: {
        ...sharedRules,
        // 커스텀 훅 deps 검사 — useFetch/usePaginatedList의 fn 클로저에서 deps 누락 방지
        'react-hooks/exhaustive-deps': [
          'error',
          {
            additionalHooks: '(useFetch|usePaginatedList)',
          },
        ],
      },
    },
    {
      files: ['src/**/*.{ts,tsx,mts,cts}'],
      languageOptions: {
        globals: globals.browser,
      },
    },
    {
      files: ['vite.config.ts'],
      languageOptions: {
        globals: globals.node,
      },
    },
    // 포맷 규칙 충돌을 끄되 Prettier 자체 검사는 별도 blocking task로 실행한다.
    prettierConfig,
  ])
}

// Node 런타임 백엔드용. 규칙은 frontend factory와 같고 React 플러그인과 browser
// globals만 빠진다. 검사 대상과 추가 ignore는 프로젝트 구조에 맞춰 주입한다.
// (source inventory는 프로젝트가 정하고, 규칙은 여기서만 정의한다.)
export function createNodeEslintConfig({
  js,
  prettierConfig,
  unusedImports,
  globals,
  tseslint,
  defineConfig,
  globalIgnores,
  tsconfigRootDir,
  files = ['src/**/*.{ts,mts,cts}'],
  ignores = [],
}) {
  return defineConfig([
    globalIgnores(['dist/**', 'node_modules/**', ...ignores]),
    {
      files,
      extends: [js.configs.recommended, tseslint.configs.recommendedTypeChecked],
      languageOptions: {
        ecmaVersion: 2023,
        globals: globals.node,
        parserOptions: {
          projectService: true,
          tsconfigRootDir,
        },
      },
      plugins: {
        'unused-imports': unusedImports,
      },
      rules: sharedRules,
    },
    // 포맷 규칙 충돌을 끄되 Prettier 자체 검사는 별도 blocking task로 실행한다.
    prettierConfig,
  ])
}
