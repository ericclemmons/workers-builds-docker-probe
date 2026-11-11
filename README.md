# workers-builds-docker-probe

Minimal repro for running rootless Docker inside Workers Builds.

A Worker with one Container. The Dockerfile has a `RUN` step, because that is the step that needs a
nested `/proc` mount.

## Connect to Workers Builds

1. Fork or push this repo, then in the dashboard go to **Workers & Pages** > **Create** > **Import a repository**.
2. Set the build settings:
   - **Build command:** `npm run probe`
   - **Deploy command:** `npx wrangler deploy` (or `npx wrangler deploy --dry-run` to build the image without deploying)
3. Optional: create a deploy hook under **Settings** > **Builds** to re-run the probe on demand or on a schedule.

## Reading the result

Search the build log for `PROBE`:

| Check           | Fails when                                                                   |
| --------------- | ---------------------------------------------------------------------------- |
| `tun`           | `/dev/net/tun` is root-only, so rootless dockerd cannot start                 |
| `userns-mounts` | Paths under `/proc` or `/sys` are masked, so runc cannot mount procfs         |
| `docker-daemon` | dockerd did not start                                                         |
| `docker-build`  | A `RUN` step cannot start its nested container                                |
| `docker-run`    | The built image cannot run                                                    |

The `mounts over /proc and /sys` section lists any mounts that block the nested mount. It should be empty.

The build fails when any check fails. If the build command passes, `wrangler deploy` builds the same
image again, the way a customer's Containers deploy does.
