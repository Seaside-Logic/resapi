Projects for `scripts/check-packages.sh`. For each scenario directory, it installs the packed packages
into a fresh project outside the repo, builds it and runs `src/Main.res.mjs`. These projects are not part
of the workspace build. `shared/` is copied into every project, and `shared-sury/` into the ones that use Sury.
