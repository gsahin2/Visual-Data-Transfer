# Visual Data Transfer — Wiki

Welcome. This wiki mirrors the **human-facing** story of the project: goals, how the pieces fit, and how to work in the tree. Deep specifications stay in the main repository under `docs/`.

## What this is

**Visual Data Transfer (VDT)** sends digital data over a **screen → camera** path: a sender draws a structured symbol grid (with optional chrome), and a receiver samples frames and reassembles a payload with **CRC-checked** framing.

V1 targets roughly **20 KiB** per transfer, looping frames until the receiver has enough observations.

## Quick links

| Topic | Wiki page |
|--------|-----------|
| Clone, build, first commands | [Getting Started](Getting-Started) |
| Core vs Swift vs Python | [Architecture](Architecture) |
| Scripts & offline decode | [Python Tools](Python-Tools) |
| Tests & contributions | [Development](Development) |
| Phases, checklist, V1 criteria | [Roadmap and Status](Roadmap-and-Status) |
| Push these files to GitHub | [Publishing the Wiki](Publishing-the-Wiki) |

## Repository (source of truth)

Replace `YOUR_ORG` with your GitHub user or organization:

**https://github.com/YOUR_ORG/Visual_Data_Transfer**

Canonical specs and phase checklist (always current with the code):

- [README](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/README.md)
- [Architecture](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/docs/architecture.md)
- [Protocol V1](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/docs/protocol-v1.md)
- [Phases & tasks (status)](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/docs/phases-and-tasks.md)
- [Contributing](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/CONTRIBUTING.md)

## License

Apache-2.0 — see the `LICENSE` file in the main repository.
