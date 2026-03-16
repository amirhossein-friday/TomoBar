---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** Implementation plan is based on a given spec file (`.friday/specs/<spec-name>.md`) (created by brainstorming skill). 
- If the spec file is not given or clear, STOP and ASK.
- If the acceptance criteria is not provided/specified or is not concrete enough, STOP and ASK.

**Save plans to:** `.friday/impl-plans/YYYY-MM-DD-<spec-name>.md`

## Workflow

- Study the spec and context throughly, use subagents if as much as needed
- LOAD test-driven-development skill to understand TDD best-practices to be able to write the plan accordingly
- Write the implementation plan
- Launch a subagent to review your plan and make sure it adheres to the spec/design
- Make adjustment if needed

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use subagent-driven-development to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Spec:** `.friday/specs/<spec-name>.md` (Extremely important! MUST READ)

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Branch:** '<branch-name>'

**Acceptance Criteria**
- ...
- ...

---
```

## Task Structure

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

```bash
git add ...
git commit ...
```
```

Make sure to replace the run/test command with respect to the available tech stack!

## Remember
- **NEVER skip TDD-based approach for the implementation plan.** This is what allows the implementer agent to verify its work.
- Exact file paths always
- DON'T put exact detailed implementation code. This is an implementation plan, not the exact code. It's okay to put code high-level outlines if needed.
- Make sure all implementation details are stated in the plan.
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits