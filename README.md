# llm-node

Container image for a coding workspace: an opencode server with Ghidra,
Lightpanda, Playwright/Chromium, Python (uv) and Node tooling.

- `Dockerfile`: image build. Tools installed by the user persist on the home volume.
- `entrypoint.sh`, `apt/`: home seeding and apt package persistence.
- `defaults/`, `skills/`: opencode defaults (model provider inside the cluster) and skill files.

Pushing to `main` builds the image and pushes it to GHCR, tagged with the commit SHA and `latest`.
