# Appagon DevOps

Read this file before doing anything.

This repository contains deployment tools shared by Appagon applications.

Main documents:

- docs/DEPLOYMENT.md
- docs/ADDING_APP.md
- docs/ARCHITECTURE.md

Rules:

- Never commit apps/*.env
- Never commit secrets
- Never deploy without explicit user request
- Never bypass Git checks
- Never modify production manually if Git manages the file
- Always preserve backward compatibility

Deploy: `./deploy <slug>` from this repo root. Planto is `./deploy planto` (not `plant`).

## Vérification

From this repo root. Script syntax only — **never run a deploy** to verify.

```bash
bash -n deploy
bash -n scripts/deploy-django.sh
bash -n scripts/deploy-php.sh
bash -n scripts/lib/output.sh
```

If `shellcheck` is installed: `shellcheck -x deploy scripts/*.sh scripts/lib/*.sh`.

Both deployment scripts are twins: any change to one usually belongs in the
other. Colored output lives only in `scripts/lib/output.sh`.
