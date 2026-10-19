# RAG — Mario & Luigi: Superstar Saga Recompilation Workbench

RAG is the project workspace for a native Windows x64 recompilation of **Mario & Luigi: Superstar Saga (USA, game code A88E, revision 0)**.

## Starting point

Rather than inventing an ARM7TDMI recompiler and GBA hardware runtime from scratch, RAG pins a working community game integration at [reference/mlss](https://github.com/Zaxaerith/MarioLuigiSuperstarSagaRecomp/tree/5c742186b131b88e48a4ba9b033ce0a480f23ccd). That project uses [GBARecomp](https://github.com/mstan/gbarecomp) for ARM/Thumb-to-native translation and [recomp-ui](https://github.com/mstan/recomp-ui) for the player launcher. The baseline is pinned as a Git submodule so the upstream source and its own submodules retain their provenance and licenses.

**ROM check:** the ROM uploaded for this project matches the baseline's accepted USA Rev 0 identity: SHA-1 7c303cdde5061ee329296948060b875cb50ba410, MD5 4b1a5897d89d9e74ec7f630eefdfd435. No ROM or BIOS file has been committed.

The baseline is explicitly experimental. Its upstream README reports the title/file-select flow and opening sequences through the Bowser tutorial battle as tested; it does **not** claim full-campaign compatibility.

## Feature baseline at the pinned revision

| Feature | Starting capability | RAG work remaining |
|---|---|---|
| Native translation | GBARecomp AOT translates ARM/Thumb code to C++; interpreter fallback remains for unresolved paths. | Expand coverage and test additional scenes. |
| Keyboard / controller | The launcher exposes keyboard and gamepad bindings via SDL2. | Verify mappings throughout the full game. |
| Saves | The game configuration selects 8 KiB EEPROM persistence. | Continue save/load round-trip testing in-game. |
| Fullscreen / display | The launcher supports borderless fullscreen and integer scaling; original 240×160 / 3:2 display remains the default. | Add any extra resolution controls without distorting pixels or game timing. |
| Adaptive widescreen | **Not enabled** in this title's current integration; its launch options leave adaptive view disabled. | First trace the field/camera bounds, background streaming, sprite clipping, and HUD positions; only enable wider views after scene-by-scene checks. |
| Frame pacing | The preview notes possible micro-stutters when native code paths are first visited. | Profile representative play and reduce stalls without changing game timing. |

These are the capabilities of the pinned preview—not claims that RAG has already completed full-game testing. Generated game code and final gameplay tests still need to be built locally with the matching ROM and retail BIOS.

## RAG Edition differences

RAG applies a small, reviewable local overlay on top of the pinned integration before compilation. The upstream submodule commit remains pinned; the overlay is maintained in this repository and is re-applied at build time.

- **RAG Edition identity:** custom launcher/window identity and a `RAGSuperstarSaga.exe` output name.
- **Independent user data:** `rag-config.ini`, `rag-keybinds.ini`, `rag-rom.cfg`, `rag-bios.cfg`, and `saves/rag_mlss_usa.sav` keep this build from sharing configuration or progress with the upstream preview.
- **Save safety:** before an interactive session starts, RAG writes the current cartridge save to `saves/rag_mlss_usa.sav.bak` and rotates the previous backup to `.bak.1`. This protects the last known save across many interrupted sessions; it is not a replacement for keeping external backups. To restore one, close RAG, make a copy of the current `.sav` elsewhere, then copy the chosen `.bak` or `.bak.1` over `saves/rag_mlss_usa.sav`.
- **Performance visibility:** FPS readout is enabled by default.
- **Resizable window:** the window may be resized freely while the renderer preserves the game image's aspect ratio with letterboxing/pillarboxing; this is not fake widescreen or a change to the game's 240×160 logical view.
- **Selectable display filters:** opt-in launcher controls expose the sharp-scaling filter and affine-texture filtering, both off by default so the original pixel presentation remains the starting point.
- **Quality-of-life menu:** expose the runtime assist menu with 4× fast-forward, nine save-state slots, and a five-second rewind history.

These settings are the first differentiators; the executable must still be built and tested before we can claim each option works correctly in this game's scenes. **Adaptive widescreen is deliberately not enabled yet**: exposing it without a scene-aware field/camera/background policy could reveal missing edges or break battle layouts.

## Get the code

~~~powershell
git clone --recurse-submodules https://github.com/TotallyJustRetro/rag.git
cd rag
git submodule update --init --recursive
~~~

Keep your legally obtained ROM and retail GBA BIOS on your own computer. Do not add either to Git. The baseline requires the matching USA ROM revision and a retail BIOS; the BIOS is not included.

## Optional: test the existing preview binary

A prebuilt Windows x64 executable is available from the upstream integration's [v0.1.1-preview release](https://github.com/Zaxaerith/MarioLuigiSuperstarSagaRecomp/releases/tag/v0.1.1-preview). This is **the upstream project's binary, not an executable produced by RAG's CI**. It still requires your matching USA Rev 0 ROM and a user-supplied retail GBA BIOS, and the reported play-tested scope covers the opening through the Bowser tutorial—not the full campaign.

The publisher lists this ZIP's SHA-256 as `729cf47d2f53ab6d5b7bb937bab166fc4c2503c82fd4a803b89d56b4013202d9`. Verify the downloaded file against the release page before using it.

## Build the game integration (Windows)

Prerequisites for the game build are Windows 10/11 x64, Git, PowerShell, MSYS2 MinGW-w64 with GCC/G++, CMake, Ninja, and SDL2 development libraries. Visual Studio 2022 with the C++ workload is only needed for the optional root diagnostic-tool build.

1. Clone this repository with submodules:
   ~~~powershell
   git clone --recurse-submodules https://github.com/TotallyJustRetro/rag.git
   cd rag
   ~~~
2. Run the root build wrapper, providing your legally obtained ROM and retail BIOS, plus the SDL2 MinGW development folder:
   ~~~powershell
   .\tools\build-mlss.ps1 -Rom "D:/ROMs/Mario & Luigi - Superstar Saga (USA).gba" -Bios "D:/BIOS/gba_bios.bin" -SdlRoot "D:/path/to/SDL2/x86_64-w64-mingw32" -Toolchain "C:/msys64/mingw64" -Jobs 4
   ~~~

The wrapper checks the USA Rev 0 ROM and retail BIOS hashes, verifies the pinned integration revision, initializes framework dependencies, builds the recompiler, generates local C++, then compiles the native executable. It places a verified copy of the ROM in the integration's ignored local folder because the pinned upstream generation script expects the ROM next to `game.toml`. The ROM, BIOS, generated C++, logs and binaries are excluded from version control. They are not uploaded by this workflow.

On success, the RAG Edition executable should be at `reference/mlss/build/host/RAGSuperstarSaga.exe`. To run it after building, the wrapper prints the launch command. Add `-RunAfterBuild` to launch it automatically.

Read [the integration's full README](https://github.com/Zaxaerith/MarioLuigiSuperstarSagaRecomp/blob/5c742186b131b88e48a4ba9b033ce0a480f23ccd/README.md) for detailed setup notes and known limitations. This baseline is an experimental preview: opening gameplay and the Bowser tutorial are reported as tested, but a complete campaign playthrough is not claimed.
 
## Private GitHub-hosted build (recommended if you do not want a local runner)

A companion **private** repository can hold your own ROM/BIOS and run the native build on GitHub-hosted Windows. This keeps input files, build logs, and the downloadable executable artifact out of the public RAG repository. The workflow template and one-time setup guide are in [private-build-template](private-build-template/README.md).

1. Create a separate repository (for example, **rag-private-build**) and set its visibility to **Private**. Keep access restricted.
2. Add your own files at **assets/Mario & Luigi - Superstar Saga (USA).gba** and **assets/gba_bios.bin**.
3. Copy [private-build-template/build-rag.yml](private-build-template/build-rag.yml) to that private repository at **.github/workflows/build-rag.yml**.
4. Run **Actions → RAG Edition Private Windows Build → Run workflow**. The workflow checks the inputs, builds the EXE, runs a headless smoke test, and uploads a 7-day package artifact to that private repository.

The private workflow uploads only the runnable package, not the ROM/BIOS or generated C++ sources. **Do not copy these inputs into the public RAG repository or its Actions artifacts.** The final artifact is visible to people who have read access to the private repository, so check its access list.

## One-click GitHub Actions build (Windows runner)

The `RAG Edition Native Windows Build` workflow is **manual-only** and runs on a self-hosted Windows x64 runner. This is intentional: the repository is public, so any published Actions artifact can be downloaded by anyone with repository read access. The workflow does not upload the game executable, the ROM, the BIOS, or ROM-generated source. The final EXE stays on your Windows machine.

1. On your PC, keep the ROM and BIOS outside the Git checkout. The workflow defaults to `C:/RAG-private/Mario & Luigi - Superstar Saga (USA).gba` and `C:/RAG-private/gba_bios.bin`; copy the files there or enter their actual local paths when starting the workflow.
2. Install the MSYS2 MinGW-w64 compiler and SDL2 development package. The default paths are `C:/msys64/mingw64` for both the toolchain and SDL2 SDK; enter different paths if your setup differs.
3. From a PowerShell 7 terminal in the RAG checkout, run the preflight first:
   ```powershell
   .\tools\check-rag-build.ps1 -Rom "C:/RAG-private/Mario & Luigi - Superstar Saga (USA).gba" -Bios "C:/RAG-private/gba_bios.bin" -Toolchain "C:/msys64/mingw64" -SdlRoot "C:/msys64/mingw64" -OutputDir "C:/RAG-private/RAG-Edition"
   ```
   It checks the ROM/BIOS hashes, pinned integration, compiler/SDL2 files, and output-folder safety. A passing preflight does not mean the game is built; it means the inputs and local build environment are ready to try.
4. Open **RAG → Settings → Actions → Runners → New self-hosted runner**, choose Windows x64, and follow GitHub's displayed steps. The one-time registration token is private: never paste it into chat or commit it. Run the runner as the same Windows account that can read the ROM/BIOS and build folders; leave the runner online.
5. In **Actions**, select **RAG Edition Native Windows Build → Run workflow**, check the ROM/BIOS/toolchain paths, and start it. The workflow validates the file hashes, regenerates the native code locally, compiles the EXE, and runs a headless smoke test.
6. After a successful run, a runnable local folder is staged at `C:/RAG-private/RAG-Edition` by default. It contains `RAGSuperstarSaga.exe`, required runtime DLLs (when dynamically linked), launcher assets, `game.toml`, notices, and a quick-start note. It deliberately does **not** contain the ROM or BIOS. You can change the destination with the workflow's `output_dir` input. The raw build remains under `reference/mlss/build/host` inside the runner workspace, but the staged folder survives the next checkout cleanup.

The root Windows CI workflow still uses GitHub-hosted runners for the diagnostic executable and tests; only the game-specific build and local package staging use the self-hosted runner. No game executable or ROM-generated source is uploaded as a public workflow artifact.

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
