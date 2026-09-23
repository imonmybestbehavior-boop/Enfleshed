# Enfleshed

Foundation for an open-world multiplayer action RPG on Roblox. This repository
contains project structure and tooling only; no gameplay systems are implemented.

## Toolchain and development

`rokit.toml` pins Rojo **7.7.0** and StyLua **2.5.2**. With Rokit installed,
run `rokit install` to install the pinned tools. No runtime dependencies or
frameworks are required.

```bash
# Format Luau and verify that formatting preserves its syntax tree.
stylua --verify src

# Check formatting without modifying files.
stylua --check src

# Build a place, then open it in Roblox Studio.
rojo build default.project.json -o Enfleshed.rbxlx

# Connect the matching Rojo Studio plugin to this server for live editing.
rojo serve default.project.json
```

The generated place and default sourcemap output are ignored by Git. A Rojo build
validates project mapping and serialization; it does not type-check Luau or replace
multiplayer testing in Studio. StyLua is a formatter, not a type checker.

## Architecture

The original `default.project.json` mappings are preserved:

| Source | Roblox location | Responsibility |
| --- | --- | --- |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Client bootstrap and local presentation |
| `src/server` | `ServerScriptService.Server` | Server bootstrap and authoritative systems |
| `src/shared` | `ReplicatedStorage.Shared` | Code and definitions safe to replicate to every client |

Because the client and server directories contain `init.client.luau` and
`init.server.luau`, Rojo maps them to a LocalScript and Script respectively.
Their subdirectories become Folder children of those scripts. At runtime the
client script is copied to each player's PlayerScripts. `Shared` is a Folder.

```text
src/
  client/
    init.client.luau
    Controllers/
    Utilities/
  server/
    init.server.luau
    Services/
    Configuration/
    Networking/
    Utilities/
  shared/
    Modules/
    Configuration/
    Networking/
    Utilities/
```

### Every foundation file

| File | Purpose |
| --- | --- |
| `.stylua.toml` | Selects Luau syntax, 120-column wrapping, tabs with width 4, Unix line endings, double-quote preference, and consistent call parentheses. |
| `src/client/init.client.luau` | Strict-mode client entry point; intentionally idle until controllers are introduced. |
| `src/server/init.server.luau` | Strict-mode server entry point; intentionally idle until services are introduced. |
| `src/client/Controllers/init.meta.json` | Preserves a Folder for input, camera, UI, and presentation controllers. |
| `src/client/Utilities/init.meta.json` | Preserves a Folder for helpers that depend on client-only APIs. |
| `src/server/Services/init.meta.json` | Preserves a Folder for authoritative domain services, such as combat or persistence, when implemented. |
| `src/server/Configuration/init.meta.json` | Preserves a Folder for server-only configuration that clients must not receive. |
| `src/server/Networking/init.meta.json` | Preserves a Folder for future server request handlers, validation, and rate limiting. |
| `src/server/Utilities/init.meta.json` | Preserves a Folder for server-only reusable helpers. |
| `src/shared/Modules/init.meta.json` | Preserves a Folder for shared types and pure domain modules. |
| `src/shared/Configuration/init.meta.json` | Preserves a Folder for public configuration safe for every client to inspect. |
| `src/shared/Networking/init.meta.json` | Preserves a Folder for shared protocol definitions; creates no remotes or networking implementation. |
| `src/shared/Utilities/init.meta.json` | Preserves a Folder for small, reusable helpers without client/server-specific dependencies. |
| `README.md` | Documents setup, mappings, every foundation file, and dependency boundaries. |

Each `init.meta.json` contains only `{"className": "Folder"}`. This keeps empty
folders in source control and explicitly represents them in Rojo without dummy
ModuleScripts. Add ordinary `.luau` modules inside these folders as systems are
introduced. The starter `src/shared/Hello.luau` sample has been removed.

The existing `default.project.json`, `.gitignore`, and tool pins are retained.
The starter baseplate, lighting, and sound settings remain unchanged.

## Boundaries for future systems

- The server owns game state, combat outcomes, inventory, rewards, and persistence.
  Clients submit intent; server handlers must validate permissions, payloads,
  timing, and gameplay constraints before mutating state.
- Controllers own local input and presentation. They may depend on shared code,
  but cannot access server modules.
- Services may depend on shared code and server utilities. Shared modules must
  never depend on client or server folders. Everything in ReplicatedStorage is
  public, including configuration and protocol definitions.
- Shared networking describes the protocol; server networking handles untrusted
  requests. No RemoteEvents, RemoteFunctions, or transport abstraction exist yet.
- Entry points will explicitly require and start modules in dependency order.
  Avoid side effects at require time, automatic folder scanning, and dependency
  cycles. Introduce lifecycle conventions only when actual systems need them.
- Group substantial future systems by domain within Services, Controllers, and
  Modules. Keep utilities focused instead of using them as a home for game rules.

World streaming, asset organization, persistence, and cross-server coordination
remain future decisions based on actual world and system requirements.
