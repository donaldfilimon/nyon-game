# nyon-game Agent Guidelines (AGENTS.md)

This document describes recommended workflows, coding standards, and operational constraints for agent-driven work inside the nyon-game repository. It is designed for both human contributors and automated coding agents that operate in this workspace.

Note: Cursor rules (in .cursor/rules) or Copilot rules (in .github/copilot-instructions.md) may exist. If present, follow those rules and update this file accordingly.

## 1) Build, Lint, and Test Commands

- Core builds
  - ``zig build`` — Compile the sandbox executable for the current target.
  - ``zig build run`` — Run the desktop sandbox (raylib backend on Windows).
  - ``zig build run-editor`` — Build and run the editor UI.
  - ``zig build run-agent`` — Run the AI automation agent.
  - ``zig build wasm`` — Emit WebAssembly target and assets for web builds.
  - ``zig build spirv`` — Compile GPU compute shaders to SPIR-V.
  - ``zig build nvptx`` — Compile GPU shaders to PTX (NVIDIA).
  - ``zig fmt`` — Auto-format all Zig sources.
  - ``zig fmt --check`` — Verify formatting without changing files.

- Testing
  - ``zig build test`` — Run all test blocks in source files.
  - ``zig test <path/to/file.zig>`` — Run Zig tests directly for a single test file.
  - Note: Most files have cross-module dependencies requiring ``zig build test``. Use ``zig test`` only for standalone utility modules (e.g., ``src/math/math.zig``).

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
  - Functions/methods: camelCase (e.g., ``getEyePosition``, ``applyForce``, ``moveAndSlide``).
  - Variables: snake_case (e.g., ``delta_time``, ``is_grounded``, ``wish_dir``).
  - Public types/structs: PascalCase (e.g., ``AssetHandle``, ``RigidBody``).
  - Enum types: PascalCase; enum variants: snake_case (e.g., ``Projection.perspective``).
  - Constants: ALL_CAPS with underscores (e.g., ``MAX_PLAYERS``, ``GRAVITY``).

- Error handling
  - Prefer inferred error unions (``!T``) over explicit error sets for most APIs.
  - Propagate with ``try`` where possible; avoid silent failures.
  - Use ``catch`` with labeled blocks for fallback behavior when recovery is possible.
  - Return optionals (``?T``) for "not found" cases rather than errors.
  - Log errors with ``std.log.warn`` or ``std.log.err`` before fallback paths.

- Types and data structures
  - Use ``const Self = @This()`` pattern in struct implementations.
  - Provide ``init``/``deinit`` methods for structs that manage resources.
  - Use Zig unions and optionals where they improve safety.
  - Use anonymous structs for multi-value returns: ``struct { pos: Vec3, grounded: bool }``.
  - Annotate unsafe or boundary operations with comments clarifying invariants.

- Memory management
  - Controllers should pass explicit ``allocator`` parameters where memory allocation occurs.
  - Favor stack-allocated structs when lifetimes are short; otherwise, use a well-scoped allocator.
  - Avoid leaks by ensuring proper deallocation patterns and using ``deinit`` when needed.

- Public APIs and documentation
  - Use ``//!`` for file-level module documentation at the top of files.
  - Use ``///`` for function/type doc comments describing behavior and arguments.
  - Use ``//`` for inline implementation comments.
  - Maintain a minimal public surface; avoid exposing internal details.
  - Update related tests and examples when public surfaces change.

- Testing discipline
  - Tests live at the bottom of source files (no separate test directory).
  - Use ``std.testing.allocator`` for memory-leak detection in tests.
  - Use descriptive test names: ``test "world spawn and despawn" { ... }``.
  - Each public surface should have unit tests if feasible.
  - Common assertions: ``std.testing.expect``, ``expectEqual``, ``expectApproxEqAbs``.

- Documentation and comments
  - Self-document the rationale behind the design decisions, especially around memory and safety trade-offs.
  - Use inline TODO markers with proper context so future maintainers can find follow-ups.

- Versioning and compatibility
  - When breaking changes are necessary, include a migration note in the changelog and a brief code-comment rationale.
  - Consider semver-like stabilization for major public API surfaces.

- Code review expectations
  - Review for correctness, safety, and alignment to conventions.
  - Ensure tests cover changes and do not regress existing behavior.

## 4) Cursor Rules and Copilot Guidance

- Cursor Rules (if present)
  - Respect per-file cursor constraints; avoid modifying sections locked by cursor sessions.
  - Communicate any conflicts to the requester; revert targeted edits if constraints are violated.

- Copilot Rules (if present)
  - Follow the repo's copilot-instructions with a bias toward explicit, minimal edits.
  - Provide rationale for changes and avoid introducing large, sweeping rewrites purely from AI suggestions.

- Status in this workspace
  - No Cursor rules directory or Copilot instruction file detected at build time. Add them if introduced later and re-run this integration.

## 5) Editing Protocols for Agents

- Before editing
  - Run formatting and basic tests locally to catch obvious issues early.
  - Scope changes to small, testable units; prefer incremental diffs.

- During editing
  - Explain edits with short rationale in a PR description or inline comments.
  - Keep diffs focused on the task; avoid unrelated changes.

- After editing
  - Re-run ``zig fmt --check``, ``zig build``, and tests.
  - Add/adjust tests for any public API changes.

## 6) Repository Hygiene

- Never commit credentials or secrets.
- Use meaningful, concise commit messages focusing on intent (the why).
- Prefer small, atomic commits; avoid large rewrites in a single commit.
- When in doubt, break changes into multiple commits with clear messages.

## 7) Verification Checklist

- [x] Build succeeds locally with ``zig build``.
- [x] All tests pass with ``zig build test``.
- [x] Code formatted with ``zig fmt --check``.
- [x] Lint/style checks pass (where applicable).
- [ ] Cursor rules are respected (if introduced).
- [ ] Copilot rules are respected (if introduced).

## 8) Known Blockers and Notes

- Vendor sysgpu interface drift in ``deviceCreateRenderPipeline`` remains a risk for non-raylib paths.
- Raygui bindings for UI are currently stubs; real bindings may be integrated later.
- This AGENTS.md will be updated as blockers are resolved or new tooling is introduced.

## 9) Quick Reference Commands (copy-paste)

- Build: ``zig build``
- Run: ``zig build run``
- Editor: ``zig build run-editor``
- Web: ``zig build wasm``
- Format: ``zig fmt``; Check: ``zig fmt --check``
- Test all: ``zig build test``; Single file: ``zig test path/to/file.zig``

## 10) Glossary

- Zig: The Zig programming language (v0.16.0-dev).
- allocator: Memory allocator interface passed to functions.
- test block: Zig's ``test "name" { ... }`` mechanism for unit tests.
- surface: Public API interface exposed by a module.
- Self: Common alias for ``@This()`` in struct implementations.
