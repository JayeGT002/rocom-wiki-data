#!/usr/bin/env python3
"""Build the browser's normalized JSON dataset from all registered Lua sources."""

import argparse
import json
from pathlib import Path

from pet_data import ROOT, load_pets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "site/data/pets.json",
        help="generated JSON path (default: site/data/pets.json)",
    )
    args = parser.parse_args()
    records = list(load_pets("all").values())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps({"schema_version": 1, "records": records}, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(records)} pet records to {args.output}")


if __name__ == "__main__":
    main()
