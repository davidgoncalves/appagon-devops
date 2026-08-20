# Deployment

Deploy an application with:

./deploy <app>

Example: `./deploy planto` (not `plant`). Other slugs: `currency`, `dashboard`.

The deployment script:

- verifies the local repository
- verifies GitHub
- updates the production server
- installs dependencies (Composer or pip)
- performs a health check

Each step is printed in color on a terminal, and the run always ends with a
single banner: green on success, red on failure. Output is plain text when
redirected to a file, when `TERM=dumb`, or when `NO_COLOR=1` is set.

The server-side check ignores untracked files (`.env`, `writable/`, `logs/`…):
only tracked modifications can block a `git pull --ff-only`.

Never modify production manually.
