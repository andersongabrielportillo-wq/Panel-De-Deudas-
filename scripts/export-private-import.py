#!/usr/bin/env python3
"""Export a local, private SQLite staging database to PostgreSQL staging SQL.
No application data is written to this repository. No network calls are made.
Run with a local private database and store output outside the repository.
The result uses COPY FROM STDIN; execute using an authorized psql connection.
"""
import argparse
import csv
import io
import json
import os
import pathlib
import sqlite3

TABLES = {
    "sources": ("file", "sha256"),
    "source_rows": ("file", "sheet", "row_number", "category", "cells"),
    "sales_stage": ("source_row", "modalidad", "fecha", "cells", "status"),
    "inventory_stage": ("sheet", "row_number", "article", "details"),
    "payroll_stage": ("person", "source_key", "fields"),
    "payroll_review": ("name", "details"),
}
KEYS = {
    "sources": ("file",), "source_rows": ("file", "sheet", "row_number"),
    "sales_stage": ("modalidad", "source_row"),
    "inventory_stage": ("sheet", "row_number"),
    "payroll_stage": ("person", "source_key"),
    "payroll_review": ("name",),
}

def validate(db):
    if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
        raise ValueError("SQLite integrity check failed")
    if db.execute("SELECT count(*) FROM sales_stage WHERE status='eligible' AND (fecha IS NULL OR fecha >= '2026-11-01')").fetchone()[0]:
        raise ValueError("Forbidden sales date in eligible staging")
    for (fields,) in db.execute("SELECT fields FROM payroll_stage"):
        if not isinstance(json.loads(fields), list) or any(f.get("valor") is not None for f in json.loads(fields)):
            raise ValueError("Historical payroll value present")
    return {name: db.execute("SELECT count(*) FROM "+name).fetchone()[0] for name in TABLES}

def export(db, out):
    out.write("\\set ON_ERROR_STOP on\nBEGIN;\n")
    for table, cols in TABLES.items():
        target = "cln_import_private."+table
        temp = "cln_tmp_"+table
        col = ",".join(cols)
        key = ",".join(KEYS[table])
        join = " AND ".join("t."+k+"=s."+k for k in KEYS[table])
        out.write(f"CREATE TEMP TABLE {temp} (LIKE {target} INCLUDING ALL) ON COMMIT DROP;\n")
        out.write(f"COPY {temp} ({col}) FROM STDIN WITH (FORMAT csv, NULL '__CLN_NULL__');\n")
        for row in db.execute(f"SELECT {col} FROM {table}"):
            vals=[]
            for val in row:
                if val is None:
                    vals.append("__CLN_NULL__")
                else:
                    val=str(val)
                    if val=="__CLN_NULL__" or "\r" in val or "\n" in val or "\\."==val:
                        raise ValueError("Unexpected multiline or reserved cell in staging; normalize before export")
                    b=io.StringIO(newline="")
                    csv.writer(b,quoting=csv.QUOTE_ALL,lineterminator="").writerow([val])
                    vals.append(b.getvalue())
            out.write(",".join(vals)+"\n")
        out.write("\\.\n")
        # A duplicate key is acceptable only when every field matches.
        out.write(f"DO $$ BEGIN IF EXISTS (SELECT 1 FROM {temp} s JOIN {target} t ON {join} WHERE to_jsonb(s) IS DISTINCT FROM to_jsonb(t)) THEN RAISE EXCEPTION 'Staging conflict in {table}'; END IF; END $$;\n")
        out.write(f"INSERT INTO {target} ({col}) SELECT {col} FROM {temp} ON CONFLICT ({key}) DO NOTHING;\n")
    out.write("COMMIT;\n")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("sqlite_file",type=pathlib.Path)
    p.add_argument("--output",type=pathlib.Path,help="Private SQL output; omit to validate only")
    a=p.parse_args()
    with sqlite3.connect(a.sqlite_file.resolve().as_uri()+"?mode=ro",uri=True) as db:
        print(json.dumps(validate(db)))
        if a.output:
            fd=os.open(a.output,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
            try:
                with os.fdopen(fd,"w",encoding="utf-8",newline="") as out: export(db,out)
            except BaseException:
                a.output.unlink(missing_ok=True)
                raise
if __name__=="__main__": main()
