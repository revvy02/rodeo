import { describe, it, expect } from "bun:test";
import { runRodeo } from "../helpers.js";

describe("place id (CLI)", () => {
  it("--place with ID auto-resolves universe and launches", () => {
    const result = runRodeo([
      "run", "--place", "72824109308551",
      "--source", "return game.PlaceId",
      "--show-return",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("72824109308551");
  });

  it("--place with ID and explicit --place.universe", () => {
    const result = runRodeo([
      "run", "--place", "72824109308551",
      "--place.universe", "8612861022",
      "--source", "return game.PlaceId",
      "--show-return",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("72824109308551");
  });
});
