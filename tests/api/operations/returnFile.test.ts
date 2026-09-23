import { describe } from "bun:test";
import { setupStudio, makeApiRunFn } from "../helpers.js";
import { returnFile } from "../../utils/executionTests.js";

const ctx = setupStudio();

describe("return file (API)", () => {
  returnFile(makeApiRunFn(ctx));
});
