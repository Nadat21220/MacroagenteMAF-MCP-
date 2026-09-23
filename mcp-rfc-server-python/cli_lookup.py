#!/usr/bin/env python3
"""CLI de consulta directa a PostgreSQL -- 0 tokens de LLM."""
import argparse
import json

from utils.database import close_db_pool
from utils.rfc_lookup import get_rfc_full, search_rfc


def main():
    parser = argparse.ArgumentParser(description="Lookups RFC sin pasar por Santiago/Ollama")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_rfc = sub.add_parser("rfc", help="Datos completos de un RFC por project_id")
    p_rfc.add_argument("project_id")

    p_search = sub.add_parser("search", help="Buscar RFC por project_id o nombre")
    p_search.add_argument("term")

    args = parser.parse_args()

    if args.cmd == "rfc":
        result = get_rfc_full(args.project_id)
    else:
        result = {"results": search_rfc(args.term)}

    print(json.dumps(result, indent=2, default=str, ensure_ascii=False))
    close_db_pool()


if __name__ == "__main__":
    main()
