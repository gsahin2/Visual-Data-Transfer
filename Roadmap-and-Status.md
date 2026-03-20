# Roadmap and Status

## Narrative roadmap

High-level milestones and phase intent:

**https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/docs/roadmap.md**

## Task checklist (engineering + product gates)

The living **done / partial / todo** table is:

**https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/docs/phases-and-tasks.md**

That file distinguishes:

- **V1 completion criteria** — product validation (field E2E, timing, success rate, device matrix).  
- **Phases 0–6** — concrete repo deliverables (protocol, sender, recorded decode, live receiver, reliability, product shell).

## V1 snapshot

- **~20 KiB** max assembled payload.  
- **Looping** descriptor + payload frames; duplicate-tolerant assembly.  
- **2-bit/cell** visual grid in V1.  
- Synthetic optical / tooling paths are tracked in the checklist; **field** metrics stay open until you run hardware trials.

---

Update the wiki only for orientation; **always** edit `docs/phases-and-tasks.md` in the repo when closing tasks.
