# Running safely: containment, measurement, restarts, teardown

The mechanics behind Phases 3–5 of SKILL.md. The examples are Linux; on macOS
use `ulimit`/Docker limits and `lsof` instead of cgroups and `/proc`.

## Contents

- Identify a listener without sending it traffic
- Run from a snapshot, not the working tree
- Contain the app
- Know where the bytes land
- Measure what the server actually holds
- Secrets
- Restarts
- Teardown

## Identify a listener without sending it traffic

A process on the documented port is not evidence that it is this app. Shared
hosts run unrelated services, and production, on `localhost` and `0.0.0.0`.
Identify it from the host side only:

- `ss -ltnp 'sport = :PORT'` → PID, then `ps -o pid,user,args -p PID` (command
  line and working dir: `readlink /proc/PID/cwd`).
- `docker ps --format '{{.Names}} {{.Image}} {{.Ports}} {{.Status}}'` → image
  and container name. A container that has been up for weeks with restart
  policies and real volumes is a deployment, not a dev instance.

Reuse it only if it is unmistakably this project, started from this checkout
or a dev image, *and* the user confirms in the plan that it is a dev instance.
Otherwise start your own on a free port. To find one:
`python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1])"`,
then confirm with `ss -ltn` that nothing else claimed it before you start.

## Run from a snapshot, not the working tree

Running from source writes into the repo (`__pycache__`, `*.egg-info`,
`build/`, `.next/`, SQLite files from test configs). Start from a snapshot in
the scratchpad instead:

```bash
git -C <repo> archive --format=tar HEAD | tar -x -C <scratch>/run/src
```

(Mention it in the plan if the working tree has uncommitted changes: the
snapshot doesn't include them.) Also set the tool's no-write flags where they
exist (`PYTHONDONTWRITEBYTECODE=1`).

**Dependencies without the network:** reuse what is already on the host:
- the project's existing virtualenv: create a new venv and add a `.pth` file
  pointing at the old one's `site-packages`;
- an existing `node_modules`: symlink it into the snapshot;
- an already-built local image.

Installing packages, pulling or building images, or anything that downloads
(many Dockerfiles fetch tools from the internet) needs the network and must be
listed in the plan as such.

## Contain the app

Put the app inside a memory limit *before* any exhaustion probe, so a memory
probe kills the app and not the host:

```bash
systemd-run --user --scope --unit=abuse-<project>-a \
  -p MemoryMax=1G -p MemorySwapMax=0 -p TasksMax=256 -- <start command>
docker run -d --name abuse-<project>-<date> --memory 1g --memory-swap 1g \
  --pids-limit 256 -p 127.0.0.1:<port>:<container-port> <image>
```

- Match production's limits when the project documents them (compose
  `mem_limit`, Kubernetes resources). Otherwise pick a limit well below free
  RAM.
- Docker's `--memory` without `--memory-swap` lets the container use the same
  amount again in host swap. Set them equal unless matching production matters
  more, and say which in the plan.
- Without systemd or Docker, use `ulimit -v` in the shell that starts the app.

**Host stop conditions, relative to the baseline.** Record these before Phase 4
and stop everything when one is crossed:
- available RAM falls below max(2 GB, 25% of total), or below the baseline
  minus the app's limit;
- swap grows by more than 500 MB over the baseline (busy hosts swap anyway, so
  the absolute value means nothing);
- free disk on any filesystem you write to falls below 10%. If it starts
  below 15%, say so in the plan and keep all payloads on another filesystem
  or in RAM within the caps;
- the load average exceeds 2× the CPU count;
- the app's logs grow by more than 1 GB.

## Know where the bytes land

Before sizing payloads, check (`df -h`, `findmnt`) where these live: the
scratchpad, `TMPDIR`, the app's data/upload dir, and container tmpfs mounts.
On many hosts `/tmp` is tmpfs, so every payload and upload spool there is RAM.

One upload usually exists several times: your payload file, the server's
upload spool, a stored input copy, an extracted workspace, and the output.
Budget about 4× the payload size against the "10% of free disk/RAM" cap, on
the filesystem where each copy lands.

## Measure what the server actually holds

`du` and `ps rss` miss things and give false "held up" results:

- **Unlinked temp files** (upload spools are often `O_TMPFILE` or deleted
  right after opening) don't show up in `du`. Count them through the process:
  `ls -l /proc/<pid>/fd | grep -c deleted`, and their size with
  `find /proc/<pid>/fd -lname '*(deleted)' -exec stat -L -c %s {} +`.
- **Cgroup memory** (`memory.current`) includes tmpfs and page cache charged
  to the app. Read `memory.stat` and separate `anon` (the process heap) from
  `shmem`/`file` (tmpfs writes, cache).
- **Leaks** show up as growth that survives the request. Measure again
  after the client has gone away and the job has finished, not only at the
  peak.
- **Open connections:** `ss -tnp state established '( sport = :PORT )' | wc -l`.

Sample these in a small monitor loop that writes timestamped lines to the
scratchpad. Run it **outside** the app's cgroup/scope, so it doesn't die when the
app is OOM-killed, and check that it is still alive after every crash.

## Secrets

Tokens, passwords and API keys never go in command-line arguments: they
show up in `ps`, in systemd unit descriptions and in your own tool output.
Pass them through the environment of the starting shell or a `0600` file in
the scratchpad. The same goes for probes: they read the token from an env var
(`TOKEN="${APP_TOKEN:?set APP_TOKEN}"`) and never contain it.

If a secret leaks anyway, rotate it straight away (for a throwaway token,
restart with a new one) and note it in the report.

## Restarts

After any restart, yours or after a crash:
1. Make sure the old instance is really gone (a failed transient systemd unit
   keeps its name until `systemctl --user reset-failed <unit>`; a crashed
   container keeps its name until `docker rm`).
2. Start it, then **block** on the health check before the next probe runs.
   A probe run against a dead port prints "connection refused" lines that
   look like results.
3. Check that the monitor is still alive.
4. Write the restart, and why, to the progress log.

## Teardown

At start, record everything you launch in `<scratchpad>/abuse-test/started.txt`:
PIDs, systemd unit names, container names, temp dirs. At teardown, stop
exactly those, in reverse order. Never `pkill -f <pattern>`: the pattern also
matches your own shell's command line. Then confirm the ports are free and the
units/containers are gone.
