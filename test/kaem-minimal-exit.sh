#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "usage: $0 HEX0-ASSEMBLER (e.g. bootstrap-seeds' hex0-seed)"
	exit 2
fi
HEX0=$1

tmp=${TMPDIR:-/tmp}/kaem-minimal-exit.$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# kaem-minimal runs commands by absolute path, and true and false are
# usually shell builtins, so look them up on PATH by hand.
find_on_path()
{
	name=$1
	old_ifs=$IFS
	IFS=:
	for dir in $PATH; do
		case $dir in
		/*)
			if [ -f "$dir/$name" ] && [ -x "$dir/$name" ]; then
				IFS=$old_ifs
				echo "$dir/$name"
				return 0
			fi
			;;
		esac
	done
	IFS=$old_ifs
	echo "no absolute $name found on PATH" >&2
	return 1
}

TRUE=$(find_on_path true)
FALSE=$(find_on_path false)
TOUCH=$(find_on_path touch)

"$HEX0" kaem-minimal.hex0 "$tmp/kaem-0"
chmod +x "$tmp/kaem-0"

failures=0

printf '%s\n' "$TRUE" > "$tmp/success.kaem"
set +e
"$tmp/kaem-0" "$tmp/success.kaem" >/dev/null 2>&1
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "ok: succeeding command exits 0"
else
	echo "FAIL: succeeding command exits $status, expected 0"
	failures=$((failures + 1))
fi

marker=$tmp/marker
printf '%s\n%s %s\n' "$FALSE" "$TOUCH" "$marker" > "$tmp/failure.kaem"
set +e
"$tmp/kaem-0" "$tmp/failure.kaem" >/dev/null 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then
	echo "ok: failing command exits $status"
else
	echo "FAIL: failing command exits 0, expected nonzero"
	failures=$((failures + 1))
fi
if [ -e "$marker" ]; then
	echo "FAIL: command after the failing one ran"
	failures=$((failures + 1))
else
	echo "ok: command after the failing one did not run"
fi

[ "$failures" -eq 0 ]
