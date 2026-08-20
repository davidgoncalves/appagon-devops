# Architecture

Repository purpose:

- deploy — entry point, dispatches to the right script
- scripts/ — one deployment script per stack, plus `lib/output.sh` (shared colored output)
- apps/ — one `<slug>.env` per application
- docs/

Applications are stored outside this repository.

This repository only contains deployment tooling.
