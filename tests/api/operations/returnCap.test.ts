import { describe } from "bun:test";
import { setupStudio, makeApiRunFn } from "../helpers.js";
import { returnValueCap } from "../../utils/executionTests.js";

const ctx = setupStudio();

describe("return value wire cap (API)", () => {
  returnValueCap(makeApiRunFn(ctx));
});
