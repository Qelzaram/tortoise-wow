# Turtle WoW — AutoFishing

> Server-side automatic fishing loop for the `autofishing` branch of Tortoise-WoW 1.18.1.

This branch adds a lightweight AutoFishing feature without Playerbots, movement AI, client modifications, database changes, or a persistent toggle system.

The idea is intentionally simple: **walk to the fishing spot yourself, cast Fishing once, and let the server handle the repetitive catch → loot → recast cycle until something interrupts it.**

## How it works

1. Cast **Fishing** manually at the place you want to fish.
2. When the bobber gets a bite, the server automatically hooks it.
3. Loot is stored through the normal server loot handlers.
4. After the current fishing channel is fully finished, the server waits `500 ms`.
5. Fishing is cast again at the previous bobber position.
6. The cycle repeats while the player remains in a valid state.

Normal fishing rules are preserved, including fishing skill checks, failed catches/junk behavior, skill gains, and fishing-hole loot logic.

## Automatic stop conditions

AutoFishing stops naturally when:

- the player moves;
- the player enters combat;
- the player dies or leaves the world;
- another spell/cast takes priority during the recast delay;
- the current catch cannot be fully stored in the inventory;
- a fishing pool is depleted;
- the current fishing cast is cancelled before the catch.

There is no permanent AutoFishing state to turn on or off. A normal manual Fishing cast starts a new cycle.

## Fishing pools

Fishing pools use the normal Tortoise-WoW loot-release path.

This is important because successful catches must update the pool's use counter correctly. Once the configured number of successful uses is reached, the pool deactivates normally and AutoFishing does **not** continue fishing ordinary water at the old pool position.

## Implementation

The feature code is deliberately small and currently modifies only:

```text
src/game/Objects/GameObject.cpp
```

The branch also modifies this `README.md` for documentation only.

The implementation uses existing core behavior instead of duplicating the inventory and spell systems:

- `WorldSession::HandleAutostoreLootItemOpcode` for item storage and loot bookkeeping;
- `WorldSession::HandleLootMoneyOpcode` for loot money;
- `WorldSession::DoLootRelease` for normal fishing-node/fishing-hole release behavior;
- `m_Events.AddLambdaEventAtOffset` for the delayed recast;
- the normal coordinate-based `CastSpell(...)` path for the next Fishing cast.

No movement, pathfinding, target selection, combat logic, or Playerbot functionality is added.

## Compatibility

Target client/server version:

```text
Turtle WoW 1.18.1
Build 7272
```

The branch is kept as **one AutoFishing commit on top of the current `main`**. The Docker installer verifies that its official stable core revision exactly matches the branch base before applying the AutoFishing source diff. If upstream `main` advances, rebase this branch onto the new `main` and test it again before deployment.

The feature has been runtime-tested on a local Docker deployment.

## Building / installing

This is a **source branch**. Build it with the same toolchain and deployment process used for the normal Tortoise-WoW server.

For Docker deployments based on the official/community stable image, the safe model is:

```text
official stable source revision
        +
official deployment patches
        +
AutoFishing GameObject.cpp diff
        ↓
build a local server image
```

No prebuilt server binaries are committed to this branch.

To disable AutoFishing, simply rebuild/redeploy the normal `main`/stable core. Existing world/character databases and server configuration do not need to be changed for this feature.

---

# Tortoise-WoW

This is an unofficial, community driven, restoration of the 1.18.1 patch of Turtle-WoW, with some additions for solo play.  
This project is not to be used for profit or to misrepresent itself, or anyone using it, as the original creators  
This project targets version 1.18.1 build 7272

## Client Version

The client version targetted is patch 1.18.1, build 7272  
Any client that does not match this version or build will likely have a myriad of issues

## Additions
Additions will be added as the core code reaches feature completion

#### Current Additions

- **Autoscale** - Rudimentary toggleable dungeon/raid auto scaling system, found in mangosd.conf
- **Leech** - Basic toggleable leech system designed for solo play, found in mangosd.conf
- **Additional Talent Points** - Mostly used for testing, found in tw_char.characters

#### Planned Additions

- **[Playerbots][20]** - Currently implemented in a very basic fashion, not ready for use
- **[Eluna][19]** - The WoW lua engine

## Operating Systems

* **[Windows][15]**, 32 bit and 64 bit. Windows Server 2008 (or newer) or Windows 8 (or newer) is recommended.
* **Linux**, 32 bit and 64 bit. [Ubuntu 22.04 LTS][14] is recommended. Other distributions with similar package versions will work, too.
Of course, newer versions should work, too. In the case of Windows, matching
server versions will work, too.

## Dependencies

* **[Git][1] / [Github for Windows][2]**: This version control software allows you to get the source files in the first place.
* **[MySQL][3]** / **[MariaDB][4]**: These databases are used to store content and user data.
* **[ACE][5]**: aka Adaptive Communication Environment, provides us with a solid cross-platform framework for abstracting operating system specific details.
* **[Recast][21]**: In order to create navigation data from the client's map files, Recast is used to do the dirty work. It provides functions for rendering, pathing, etc.
* **[G3D][6]**: This engine provides the basic framework for handling 3D data and is used to handle basic map data.
* **[Stormlib][7]**: Provides an abstraction layer for reading data from MPQ archive files.
* **[Zlib][8]/[Zlib for Windows][9]** provides compression algorithms used in both MPQ archive handling and the client/server protocol.
* **[Bzip2][10]/[Bzip2 for Windows][11]** provides compression algorithms used in MPQ archives.
* **[OpenSSL][12]/[OpenSSL for Windows][13]** provides encryption algorithms used when authenticating clients.

To build this project follow any MaNGOS/MaNGOS Zero build guide, with the addition of ACE  

## Database Setup

1. Manually import sql/create_databases.sql
2. Manually import all sql scripts in the sql/base folder
3. Run mangosd to automatically import and track updates  

This will be streamlined once the core is more up to date

## Contributing

Contributions are welcome, but I may be slow to review and merge PRs

See `CONTRIBUTING.md` for ways to get started.


[1]: http://git-scm.com/ "Git - Distributed version control system"
[2]: http://windows.github.com/ "github - windows client"
[3]: https://dev.mysql.com/downloads/ "MySQL - The world's most popular open source database"
[4]: https://mariadb.org/download/ "MariaDB - An enhanced, drop-in replacement for MySQL"
[5]: http://www.dre.vanderbilt.edu/~schmidt/ACE.html "ACE - The ADAPTIVE Communication Environment"
[6]: http://sourceforge.net/projects/g3d/ "G3D - G3D Innovation Engine"
[7]: http://zezula.net/en/mpq/stormlib.html "Stormlib - A library for reading data from MPQ archives"
[8]: http://www.zlib.net/ "Zlib"
[9]: http://gnuwin32.sourceforge.net/packages/zlib.htm "Zlib for Windows"
[10]: http://www.bzip.org/ "Bzip2"
[11]: http://gnuwin32.sourceforge.net/packages/bzip2.htm "Bzip2 for Windows"
[12]: http://www.openssl.org/ "OpenSSL - The Open Source toolkit for SSL/TLS"
[13]: http://slproweb.com/products/Win32OpenSSL.html "OpenSSL for Windows"
[14]: http://www.ubuntu.com/ "Ubuntu - The world's most popular free OS"
[15]: http://windows.microsoft.com/ "Microsoft Windows"
[19]: https://github.com/ElunaLuaEngine/Eluna
[20]: https://github.com/ike3/mangosbot-bots
[21]: http://github.com/memononen/recastnavigation "Recast - Navigation-mesh Toolset for Games"
