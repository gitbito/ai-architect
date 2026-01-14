# Architecture-Grounded Instructions

## Core Principle

**ALWAYS use BitoAIArchitect MCP for architecture knowledge — whether generating code OR answering questions about the system.**

BitoAIArchitect has indexed data that local file exploration can't see (dependencies, relationships, architecture patterns across repos, clusters, technology stacks).

---

## When to Engage Architecture Knowledge (Auto-Trigger)

### For Code Generation:
- User asks about implementation, creation, building, or "how to"
- Code will interact with APIs, services, or dependencies
- Following existing patterns matters (consistency, compatibility)
- Understanding system boundaries or architecture is relevant

### For Architecture/Repository Exploration:
- User asks about repositories, services, or system components
- Questions about dependencies or relationships between repos/services
- Questions about technology stacks, frameworks, or patterns used
- Questions about clusters, subsystems, or architectural groupings
- Any "what", "which", "how does X relate to Y" architecture questions
- Exploring the codebase structure or organization
- Questions like "what repos do we have?", "show me dependencies", "how is X architected?"

---

## Architecture Exploration Workflow

**For pure exploration/questions (not code generation):**

1. **Use BitoAIArchitect as PRIMARY source:**
   - `listRepositories` — discover all repos in the organization
   - `searchRepositories` — find repos by technology, functionality, or keywords
   - `getRepositoryInfo` — get detailed info including dependencies
   - `listClusters` / `getClusterInfo` — understand architectural groupings
   - `searchWithinRepository` — find specific information within a repo
   - `getRepositorySchema` — understand repo structure
   - `queryFieldAcrossRepositories` — compare patterns across repos
   - `searchCode` / `searchSymbols` — find code patterns across the system

2. **Supplement with local files if needed** for implementation details

3. **Present findings** with clear structure showing relationships and patterns

---

## Pre-Code-Generation Checklist (CRITICAL)

**ALWAYS attempt to use BitoAIArchitect tools IN PARALLEL with local file exploration:**

1. **API Endpoint Verification** ← MANDATORY
   - What are the ACTUAL endpoint paths? (Don't assume REST conventions)
   - How is the session/context passed? (URL path? Header? Query param?)
   - What is the actual request body format?
   - What is the actual response format? (JSON object? Streaming? SSE?)
   - Are there required headers or authentication?
   - FIND ACTUAL ROUTE/ENDPOINT DEFINITIONS in the codebase

2. **Request/Response Format Evidence** ← MANDATORY
   - Find working examples of API calls (tests, client code, docs)
   - Check actual response structure with real data
   - Verify special formats (streaming, chunked, etc.)
   - Look for middleware or interceptors that transform data
   - DON'T assume standard REST or JSON response patterns

3. **Pattern Grounding**
   - Find 2-3 existing implementations that call the same API
   - Study HOW they do it, not just WHAT they do
   - Understand architectural patterns (error handling, structure, library choices)
   - Look for conventions specific to this codebase

4. **Type/Contract Understanding**
   - What types/interfaces does the API work with?
   - Are there shared models, enums, or constants?
   - What does the actual function signature look like elsewhere?
   - What edge cases or special handling exists?

5. **Architectural Alignment**
   - Does this code belong in the right service/repo?
   - Does it respect service boundaries and relationships?
   - Are there subsystem or cluster considerations?

6. **Local Implementation Details**
   - How are similar patterns actually coded in this specific codebase?
   - What libraries, idioms, or conventions are used?
   - Copy the STYLE and APPROACH of existing code

---

## Search Strategy for API Code

When writing code that calls APIs:

1. **Search for endpoint definitions first**
   - Look for route files, controller files, handler files
   - Find the actual path and method

2. **Search for request format examples**
   - Look for: headers, authentication, etc.
   - Find test files that call the endpoint
   - Look for client code already calling this endpoint

3. **Search for response format examples**
   - Look for response parsing code
   - Find test assertions on response structure

4. **VERIFY BEFORE CODING**
   - Don't generate until you've seen actual examples
   - If endpoints don't match REST conventions, verify the actual pattern
   - Check for response and how it's parsed

---

## How to Generate Code

1. **Use BitoAIArchitect IN PARALLEL with local file exploration** to gather architecture context
   - BitoAIArchitect provides: architecture, dependencies, repo relationships, patterns across system
   - Local files provide: implementation details, exact syntax, conventions, actual API definitions
2. **VERIFY the API contract BEFORE writing code**
   - Find actual endpoint definition
   - Find actual request/response examples
   - Look for existing code calling the same endpoint
3. **Study the pattern** from both sources
4. **Generate based on evidence** — follow the patterns you found
5. **Validate alignment** — does it match the architecture and style you studied?

---

## Key Principles

✅ **Use BitoAIArchitect for ALL architecture questions** — repos, dependencies, relationships, patterns  
✅ **Use BitoAIArchitect + local files IN PARALLEL** — both are needed for complete answers  
✅ **VERIFY API contracts first** — find actual endpoint definitions and examples before coding  
✅ **Find working examples** — don't assume patterns, find them in existing code  
✅ **Search for special handling** — any special handling different from the norm, etc.  
✅ **Never ask permission** — just call BitoAIArchitect, don't ask "would you like me to search?"  
✅ **Grounded**: Generated code follows evidence from the codebase  
✅ **Consistent**: Follows existing patterns, conventions, and architectural decisions  

❌ **Never** skip BitoAIArchitect because you see local files  
❌ **Never** skip BitoAIArchitect for architecture/repo questions — it's the primary source  
❌ **Never** assume API structure based on REST conventions—verify actual implementation  
❌ **Never** generate code without finding actual endpoint definitions  
❌ **Never** assume response format—find examples of real responses  
❌ **Never** ask permission — "Would you like me to search?" is not allowed  
❌ **Never** ignore existing patterns "because it would work either way"  

---

## BitoAIArchitect Quick Reference

| Question Type | Primary Tool(s) |
|--------------|-----------------|
| "What repos do we have?" | `listRepositories` |
| "Find repos using X technology" | `searchRepositories` |
| "What are the dependencies of repo X?" | `getRepositoryInfo` with `includeOutgoingDependencies=true` |
| "What depends on repo X?" | `getRepositoryInfo` with `includeIncomingDependencies=true` |
| "How are repos grouped/clustered?" | `listClusters`, `getClusterInfo` |
| "Find code pattern across repos" | `searchCode`, `searchSymbols` |
| "Compare field across repos" | `queryFieldAcrossRepositories` |
| "What's the structure of repo X?" | `getRepositorySchema` |
| "Find X within repo Y" | `searchWithinRepository` |

---

