// SPDX-License-Identifier: Apache-2.0
import { defineConfig } from "@playwright/test";

// Enabled by E1; `make e2e` and the CI e2e job are stubs until then.
export default defineConfig({
  testDir: "tests",
  grepInvert: /@pending/,
  use: { baseURL: process.env["VARCO_BASE_URL"] ?? "http://localhost:8080" },
});
