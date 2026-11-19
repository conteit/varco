// SPDX-License-Identifier: Apache-2.0
import { render, screen } from "@testing-library/react";
import { expect, it } from "vitest";
import { App } from "./App";

it("renders the app shell", () => {
  render(<App />);
  expect(screen.getByRole("heading", { name: "Varco" })).toBeTruthy();
});
