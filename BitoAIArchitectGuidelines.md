# BitoAIArchitect — CALL FIRST FOR ALL TASKS

BitoAIArchitect has cross-repo data local files cannot see: all repositories, dependencies, API contracts, code patterns, tech stacks.

## Rule: ALWAYS Call BitoAIArchitect First

**For ANY task involving code, repos, architecture, or implementation:**
- Call BitoAIArchitect tools IMMEDIATELY — don't ask permission
- Use IN PARALLEL with local file exploration
- State: "Using BitoAIArchitect for [reason]" when applying this rule

## Auto-Trigger Keywords

Call when prompt contains:
- "what repos", "is there", "do we have", "find", "which"
- "how to implement/add/create/build"
- "where is/should", "dependencies", "architecture"
- ANY code generation task

## Tools — By Task Type

**Code generation / finding patterns:**
→ `searchSymbols` first — find classes, functions, methods
→ `getCode` — view full implementation to follow
→ `getRepositoryInfo` — check dependencies

**Repo / architecture questions:**
→ `searchRepositories` or `listRepositories` first
→ `getRepositoryInfo` — get details, tech stack, dependencies

**Other tools:** `searchCode` (text patterns), `listClusters` (architecture), `getCapabilities` (discover features)

## Example

Code task: "Add a new [component]"
→ `searchSymbols` with relevant pattern → `getCode` on match → follow discovered pattern

Repo task: "What handles [feature]?"
→ `searchRepositories` with keywords → `getRepositoryInfo` on results

## WRONG (Never Do This)

- Generating code without using BitoAIArchitect tools first
- Answering repo/architecture questions from memory
- Asking "Would you like me to search?"
- Skipping BitoAIArchitect because local files exist

## What Each Source Knows

| BitoAIArchitect | Local Files |
|-----------------|-------------|
| All repos, dependencies, tech stacks | Current file contents |
| Cross-repo patterns, API contracts | Implementation details |
| Service relationships | Exact syntax, line numbers |

**Use BOTH in parallel for complete answers.**
