#!/usr/bin/env bash
# Checks what rootless Docker needs inside a Workers Builds container.
# Each check prints "PROBE <name>: PASS|FAIL|SKIP" so results are easy to grep in build logs.
set -u

failed=0

result() {
	echo "PROBE $1: $2"
	if [ "$2" = "FAIL" ]; then
		failed=1
	fi
}

echo "== environment"
uname -a
id
grep -E '^(CapBnd|CapEff)' /proc/self/status
echo "open files: soft $(ulimit -Sn), hard $(ulimit -Hn)"

echo "== mounts over /proc and /sys (any line here blocks a nested procfs or sysfs mount)"
awk '$5 ~ "^/(proc|sys)/" { print $5, $9 }' /proc/self/mountinfo

echo "== /dev/net/tun"
ls -l /dev/net/tun 2>&1
if [ -r /dev/net/tun ] && [ -w /dev/net/tun ]; then
	result tun PASS
else
	result tun FAIL
fi

echo "== nested procfs and sysfs mount (what runc does for each RUN step)"
if command -v unshare >/dev/null; then
	if unshare -U -r -m -p -f -n sh -ec '
		mkdir -p /tmp/probe-proc /tmp/probe-sys
		mount -t proc proc /tmp/probe-proc
		mount -t sysfs sysfs /tmp/probe-sys
	'; then
		result userns-mounts PASS
	else
		result userns-mounts FAIL
	fi
else
	result userns-mounts SKIP
fi

echo "== docker daemon"
if docker info >/dev/null 2>&1; then
	result docker-daemon PASS
else
	docker info 2>&1 | tail -5
	result docker-daemon FAIL
fi

echo "== docker build with a RUN step"
if docker build --network=host -t workers-builds-docker-probe .; then
	result docker-build PASS
else
	result docker-build FAIL
fi

echo "== docker run"
if docker run --rm --network=host workers-builds-docker-probe cat /www/health; then
	result docker-run PASS
else
	result docker-run FAIL
fi

if [ "$failed" -ne 0 ]; then
	echo "PROBE RESULT: FAIL"
	exit 1
fi

echo "PROBE RESULT: PASS"
