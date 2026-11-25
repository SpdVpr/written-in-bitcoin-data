# Written in Bitcoin: open data

Free, weekly-updated tables about what has been written into the Bitcoin blockchain and about bitcoin whose public key is visible on the chain ("quantum-exposed" coins). Every number is computed on our own Bitcoin Core node; nothing comes from other services.

These are the same tables as on the data pages of [writteninbitcoin.com](https://writteninbitcoin.com):

| File | What it holds | Page |
|---|---|---|
| [`data/quantum-by-type.csv`](data/quantum-by-type.csv) | Every output type of the UTXO set: outputs, amount, share of all bitcoin, and whether its public key is visible | [/en/quantum](https://writteninbitcoin.com/en/quantum) |
| [`data/quantum-by-year.csv`](data/quantum-by-year.csv) | Unspent bitcoin with a visible public key by the year its output was created, per output type | [/en/quantum](https://writteninbitcoin.com/en/quantum) |
| [`data/written-by-year.csv`](data/written-by-year.csv) | Per calendar year since 2009: block bytes, bytes of written data, their share, and records and bytes per channel | [/en/block-space](https://writteninbitcoin.com/en/block-space), [/en/in-numbers](https://writteninbitcoin.com/en/in-numbers) |

`data/manifest.json` gives the block and date each file describes. `snapshots/<file>/<date>.csv` keeps every weekly version, so the series can be compared over time. The canonical, always-current copies are at `https://writteninbitcoin.com/datasets/<file>.csv` (CORS enabled); this repository mirrors them every Monday.

## Licence and credit

[CC BY 4.0](LICENSE). You may copy, adapt and publish the data and charts, also commercially, if you credit **Written in Bitcoin** with a link to the page the data comes from, for example:

> Source: [Written in Bitcoin](https://writteninbitcoin.com/en/quantum), data as of block 976,981 (CC BY 4.0)

Ready-made chart images with embed code are at the bottom of each data page. To cite the dataset formally, use [`CITATION.cff`](CITATION.cff) (GitHub shows it under "Cite this repository").

The licence covers these summary tables and the charts on the data pages. It does not cover the rest of the website's database (previews, classifications, decoded texts, the search index); see the [terms](https://writteninbitcoin.com/en/policy/terms).

## Columns

All amounts are exact integers: `_sats` in satoshis, `_bytes` in bytes. `_btc` columns repeat the amount in BTC with eight decimals. Shares are plain fractions (0.0852 = 8.52 %). `as_of_block` and `as_of_date` (UTC) say which block the row describes.

### quantum-by-type.csv

| Column | Meaning |
|---|---|
| `output_type` | `p2pk`, `p2pkh`, `p2sh`, `p2wpkh`, `p2wsh`, `p2tr`, `multisig` (bare multisig), `p2a`, `witness_unknown`, `nonstandard`; `other` sums types our reader does not know yet |
| `public_key` | Where the output keeps its public key: `visible` (in the output itself), `onSpend` (only a hash; the key appears when the coins are spent), `none`, `unknown` |
| `quantum_exposed` | `yes` when the public key is visible before the coins move |
| `outputs` | Number of unspent outputs |
| `amount_sats`, `amount_btc` | Their total amount |
| `share_of_all_bitcoin` | Share of all unspent bitcoin |

### quantum-by-year.csv

| Column | Meaning |
|---|---|
| `year` | Calendar year of the block that created the outputs; `undated` for blocks whose time we could not read yet (normally none) |
| `p2pk_sats`, `p2tr_sats`, `multisig_sats` | Unspent amount with a visible public key, per type |
| `exposed_sats`, `exposed_btc` | Their sum |
| `all_unspent_sats` | All unspent bitcoin created that year, every type |
| `exposed_share_of_year` | `exposed_sats / all_unspent_sats` |

The UTXO snapshot is counted in groups of 1,000 consecutive blocks of creation height (about a week); each group goes to the year of its middle block, so the edges of a year can move by a few days.

### written-by-year.csv

| Column | Meaning |
|---|---|
| `year` | Calendar year (block header time, UTC) |
| `blocks`, `block_bytes` | Blocks of the year and their serialized size, witness data included |
| `written_bytes` | Bytes of written data, all channels together |
| `written_share_of_block_bytes` | `written_bytes / block_bytes` |
| `<channel>_records`, `<channel>_bytes` | Per channel (below); only channels the data holds have columns |

Channels (each byte is counted once, in the channel of the place that holds it):

- `coinbase`: miners' messages, the whole coinbase input script of each block whose coinbase carries a readable message. Pool tags and signalling alone are not counted. One record is one block.
- `hidden`: data in fake public keys of bare multisig outputs, fake addresses, large data pushes of P2SH inputs, readable input scripts and non-standard outputs (texts, files, the 2013 uploads such as the Bitcoin whitepaper). One record is one transaction.
- `op_return`: the data after OP_RETURN in every OP_RETURN output outside the coinbase, without the opcode and push lengths; runestones and Counterparty messages have their own channels. One record is one output with data.
- `counterparty`: each decoded Counterparty message, whatever output carried it (classic Bitcoin Stamps are Counterparty messages and are counted here). One record is one message.
- `ordinals`: everything pushed inside each `ord` envelope in a Taproot witness (content type, other fields and body). One record is one envelope.
- `stamps`: data that Bitcoin Stamps protocols write directly (SRC-20, SRC-721, SRC-101 in bare multisig keys or P2WSH outputs). One record is one transfer, mint or deploy.
- `atomicals`: everything pushed inside each `atom` envelope. One record is one envelope.
- `runes`: the runestone after OP_RETURN OP_13. One record is one output.
- `envelopes`: envelopes with any other tag (PIPE, Alkanes, Tacit, Charms, MetaID and others). One record is one envelope.
- `addresses`: records only (burn and vanity addresses); an address takes the same room as any payment, so it adds no bytes.

Not counted as written data: coinbase OP_RETURN outputs (witness commitments, merged-mining tags), ordinary multisig with valid keys, printable runs that are not readable text, and the outputs, signatures and amounts of ordinary payments. These are bytes, not weight: since SegWit a witness byte weighs one unit and any other byte four, so a share of block bytes is not a share of the block weight limit.

## Method

- **Quantum exposure.** Once a week our Bitcoin Core node writes a snapshot of the whole UTXO set (`dumptxoutset`). Each output is classified by its script type; amounts are exact to the satoshi at the snapshot's block. An output counts as exposed when its public key can be read before the coins move: P2PK and bare multisig write the key into the output script, and a Taproot output is itself a public key. Coins on P2PKH/P2WPKH addresses whose key is already public because the same address spent before (address reuse) are **not** counted yet, so the real amount with a visible key is higher. A visible key says nothing about who owns the coins; no addresses are published.
- **Written data.** A full scan of every block on our own node, classified by the published rules of each protocol and kept current block by block; Ordinals envelopes are counted by the same scan, so the series is complete.
- **Neutral by design.** Whether data belongs in Bitcoin blocks is an open debate (OP_RETURN limits, Ordinals, Runes, Bitcoin Core 30). These tables take no side: measurements and their definitions only.

Questions and corrections: open an issue in this repository.

## About

[Written in Bitcoin](https://writteninbitcoin.com) is a free archive of everything ever written into Bitcoin since 2009, without ads or accounts. This repository holds only the open summary data.
