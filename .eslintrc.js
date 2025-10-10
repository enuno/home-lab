module.exports = {
  root: true,
  env: {
    node: true,
    es2022: true,
    browser: false,
  },
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
  },
  extends: [
    'eslint:recommended',
    'plugin:node/recommended',
    'plugin:security/recommended',
    'prettier', // Must be last to override other configs
  ],
  plugins: ['node', 'security', 'promise'],
  rules: {
    // Best Practices
    'no-console': ['warn', { allow: ['warn', 'error'] }],
    'no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
    'no-var': 'error',
    'prefer-const': 'error',
    'prefer-arrow-callback': 'error',
    'prefer-template': 'error',
    'object-shorthand': ['error', 'always'],
    'no-useless-concat': 'error',
    'prefer-destructuring': ['error', { object: true, array: false }],

    // Error Prevention
    'no-await-in-loop': 'warn',
    'no-promise-executor-return': 'error',
    'require-atomic-updates': 'error',
    'no-unreachable-loop': 'error',

    // Promise Best Practices
    'promise/always-return': 'error',
    'promise/no-return-wrap': 'error',
    'promise/param-names': 'error',
    'promise/catch-or-return': 'error',
    'promise/no-nesting': 'warn',
    'promise/no-promise-in-callback': 'warn',
    'promise/no-callback-in-promise': 'warn',
    'promise/avoid-new': 'off',

    // Security
    'security/detect-object-injection': 'off', // Too many false positives
    'security/detect-non-literal-fs-filename': 'warn',
    'security/detect-non-literal-regexp': 'warn',
    'security/detect-unsafe-regex': 'error',
    'security/detect-buffer-noassert': 'error',
    'security/detect-eval-with-expression': 'error',
    'security/detect-no-csrf-before-method-override': 'error',
    'security/detect-possible-timing-attacks': 'warn',

    // Node.js Specific
    'node/no-unpublished-require': 'off', // Allow dev dependencies in scripts
    'node/no-missing-require': 'error',
    'node/no-extraneous-require': 'error',
    'node/no-unsupported-features/es-syntax': ['error', { ignores: ['modules'] }],
    'node/prefer-global/buffer': ['error', 'always'],
    'node/prefer-global/console': ['error', 'always'],
    'node/prefer-global/process': ['error', 'always'],
    'node/prefer-promises/dns': 'error',
    'node/prefer-promises/fs': 'error',

    // Code Style (handled by Prettier, but some logical rules)
    'max-depth': ['warn', 4],
    'max-nested-callbacks': ['warn', 3],
    'max-params': ['warn', 5],
    'complexity': ['warn', 15],
  },
  overrides: [
    // TypeScript files
    {
      files: ['*.ts', '*.tsx'],
      parser: '@typescript-eslint/parser',
      parserOptions: {
        project: './tsconfig.json',
      },
      extends: [
        'plugin:@typescript-eslint/recommended',
        'plugin:@typescript-eslint/recommended-requiring-type-checking',
      ],
      plugins: ['@typescript-eslint'],
      rules: {
        '@typescript-eslint/no-unused-vars': [
          'error',
          { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
        ],
        '@typescript-eslint/explicit-function-return-type': [
          'warn',
          { allowExpressions: true },
        ],
        '@typescript-eslint/no-explicit-any': 'warn',
        '@typescript-eslint/no-non-null-assertion': 'warn',
        '@typescript-eslint/no-floating-promises': 'error',
        '@typescript-eslint/await-thenable': 'error',
        '@typescript-eslint/no-misused-promises': 'error',
        '@typescript-eslint/prefer-nullish-coalescing': 'warn',
        '@typescript-eslint/prefer-optional-chain': 'warn',
        '@typescript-eslint/strict-boolean-expressions': 'off', // Too strict for home lab
      },
    },

    // Test files
    {
      files: ['**/*.test.js', '**/*.test.ts', '**/*.spec.js', '**/*.spec.ts'],
      env: {
        jest: true,
        mocha: true,
      },
      rules: {
        'no-console': 'off',
        'max-nested-callbacks': 'off',
      },
    },

    // Configuration files
    {
      files: [
        '.eslintrc.js',
        'prettier.config.js',
        'jest.config.js',
        'webpack.config.js',
        'rollup.config.js',
      ],
      env: {
        node: true,
      },
      rules: {
        'node/no-unpublished-require': 'off',
      },
    },

    // Scripts
    {
      files: ['scripts/**/*.js', 'scripts/**/*.ts'],
      rules: {
        'no-console': 'off',
        'node/no-unpublished-require': 'off',
      },
    },
  ],
  ignorePatterns: [
    'node_modules/',
    'dist/',
    'build/',
    'coverage/',
    '*.min.js',
    'vendor/',
    '.terraform/',
  ],
};
