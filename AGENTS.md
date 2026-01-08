# nyon-game Agent Guidelines (AGENTS.md)

This document describes recommended workflows, coding standards, and operational constraints for agent-driven work inside the nyon-game repository. It is designed for both human contributors and automated coding agents that operate in this workspace.

Note: Cursor rules (in .cursor/rules) or Copilot rules (in .github/copilot-instructions.md) may exist. If present, follow those rules and update this file accordingly.

## 1) Build, Lint, and Test Commands

- Core builds
  - ``zig build`` — Compile the sandbox executable for the current target.
  - ``zig build run`` — Run the desktop sandbox (raylib backend on Windows).
  - ``zig build run-editor`` — Build and run the editor UI.
  - ``zig build wasm`` — Emit WebAssembly target and assets for web builds.
  - ``zig fmt`` — Auto-format all Zig sources.
  - ``zig fmt --check`` — Verify formatting without changing files.

- Testing
  - ``zig build test`` — Run all test blocks in source files.
  - ``zig build test -- <file.zig>`` — Run tests contained in a specific file.
  - ``zig test <path/to/file.zig>`` — Run Zig tests directly for a single test file.
  - For focused, targeted tests, pick the file first and then narrow by test blocks inside that file.

- Platform notes
  - Desktop / raylib: ``zig build run``.
  - Web / WebGPU: ``zig build wasm``.

- Quick validation checklist (idle in CI, but useful locally)
  - Run: ``zig fmt --check`` and fix issues if any.
  - Run: ``zig build`` and ensure no warnings escalate to errors.
  - Run: ``zig build test`` and ensure all tests pass.

## 2) Build/CI Hygiene and Tooling

- Use the Zig-provided toolchain consistently with the repository's target triple and system libs as configured in the build.zig files.
- When adding new dependencies or changing interfaces, update any tests that exercise those surfaces.
- Do not push or publish secrets (environment variables, credentials) in diffs or commits.
- Prefer deterministic builds by pinning relevant options in build.zig where feasible (e.g., -ODebug for development, -OReleaseFast for releases).

## 3) Code Style Guidelines

These guidelines describe conventions for readability, maintainability, and safety. They complement Zig's formatting with intentional decisions about structure and naming.

- General philosophy
  - Strive for clarity and minimalism. Clear API boundaries and documented behavior trump cleverness.
  - Enforce formatting via ``zig fmt`` and treat it as a non-negotiable pre-commit step.
  - Prefer small, well-scoped units. If a function grows too large, extract logical pieces into helpers or modules.

- Imports and modules
  - Place all imports at the top of the file.
  - Group imports in this order: standard library, third-party, project-local.
  - Avoid wildcard imports; use explicit import paths and namespace qualifiers when necessary.
  - Namespace collisions should be avoided through module aliasing (e.g., ``const json = @import("std").json;``).

- Naming conventions
  - Files/modules: snake_case (e.g., ``asset_manager.zig``).
  - Functions/variables: snake_case.
  - Public types/classes: PascalCase (e.g., ``AssetHandle``).
  - Enums: PascalCase.
  - Constants: ALL_CAPS with underscores (e.g., ``MAX_PLAYERS``).

- Error handling
  - Expose explicit error sets (``error{...}``) for public APIs.
  - Propagate with ``try`` where possible; avoid silent failures.
  - Convert low-level errors to domain-specific errors when crossing module boundaries.
  - Document error semantics in public items via doc-comments.

- Types and data structures
  - Use Zig unions and optionals where they improve safety.
  - Prefer explicit discriminants for error cases, and name error variants clearly.
  - Annotate unsafe or boundary-boundary operations with comments clarifying invariants.

- Memory management
  - Controllers should pass explicit ``allocator`` parameters where memory allocation occurs.
  - Favor stack-allocated structs when lifetimes are short; otherwise, use a well-scoped allocator.
  - Avoid leaks by ensuring proper deallocation patterns and using ``deinit`` when needed.

- Public APIs and documentation
  - Use doc comments ``///`` to describe behavior, arguments, return values, and error cases.
  - Maintain a minimal public surface; avoid exposing internal details.
  - Update related tests and examples when public surfaces change.

- Testing discipline
  - Each public surface should have unit tests if feasible.
  - Integration tests live in-domain where they test cross-module behavior.
  - Use descriptive test names and inline comments for intent.

- Documentation and comments
  - Self-document the rationale behind the design decisions, especially around memory and safety trade-offs.
  - Use inline TODO markers with proper context so future maintainers can find follow-ups.

- Versioning and compatibility
  - When breaking changes are necessary, include a migration note in the changelog and a brief code-comment rationale.
  - Consider semver-like stabilization for major public API surfaces.

- Code review expectations
  - Review for correctness, safety, and alignment to conventions.
  - Ensure tests cover changes and do not regress existing behavior.

## 3) Cursor Rules and Copilot Guidance

- Cursor Rules (if present)
  - Respect per-file cursor constraints; avoid modifying sections locked by cursor sessions.
  - Communicate any conflicts to the requester; revert targeted edits if constraints are violated.

- Copilot Rules (if present)
  - Follow the repo's copilot-instructions with a bias toward explicit, minimal edits.
  - Provide rationale for changes and avoid introducing large, sweeping rewrites purely from AI suggestions.

- Status in this workspace
  - No Cursor rules directory or Copilot instruction file detected at build time. Add them if introduced later and re-run this integration.

## 4) Editing Protocols for Agents

- Before editing
  - Run formatting and basic tests locally to catch obvious issues early.
  - Scope changes to small, testable units; prefer incremental diffs.

- During editing
  - Explain edits with short rationale in a PR description or inline comments.
  - Keep diffs focused on the task; avoid unrelated changes.

- After editing
  - Re-run ``zig fmt --check``, ``zig build``, and tests.
  - Add/adjust tests for any public API changes.

## 5) Repository Hygiene

- Never commit credentials or secrets.
- Use meaningful, concise commit messages focusing on intent (the why).
- Prefer small, atomic commits; avoid large rewrites in a single commit.
- When in doubt, break changes into multiple commits with clear messages.

## 6) Verification Checklist

- [x] Build succeeds locally with ``zig build``.
- [x] All tests pass with ``zig build test``.
- [x] Code formatted with ``zig fmt --check``.
- [x] Lint/style checks pass (where applicable).
- [ ] Cursor rules are respected (if introduced).
- [ ] Copilot rules are respected (if introduced).

## 7) Known Blockers and Notes

- Vendor sysgpu interface drift in ``deviceCreateRenderPipeline`` remains a risk for non-raylib paths.
- Raygui bindings for UI are currently stubs; real bindings may be integrated later.
- This AGENTS.md will be updated as blockers are resolved or new tooling is introduced.

## 8) Quick Reference Commands (copy-paste)

- Build: ``zig build``
- Run: ``zig build run``
- Editor: ``zig build run-editor``
- Web: ``zig build wasm``
- Format: ``zig fmt``; Check: ``zig fmt --check``
- Test all: ``zig build test``; Test file: ``zig build test -- path/to/file.zig``; Single file: ``zig test path/to/file.zig``

## 9) Glossary

- Zig: The Zig programming language.
- allocator: Memory allocator interface passed to functions.
- unittest: Zig's internal testing mechanism.
- surface: Public API interface exposed by a module.

