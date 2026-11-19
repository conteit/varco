// SPDX-License-Identifier: Apache-2.0
import { expect, it } from "vitest";
import { BRAND_NAME } from "./index";

it("exports the default brand name", () => {
  expect(BRAND_NAME).toBe("Varco");
});
