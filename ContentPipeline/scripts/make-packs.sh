#!/bin/bash
# Makes a language's level packs (10) and daily packs (4), exactly as
# shipped: the same command always gives the same packs. About an hour.
#
#   scripts/make-packs.sh en
#
# Each pack is made in pieces of 20 levels, each with its own seed, and each
# piece remembers the pieces before it (--after): recently used words are
# avoided and each word's clues rotate, just as in one long run. Each pack
# carries on from the ones before. The dailies are their own run.
#
# Pack 1's first 20 levels use only data/<lang>/starter-words.txt (everyday
# words), on small boards: the first impression should be easy.
#
# Output: data/<lang>/packs/<lang>-001.json … -010.json and
# daily-<lang>-001.json … -004.json. Then copy pack 1 and daily pack 1 into
# grannys_puzzle/Levels/, and the others into Firebase/public/packs/
# (docs/LevelDelivery.md).
set -euo pipefail
lang=${1:?usage: scripts/make-packs.sh <lang>}
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

boards=6x8,7x9,7x7,8x10
daily_boards=7x9,8x8,7x8

# piece <first level number> <boards> <familiarity> <longest answer> <shape every> <name> <only-words or -> <earlier pieces…>
piece() {
  local first=$1 sizes=$2 familiarity=$3 longest=$4 shapes=$5 name=$6 only=$7
  shift 7
  local options=()
  [ "$only" != "-" ] && options+=(--only-words "$only")
  if [ $# -gt 0 ]; then
    local earlier=()
    for part in "$@"; do earlier+=("$work/$part.json"); done
    options+=(--after "${earlier[@]}")
  fi
  python3 -m pipeline.cli generate --lang "$lang" --count 20 --first-number "$first" --pack "$name" \
    --sizes "$sizes" --max-familiarity "$familiarity" --max-answer-length "$longest" \
    --shape-every "$shapes" --seed "$first" ${options[@]+"${options[@]}"} | tail -1
  mv "data/$lang/packs/$name.json" "$work/$name.json"
}

packs=10          # normal packs: pack 1 ships in the app, the rest online
daily_packs=4     # 400 dailies: a year and a month; every pack full

# Pack 1: an easy start, then the usual boards with a shaped one every 10th.
# Every later pack carries on from all the levels before it.
piece 1 5x6,6x7 10 6 0 p1-1 "data/$lang/starter-words.txt"
earlier=(p1-1)
for first in $(seq 21 20 $((packs * 100 - 19))); do
  name=p-$first
  piece "$first" "$boards" 20 8 10 "$name" - "${earlier[@]}"
  earlier+=("$name")
done

# The dailies, numbered from 900001 so their ids never meet the levels'.
daily=()
for first in $(seq 900001 20 $((900000 + daily_packs * 100 - 19))); do
  name=d-$first
  piece "$first" "$daily_boards" 20 8 0 "$name" - ${daily[@]+"${daily[@]}"}
  daily+=("$name")
done

# Five pieces of 20 to a pack.
out="data/$lang/packs"
made=()
for n in $(seq 1 $packs); do
  id=$(printf "%s-%03d" "$lang" "$n")
  parts=()
  for first in $(seq $(((n - 1) * 100 + 1)) 20 $((n * 100 - 19))); do
    [ "$first" = 1 ] && parts+=("$work/p1-1.json") || parts+=("$work/p-$first.json")
  done
  python3 -m pipeline.cli merge-packs --lang "$lang" --pack "$id" --out "$out/$id.json" "${parts[@]}"
  made+=("$out/$id.json")
done
for n in $(seq 1 $daily_packs); do
  id=$(printf "daily-%s-%03d" "$lang" "$n")
  parts=()
  for first in $(seq $((900000 + (n - 1) * 100 + 1)) 20 $((900000 + n * 100 - 19))); do
    parts+=("$work/d-$first.json")
  done
  python3 -m pipeline.cli merge-packs --lang "$lang" --pack "$id" --out "$out/$id.json" "${parts[@]}"
  made+=("$out/$id.json")
done
python3 -m pipeline.cli validate "${made[@]}"
