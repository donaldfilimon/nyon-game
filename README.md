# NYON — Sandbox and Engine Lineage

The earlier NYON creative-sandbox and engine source tree, implemented in Zig.
It preserves experiments around editable 3D worlds, editor interfaces,
procedural geometry, and platform integration.

**Looking for the retained Rust game and Galaxy Workshop?** Start at
[`donaldfilimon/NYON`](https://github.com/donaldfilimon/NYON). That repository has
its own Rust toolchain, simulation contracts, player manual, and native/browser
qualification. It is not interchangeable with this Zig source tree.

NYON's broader direction is creative-first, with optional Survival and
Geometry Nodes. Those product goals do not prove that every subsystem in this
historical engine is complete. The Donald Company's separate LYLX intelligence
program does not automatically migrate this repository or replace its code.

## Source and status

The checked-in [`build.zig`](build.zig) defines a game executable, an editor,
an automation-agent executable, tests, and experimental shader/WebAssembly
targets. Source declarations and prior documentation are not fresh build,
performance, portability, or runtime results.

The raylib dependency remains declared in [`build.zig.zon`](build.zig.zon).
Do not infer that every backend is integrated or working from the dependency
list. [AGENTS.md](AGENTS.md) records unfinished raygui bindings and non-raylib
interface risks. Earlier claims such as "bulletproof," "industry-grade," or
unqualified cross-platform deployment are not acceptance evidence.

## Toolchain and setup

`build.zig.zon` declares:

```text
minimum_zig_version = 0.16.0-dev.2075+62d6bbc7d
```

This is the manifest's **minimum**, not a guarantee that all later development
compilers are compatible. Record the exact Zig version used and validate it
against this source. The Rust 1.99.1 target of the separate NYON/LYLX programs
must not be substituted into this repository's build instructions without an
actual port.

```bash
git clone https://github.com/donaldfilimon/nyon-game.git
cd nyon-game
zig version
zig build --help
zig build
zig build run
```

`zig build` installs the declared game, editor, and agent artifacts, so its
requirements can be broader than running one specific target. Review the
platform modules and system-library requirements before assuming portability.
The agent imports a Win32 automation module; building or listing it does not
establish working automation on other platforms.

## Build targets defined in source

| Command | Declared purpose | Qualification boundary |
| --- | --- | --- |
| `zig build` | Build/install the game, editor, and agent artifacts. | Requires a compatible compiler and target environment. |
| `zig build run` | Build and run `nyon_game`. | Requires live desktop/graphics acceptance. |
| `zig build run-editor` | Build and run `nyon_editor`. | Does not establish every documented editor feature. |
| `zig build test` | Run tests reached through the root module. | Not proof that every source file or platform path is covered. |
| `zig build run-agent` | Run `perihelion_agent`. | Automation is a separate operational action; inspect permissions and platform support first. |
| `zig build spirv` | Compile the declared SPIR-V compute object. | Compilation is not Vulkan execution or a speedup measurement. |
| `zig build nvptx` | Compile the declared NVIDIA PTX object. | Compilation is not CUDA runtime evidence. |
| `zig build wasm` | Attempt the experimental freestanding wasm target. | The build source documents standard-library limitations; not a qualified browser release. |

The old README advertised `example-file-browser`, `example-drop-viewer`, and
`nyon-cli`; these are **not registered by the current `build.zig`**. Do not use
those commands as supported setup steps without restoring and validating the
corresponding build targets.

The wasm definition explicitly notes missing `Thread`, `DynLib`, and POSIX
support in the selected freestanding path and the need for a dedicated entry
point/conditional compilation. Do not promise a working browser build or add
an Emscripten requirement merely because an older README mentioned it.

## Source map

| Path | Responsibility |
| --- | --- |
| [`build.zig`](build.zig) | Executables, target selection, tests, and experimental builds. |
| [`build.zig.zon`](build.zig.zon) | Package identity, compiler minimum, and pinned dependency source. |
| [`src/root.zig`](src/root.zig) | Root engine module and test entry. |
| [`src/main.zig`](src/main.zig) | Game entry point. |
| [`src/editor.zig`](src/editor.zig) | Editor entry point. |
| [`src/agent/main.zig`](src/agent/main.zig) | Automation-agent entry. |
| [`src/platform/automation_win32.zig`](src/platform/automation_win32.zig) | Win32 automation integration. |
| [`src/gpu/compute.zig`](src/gpu/compute.zig) | Compute source used by the shader targets. |

## Validation and contribution

```bash
zig fmt --check build.zig src
zig build
zig build test
```

These are validation steps to run on a supported environment, not outcomes from
this documentation update. Most modules have cross-module dependencies; use
`zig test <file>` only for genuinely standalone utilities. Build, test, shader
compilation, graphical launch, and actual platform behavior must be reported
separately.

Read [AGENTS.md](AGENTS.md), preserve historical code and saved data, keep
changes focused, and document compiler/API migrations explicitly. Do not treat
old checked boxes as results for a new commit. Do not run the automation agent
or overwrite user worlds as part of a documentation check.

## Development direction

Prioritize reproducible baseline builds, explicit backend boundaries, and
verified sandbox/editor behavior before expanding procedural geometry,
materials, plugins, or assets. Preserve the useful creative lineage without
presenting research targets as finished systems. New Rust game development
belongs to the separately governed [NYON workspace](https://github.com/donaldfilimon/NYON).

Review the repository's applicable licensing and third-party dependency terms
before redistribution; project names alone do not establish a shared license.
