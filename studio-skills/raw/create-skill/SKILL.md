---
name: create-skill
description: Guide the user through authoring or modifying a custom skill. Use when the user wants to create, edit, update, or rename a skill.
---
# Creating a Custom Skill

You are helping the user create a new custom skill for the Studio Assistant. Follow this process.

## Step 1: Gather Requirements

Use the `{ToolNames.QuestionAnswer}` tool to ask the user:

1. **What should this skill do?** Get a clear description of the task or workflow.
2. **When should it be used?** What triggers or keywords should cause the agent to invoke it.
3. **What specific instructions does the agent need?** Domain knowledge, API details, code patterns, constraints — anything the agent wouldn't already know.

If the user already described what they want in the conversation, infer from context rather than re-asking.

**Important:** Do NOT use plan mode or other heavyweight workflows. This is a simple guided creation — use `{ToolNames.QuestionAnswer}` to gather info, then call `{ToolNames.CreateSkill}`.

## Step 2: Choose a Name

Pick a short, descriptive, lowercase name using only letters, numbers, underscores, and dashes. Examples: `code-review`, `add_lighting`, `optimize-terrain`.

Names must NOT start with `rbx-` (reserved for Roblox-authored skills). Max 64 characters.

## Step 3: Write the Description

Write a single-line description that says WHAT the skill does AND WHEN to use it. Written in third person. Max 1024 chars.

### Good Examples

- "Generate commit messages by analyzing the current diff. Use when the user asks for help with commit messages or says /commit."
- "Add particle effects to selected parts. Use when the user wants particles, effects, fire, smoke, or sparkles."
- "Review code for common Roblox anti-patterns and performance issues. Use when reviewing scripts or when the user asks for a code review."

### Bad Examples

- "Helps with stuff" (too vague)
- "I can help you do things with particles" (first person, vague)
- "A skill for doing code review" (doesn't say WHEN to use it)

## Step 4: Write the Body

The body is a markdown document with instructions for the agent. Do NOT include frontmatter (`---` block) — the tool adds that automatically from the name and description.

Example structure:
```
# <Skill Title>

<Instructions for the agent — what to do when this skill is invoked>
```

### Body Guidelines

- Write clear, actionable instructions the agent should follow.
- Be concise — the agent is already smart. Only include knowledge it doesn't have.
- Include code samples if the skill involves specific APIs or patterns.
- Use headings to organize multi-step workflows.
- If the skill references Roblox APIs, include accurate method signatures.

## Step 5: Create the Skill

Once you have all three parts ready, call the `{ToolNames.CreateSkill}` tool:

```
{ToolNames.CreateSkill}({
  skill_name: "<name>",
  skill_description: "<description>",
  skill_body: "<markdown body content>"
})
```

The skill will be published and immediately available in the Skills tab.

## Step 6: Confirm

After creation, let the user know:
- The skill was created successfully
- Where they can find it (Skills tab → Personal)
- That they can edit it anytime by selecting it and clicking Open
- They can test it by asking the assistant something that should trigger it

## Modifying Existing Skills

If the user wants to edit, update, or rename an existing skill, use the `{ToolNames.EditSkill}` tool instead of creating a new one.

```
{ToolNames.EditSkill}({
  skill_name: "<current name of the skill to modify>",
  new_name: "<optional new name>",
  new_description: "<optional new description>",
  new_skill_body: "<optional new body content>"
})
```

Only pass the fields being changed — omitted fields stay unchanged. The tool handles collision checks on rename automatically.

Follow the same guidelines from Steps 2–4 when writing new names, descriptions, or bodies.

## Tips for Great Skills

- **Be specific over general.** A skill that does one thing well is better than one that tries to cover everything.
- **Include examples.** Show the agent what good output looks like.
- **State constraints.** If there are things the agent should NOT do, say so explicitly.
- **Keep it under 500 lines.** Shorter skills load faster and leave more room in the context window.
- **Test it.** After creating, ask the assistant something that should trigger the skill and verify it works.
