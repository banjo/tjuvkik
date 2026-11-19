# Changesets

Every change a user notices needs a changeset: it describes the change for the changelog and the
release notes, and decides the version bump. Run `pnpm changeset`, pick the bump and write a line
for users, then commit the generated file with the change.

While Tjuvkik is in 0.x, pick patch. `scripts/release.sh` turns the changesets into a version and
`CHANGELOG.md`; see [internal/building.md](../internal/building.md#release).
