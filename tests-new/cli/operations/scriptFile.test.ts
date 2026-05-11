import { describe, beforeAll, afterAll } from "bun:test";
import { scriptFile } from "../../utils/executionTests.js";
import { makeCliRunFn, spawnBackground, waitForVm, type BackgroundProcess } from "../helpers.js";

const PORT = 46206;

describe("script file (CLI)", () => {
  let bg: BackgroundProcess;
  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForVm(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  scriptFile(makeCliRunFn(PORT));
});
