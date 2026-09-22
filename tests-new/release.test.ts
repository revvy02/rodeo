import { it, expect } from "bun:test";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

it("release: bumps all authoritative stamps together and build rejects drift",()=>{
  const dir=mkdtempSync(join(tmpdir(),"rodeo-release-"));
  try {
    mkdirSync(join(dir,"rodeo-cli"),{recursive:true});
    mkdirSync(join(dir,".claude/skills/rodeo"),{recursive:true});
    for(const file of ["rodeo-cli/Cargo.toml",".claude/skills/rodeo/SKILL.md"]) writeFileSync(join(dir,file),readFileSync(file));
    const result=Bun.spawnSync(["lune","run",resolve(".lune/release.luau"),"9.8.7-rc.6"],{cwd:dir});
    expect(result.exitCode,result.stderr.toString()).toBe(0);
    expect(readFileSync(join(dir,"rodeo-cli/Cargo.toml"),"utf8")).toContain('version = "9.8.7-rc.6"');
    const skillPath=join(dir,".claude/skills/rodeo/SKILL.md");
    const skill=readFileSync(skillPath,"utf8");
    expect(skill).toContain("version: 9.8.7-rc.6");
    expect(skill).toContain("This skill describes rodeo **9.8.7-rc.6**");
    writeFileSync(skillPath,skill.replace("version: 9.8.7-rc.6","version: 9.8.7-rc.5"));
    const bad=Bun.spawnSync(["lune","run",resolve(".lune/build.luau")],{cwd:dir});
    expect(bad.exitCode).not.toBe(0);
    expect(bad.stderr.toString()+bad.stdout.toString()).toContain("stamped for rodeo");
  } finally {rmSync(dir,{recursive:true,force:true});}
});
