import { describe, beforeAll, afterAll } from "bun:test";
import { returnFile } from "../../utils/executionTests.js";
import { makeCliRunFn, spawnBackground, waitForDom, type BackgroundProcess } from "../helpers.js";

const PORT = 46208;

describe("return file (CLI)", () => {
  let bg: BackgroundProcess;
  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForDom(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  returnFile(makeCliRunFn(PORT));
});
