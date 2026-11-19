// SPDX-License-Identifier: Apache-2.0
import js from "@eslint/js";
import header from "eslint-plugin-header";
import i18next from "eslint-plugin-i18next";
import jsxA11y from "eslint-plugin-jsx-a11y";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";
import tseslint from "typescript-eslint";

// eslint-plugin-header 3.x predates flat config and needs this flag.
header.rules.header.meta.schema = false;

export default tseslint.config(
  { ignores: ["**/dist/**", "**/build/**", "**/node_modules/**", "backend/**", "**/coverage/**"] },
  js.configs.recommended,
  tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
    plugins: { header },
    rules: {
      "header/header": ["error", "line", " SPDX-License-Identifier: Apache-2.0"],
    },
  },
  { files: ["**/*.{js,mjs,cjs}"], extends: [tseslint.configs.disableTypeChecked] },
  {
    files: ["frontend/src/**/*.{ts,tsx}"],
    extends: [reactHooks.configs.flat.recommended, jsxA11y.flatConfigs.strict],
  },
  {
    files: ["frontend/src/features/**/*.{ts,tsx}", "frontend/src/ui/**/*.{ts,tsx}"],
    ignores: ["**/*.test.{ts,tsx}", "**/*.stories.{ts,tsx}", "**/messages.it.ts"],
    extends: [i18next.configs["flat/recommended"]],
  },
);
