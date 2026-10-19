# RAG Edition: private GitHub-hosted Windows build

This template runs the native build on a GitHub-hosted Windows runner while keeping the ROM, BIOS, build logs, and downloadable package inside a separate **private repository**. The public TotallyJustRetro/rag repository contains only source and workflow documentation.

## One-time setup

1. In your GitHub account, create a new repository named **rag-private-build** and set **Visibility = Private**. Do not fork the public RAG repository for this purpose.
2. In the new private repository, create an **assets** folder and upload your own supported input files:
   - **assets/Mario & Luigi - Superstar Saga (USA).gba**
   - **assets/gba_bios.bin**
   
   The workflow validates the exact USA Rev 0 ROM and retail GBA BIOS identities. Do not put either file in TotallyJustRetro/rag.
3. In this private repository, create the file **.github/workflows/build-rag.yml** and copy the contents of the [build-rag.yml template](https://github.com/TotallyJustRetro/rag/blob/main/private-build-template/build-rag.yml) into it.
4. Keep the repository private and limit read access to people you trust. Anyone with read access to the private repository may be able to see its Actions logs and download its build artifacts.
5. Open **Actions → RAG Edition Private Windows Build → Run workflow**, leave source_ref set to main, and start the run.

## What this does

- Runs on windows-latest, so a self-hosted runner and local toolchain are not needed.
- Checks out the public RAG source and pinned submodules.
- Validates the private ROM/BIOS hashes, MinGW-w64 compiler, SDL2 SDK, and safe output paths.
- Generates native code and compiles RAGSuperstarSaga.exe.
- Runs a 600-frame headless smoke test.
- Uploads a 7-day RAG-Edition-Windows-x64 artifact to **this private repository**. Download it from the run's Summary page under Artifacts.

The artifact contains the executable, runtime DLLs, launcher assets, configuration, and notices. It deliberately excludes the ROM and BIOS. The generated C++ and full build output stay on the ephemeral runner and are not uploaded as artifacts.

## Important limitations and security

- The build is experimental. A successful compile/smoke test does not prove the entire game campaign is playable.
- This template guards against running in a public repository, but the guard is not a substitute for creating the repository as private and auditing its access list.
- GitHub-hosted runners need access to public GitHub and MSYS2 dependency downloads.
- Keep a separate local backup of your legally obtained inputs. This workflow does not add any credentials to the public RAG repository and does not require you to paste tokens or passwords into chat.
- Review the underlying integration's non-commercial license terms before redistribution.
