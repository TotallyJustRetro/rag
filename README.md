# RAG — Mario & Luigi: Superstar Saga Recompilation Workbench

RAG is the project workspace for a native Windows x64 recompilation of **Mario & Luigi: Superstar Saga (USA, game code A88E, revision 0)**.

## Starting point

Rather than inventing an ARM7TDMI recompiler and GBA hardware runtime from scratch, RAG pins a working community game integration at [reference/mlss](https://github.com/Zaxaerith/MarioLuigiSuperstarSagaRecomp/tree/5c742186b131b88e48a4ba9b033ce0a480f23ccd). That project uses [GBARecomp](https://github.com/mstan/gbarecomp) for ARM/Thumb-to-native translation and [recomp-ui](https://github.com/mstan/recomp-ui) for the player launcher. The baseline is pinned as a Git submodule so the upstream source and its own submodules retain their provenance and licenses.

**ROM check:** the ROM uploaded for this project matches the baseline's accepted USA Rev 0 identity: SHA-1 7c303cdde5061ee329296948060b875cb50ba410, MD5 4b1a5897d89d9e74ec7f630eefdfd435. No ROM or BIOS file has been committed.

The baseline is explicitly experimental. Its upstream README reports the title/file-select flow and opening sequences through the Bowser tutorial battle as tested; it does **not** claim full-campaign compatibility.

## Get the code

~~~powershell
git clone --recurse-submodules https://github.com/TotallyJustRetro/rag.git
cd rag
git submodule update --init --recursive
~~~

Keep your legally obtained ROM and retail GBA BIOS on your own computer. Do not add either to Git. The baseline requires the matching USA ROM revision and a retail BIOS; the BIOS is not included.

## Build the game integration (Windows)

Prerequisites include Windows 10/11 x64, Git, Visual Studio 2022, MSYS2 MinGW-w64, CMake, Ninja, and SDL2 development libraries. Then from the RAG root:

~~~powershell
cd reference/mlss
./tools/setup-deps.ps1
./tools/regen.ps1 -Rom "D:/ROMs/Mario & Luigi - Superstar Saga (USA).gba" -Bios "D:/BIOS/gba_bios.bin"
./tools/build-host.ps1 -Jobs 4 -Toolchain "C:/msys64/mingw64" -SdlRoot "D:/path/to/SDL2/x86_64-w64-mingw32"
~~~

Adjust the ROM, BIOS, and SDL2 paths to your machine. If the build succeeds, the current baseline's game executable is created under reference/mlss/build/host/. The generated C++ and build output remain local and should not be committed.

Read [the integration's full README](https://github.com/Zaxaerith/MarioLuigiSuperstarSagaRecomp/blob/5c742186b131b88e48a4ba9b033ce0a480f23ccd/README.md) and [Windows build guide](https://github.com/mstan/gbarecomp/blob/main/docs/WINDOWS_GAME_SETUP.md) for details and limitations.

## RAG's own diagnostic utility

The repository root also keeps a small C++ ROM/entry-point inspection tool. It is a developer diagnostic, not a substitute for the full game integration and not a playable recompiler.

From the RAG root, install CMake 3.24+ and Visual Studio 2022 with the C++ workload, then run:

~~~powershell
cmake -S . -B build -A x64
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
./build/Release/rag.exe inspect-rom "D:/ROMs/Mario & Luigi - Superstar Saga (USA).gba"
./build/Release/rag.exe disassemble-entry "D:/ROMs/Mario & Luigi - Superstar Saga (USA).gba" 32
~~~

The diagnostic decoder only classifies a small subset of ARM-state instructions. The actual static translation engine is in the pinned game integration's GBARecomp submodule.

## Next RAG milestones

1. Make the upstream baseline reproducibly buildable from a clean recursive clone with local ROM/BIOS paths.
2. Verify the native Windows executable against this exact ROM and record boot/playback smoke-test results.
3. Work on requested improvements in small, measured changes: keyboard/controller configuration, save reliability, fullscreen/display options, and frame pacing.
4. Investigate adaptive widescreen only after verifying camera, room/field bounds, and HUD behavior. The current baseline uses native 240×160 view settings; merely stretching the image is not considered widescreen support.

## Licensing and attribution

The referenced game integration and GBARecomp framework use the **PolyForm Noncommercial 1.0.0** license. The upstream license and third-party notices are preserved in reference/mlss; review those terms before redistributing changes. This project is for non-commercial research and personal use. It is unofficial and is not affiliated with or endorsed by Nintendo or AlphaDream.
