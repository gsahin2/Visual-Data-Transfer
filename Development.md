# Development

## Principles (short)

- Reliability over visual complexity.  
- Deterministic behavior; clear boundary between **core** and **UI**.  
- Keep protocol rules in C++ (or the shared Python mirror), not scattered in views.

## Local checks

Summarized from the repo’s contributing guide:

**C++**

```bash
cmake -S core -B build-core
cmake --build build-core -j
ctest --test-dir build-core --output-on-failure
```

**Swift**

```bash
swift build
```

**Python**

```bash
cd python && pip install -r requirements.txt
python3 -m unittest discover -v -p 'test_*.py'
```

## Documentation

When behavior or wire formats change, update:

- `docs/protocol-v1.md`, `docs/frame-layout.md`, `docs/constraints.md` as needed  
- `docs/phases-and-tasks.md` checklist  
- This wiki only if it helps onboarding (wiki is a thin layer on top of `docs/`)

## Pull requests

Describe the problem and approach; keep diffs focused; use **English** for project text.

---

**Full guide:** [CONTRIBUTING.md](https://github.com/YOUR_ORG/Visual_Data_Transfer/blob/main/CONTRIBUTING.md).
