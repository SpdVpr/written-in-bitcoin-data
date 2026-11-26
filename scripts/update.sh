#!/usr/bin/env bash
# Fetches the current CSV files from https://writteninbitcoin.com/datasets/ (the canonical source) into data/, keeps a dated
# copy per file in snapshots/<name>/<as_of_date>.csv and writes data/manifest.json. Run weekly by
# .github/workflows/update.yml; safe to run by hand. Stops without touching anything when a file looks wrong.
set -euo pipefail
cd "$(dirname "$0")/.."
BASE=${WIB_DATASETS:-https://writteninbitcoin.com/datasets}
UA='written-in-bitcoin-data/1.0 (+https://github.com/SpdVpr/written-in-bitcoin-data)'
NAMES=(quantum-by-type quantum-by-year written-by-year puzzles)
declare -A HEADER=(
  [quantum-by-type]='output_type,public_key,quantum_exposed,outputs,amount_sats,amount_btc,share_of_all_bitcoin,as_of_block,as_of_date'
  [quantum-by-year]='year,p2pk_sats,p2tr_sats,multisig_sats,exposed_sats,exposed_btc,all_unspent_sats,exposed_share_of_year,as_of_block,as_of_date'
  # the channel columns that follow depend on which channels the data holds
  [written-by-year]='year,blocks,block_bytes,written_bytes,written_share_of_block_bytes,'
  # bitcoin puzzles and bounties, one row each, checked against the site's own node
  [puzzles]='slug,title,page,state,waiting_btc,waiting_sats,prize_sats,announced_txid,announced_height,resolution_txid,resolution_height,checked_at,checked_height'
)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# 1. fetch and check every file first; nothing is written unless every file is fine
for name in "${NAMES[@]}"; do
  curl -fsS --retry 3 --retry-delay 30 -A "$UA" -o "$tmp/$name.csv" "$BASE/$name.csv"
  header=$(head -1 "$tmp/$name.csv" | tr -d '\r')
  case "$header" in "${HEADER[$name]}"*) ;; *) echo "unexpected header in $name.csv: $header" >&2; exit 1;; esac
  rows=$(( $(wc -l < "$tmp/$name.csv") - 1 ))
  [ "$rows" -ge 5 ] || { echo "$name.csv has only $rows data rows" >&2; exit 1; }
  first=$(sed -n 2p "$tmp/$name.csv" | tr -d '\r')
  case "$header" in
    *,as_of_block,as_of_date) date=$(awk -F, '{print $NF}' <<<"$first"); block=$(awk -F, '{print $(NF-1)}' <<<"$first") ;;
    # puzzles.csv: the time and block of the last check against the node (the last two columns never hold a comma)
    *,checked_at,checked_height) date=$(awk -F, '{print substr($(NF-1),1,10)}' <<<"$first"); block=$(awk -F, '{print $NF}' <<<"$first") ;;
    *) echo "$name.csv: no as_of or checked columns" >&2; exit 1;;
  esac
  [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && "$block" =~ ^[0-9]+$ ]] || { echo "$name.csv: bad as_of values ($block, $date)" >&2; exit 1; }
  printf '%s %s %s %s\n' "$name" "$block" "$date" "$rows" >> "$tmp/meta"
done

# 2. store: the current file, a dated snapshot, the manifest
entries=()
while read -r name block date rows; do
  cp "$tmp/$name.csv" "data/$name.csv"
  mkdir -p "snapshots/$name"; cp "$tmp/$name.csv" "snapshots/$name/$date.csv"
  sha=$(sha256sum "data/$name.csv" | cut -d' ' -f1)
  entries+=("    {\"name\": \"$name.csv\", \"as_of_block\": $block, \"as_of_date\": \"$date\", \"rows\": $rows, \"sha256\": \"$sha\", \"source\": \"$BASE/$name.csv\"}")
done < "$tmp/meta"
{
  printf '{\n  "license": "CC-BY-4.0",\n  "files": [\n'
  for i in "${!entries[@]}"; do printf '%s%s\n' "${entries[$i]}" "$([ "$i" -lt $(( ${#entries[@]} - 1 )) ] && echo ,)"; done
  printf '  ]\n}\n'
} > data/manifest.json
cat "$tmp/meta"
