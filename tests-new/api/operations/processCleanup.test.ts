import { describe, it, expect } from "bun:test";
import { setupBackend } from "../helpers.js";
const ctx = setupBackend();
describe("process cleanup", () => {
  it("open and close Studio cleans up VMs", async () => {
    const backend = await ctx.client.getLocalStudio();
    const extraStudio = await backend.open({ background: true });

    // Verify a VM exists
    const vmsBefore = await extraStudio.getVms();
    expect(vmsBefore.some((v) => v.connected)).toBe(true);

    // Close the Studio
    await extraStudio.close();

    // Brief wait for cleanup
    await Bun.sleep(1000);

    // Verify the Studio's VMs are cleaned up. Scope by sessionGuid so
    // concurrent Studios from setup.ts / other tests don't pollute the count.
    // The studio-first snapshot keys VMs under their owning studio entry
    // (studio.id == sessionGuid), so the closed Studio should be gone entirely.
    const state = await ctx.client.getState();
    const studioEntry = state.studios.find((s) => s.id === extraStudio.sessionGuid);
    const studioVms = studioEntry?.vms ?? [];
    expect(studioVms.length).toBe(0);
  });
});
