# RAG — GBA Static Recompilation

RAG is a work-in-progress native Windows x64 static-recompilation project, initially targeting **Mario & Luigi: Superstar Saga (USA, game code `A88E`)**.

The first milestone is a reproducible C++ build and ROM/ARM entry-point inspection. This is not yet a playable game and does not yet translate the complete game into native code.

## Principles

- Do not commit commercial ROMs, BIOS images, save files, or extracted game assets. Supply a legally obtained ROM locally.
- Keep analysis tools, tests, and the game-specific recompiler separate.
- Validate every CPU translation against known instruction semantics before using it for game code.
- Preserve GBA timing and hardware behavior; window stretching alone is not a widescreen implementation.

## Build (Windows)

Install Visual Studio 2022 with **Desktop development with C++**, plus CMake 3.24+.

```powershell
cmake -S . -B build -A x64
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
```

## Inspect the local ROM

```powershell
.\build\Release\rag.exe inspect-rom "D:\ROMs\Mario & Luigi - Superstar Saga (USA).gba"
.\build\Release\rag.exe disassemble-entry "D:\ROMs\Mario & Luigi - Superstar Saga (USA).gba" 32
```

The entry disassembler is intentionally a small diagnostic decoder, not a complete ARM7TDMI disassembler.

## Roadmap

1. Establish clean Windows CI and ROM metadata checks.
2. Build a tested ARM7TDMI/Thumb instruction decoder and translation layer.
3. Map cartridge ROM, EWRAM/IWRAM, I/O, VRAM, palette/OAM, timers, DMA, interrupts, and save hardware.
4. Translate reachable ROM code into C/C++ and implement required BIOS/HLE services.
5. Recreate graphics/audio/input behavior and prove the first boot path.
6. Add save persistence, remappable keyboard/gamepad controls, display modes, and stable frame pacing.
7. Investigate game-aware widescreen support after rendering/camera behavior is understood.

## Status

**Milestone 0 — build and inspection scaffold.** A successful build means the tools compile and tests pass; it does not mean the game runs yet.
