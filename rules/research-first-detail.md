# Research-First Workflow — detailed examples

## 5-step process

```
1. RESEARCH    → Search for prior art in English (Stack Overflow, GitHub Issues, Reddit)
2. COLLECT     → Record all solutions + source credibility
3. ANALYSE     → Is it current? Do 3+ sources agree?
4. PRESENT     → Offer solution with "why" explanation + sources
5. IMPLEMENT   → Only after user confirmation
```

## Example

```
User: "I'm getting a CORS error when calling the API"

WRONG: [Immediately adds headers to the code]

RIGHT:
  1. WebSearch("CORS error API call solutions 2025")
  2. Finds 3 approaches: proxy, server headers, browser extension
  3. Majority recommend the server-side solution

  "I found 3 main approaches to the CORS problem:
   1. Server-side headers (recommended by most sources)
   2. Proxy server (if you don't control the API)
   3. Browser extension (dev only)
   Sources: Stack Overflow (500+ upvotes), MDN docs
   Which approach do you want to use?"
```

## Exceptions (skip the research step)

- Trivial changes (typos, formatting)
- User explicitly says "do it this way"
- Standard operations (git commit, npm install)
- Solution is 100% unambiguous

## Supervisor / autonomous mode variant

In an autonomous run, steps 4–5 change:
- 3+ sources agree → implement without asking
- 2 sources agree, 0 disagree → implement, log the decision
- No consensus → try the most common solution, log the risk
- Sources contradict each other → start with the safer variant
