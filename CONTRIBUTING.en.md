# Contributing guide

**Language:** [English](CONTRIBUTING.en.md) | [Русский](CONTRIBUTING.md)

Thank you for your interest in **SkupLink**. Bug reports, ideas, and fixes are welcome.  
To keep the option of shipping commercial builds based on this codebase, please accept the terms below.

## Contributor License Agreement (CLA)

By submitting a Pull Request (or any other patch) to this repository, you confirm and agree that:

1. You are the author of the contributed code **or** you have the legal right to grant the license described here.
2. You grant the project copyright holder (SpecPromDesign LLC / ООО «СпецПромДизайн» and its successors) a **perpetual, irrevocable, worldwide, non-exclusive, royalty-free license** to use your contribution for any purpose, including:
   - inclusion in the open-source edition under GNU GPL v3;
   - inclusion in closed / commercial products;
   - modification, distribution, and sublicensing.
3. You retain copyright in your contribution, but you allow the copyright holder to use it **without additional restrictions and without any obligation to pay royalties**.
4. You warrant that the contribution does not infringe third-party rights and does not contain code that cannot be licensed under these terms.

**No separate paperwork is required.** Opening a Pull Request constitutes full acceptance of these terms.  
If you do not agree with the CLA, do not submit code to this repository; you may still describe an idea in an Issue without a patch.

## How to help

- Report bugs via **Issues** (OS, build type, steps to reproduce, logs if available).
- Propose changes via **Pull Request** against the main development branch.
- One PR — one logical topic; large refactors should be discussed in an Issue first.
- Do not commit secrets, local `config.json` files with passwords, build binaries, or IDE junk unless necessary.

## Code style

The project is written in Delphi; follow the style of nearby modules:

- indentation and formatting as in existing `.pas` files;
- no drive-by refactors mixed into a feature change;
- strings/constants — preferably in `Common.pas` or next to existing ones;
- web UI (`web/`) — keep changes minimal and consistent with the current layout.

Build to verify:

- Windows: `SkupLinkService/SkupLink.dproj` (Debug/Release), and `SkupLinkTray` if needed;
- Linux: Release / Linux64.

## Development notes

Substantial parts of this project were developed with AI-assisted tooling (Grok / Cursor).

## Contact

Licensing and commercial use: **info@spd.net.ru** · [spd.net.ru](https://spd.net.ru)
