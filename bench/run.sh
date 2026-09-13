#!/bin/sh
# Builds and runs the benchmarks of bench/valk, bench/go and bench/rust against the same
# server and prints a comparison. The database is the one tests/servers.sh creates.
#
#   ./bench/run.sh [host] [port] [iterations]
#
# Every program runs the same scenarios on one connection, sequentially:
#   ping          simple query "SELECT 1"
#   select_by_id  prepared statement with a parameter, one row read
#   fetch_rows    every row of a 10k row table (20 rounds), 4 columns read
#   insert        parameterized inserts inside one transaction
# Go and Rust are skipped when their toolchain is missing.
set -e
DIR=$(cd "$(dirname "$0")" && pwd)
HOST=${1:-127.0.0.1}
PORT=${2:-5432}
N=${3:-20000}
OUT="$DIR/build"
mkdir -p "$OUT"

echo "Building valk..."
(cd "$DIR/valk" && valk build . -o "$OUT/bench-valk" --release >/dev/null)
LANGS="valk"
if command -v go >/dev/null 2>&1; then
    echo "Building go..."
    (cd "$DIR/go" && go mod tidy >/dev/null 2>&1 && go build -o "$OUT/bench-go" .)
    LANGS="$LANGS go"
fi
if command -v cargo >/dev/null 2>&1; then
    echo "Building rust..."
    (cd "$DIR/rust" && cargo build --release -q && cp target/release/bench-rust "$OUT/bench-rust")
    LANGS="$LANGS rust"
fi

for lang in $LANGS; do
    echo "Running $lang ($N iterations)..."
    "$OUT/bench-$lang" "$HOST" "$PORT" "$N" > "$OUT/$lang.txt"
done

echo
echo "Operations per second (higher is better), total time in ms in parentheses"
awk -v langs="$LANGS" -v out="$OUT" '
BEGIN {
    count = split(langs, lang, " ")
    for (i = 1; i <= count; i++) {
        file = out "/" lang[i] ".txt"
        while ((getline line < file) > 0) {
            split(line, f, " ")
            if (f[1] != "RESULT") continue
            if (!(f[2] in seen)) { seen[f[2]] = 1; order[++names] = f[2] }
            ops[f[2], lang[i]] = f[5]
            ms[f[2], lang[i]] = f[4]
        }
        close(file)
    }
    printf "%-14s", "scenario"
    for (i = 1; i <= count; i++) printf "%20s", lang[i]
    printf "\n"
    for (j = 1; j <= names; j++) {
        printf "%-14s", order[j]
        for (i = 1; i <= count; i++) {
            v = ops[order[j], lang[i]]
            if (v == "") printf "%20s", "-"
            else printf "%20s", sprintf("%s (%s)", v, ms[order[j], lang[i]])
        }
        printf "\n"
    }
}'
