// The executable rules live here. frontend/eslint.config.js only resolves the
// dependencies owned by frontend/package.json and injects them into this factory.
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
