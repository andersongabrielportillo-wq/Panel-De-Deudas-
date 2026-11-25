-- Private staging; this is NOT the live sales, stock or payroll schema.
-- No source data is committed to Git.
BEGIN;
CREATE SCHEMA IF NOT EXISTS cln_import_private;
REVOKE ALL ON SCHEMA cln_import_private FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS cln_import_private.sources (
 file text PRIMARY KEY, sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$')
);
CREATE TABLE IF NOT EXISTS cln_import_private.source_rows (
 file text NOT NULL REFERENCES cln_import_private.sources(file),
 sheet text NOT NULL,row_number integer NOT NULL CHECK(row_number>0),
 category text NOT NULL CHECK(category IN ('summary_review','exception_review','route_review','sales_adjustment_review')),
 cells jsonb NOT NULL CHECK(jsonb_typeof(cells)='object'),
 PRIMARY KEY(file,sheet,row_number)
);
CREATE TABLE IF NOT EXISTS cln_import_private.sales_stage (
 source_row integer NOT NULL CHECK(source_row>0), modalidad text NOT NULL,
 fecha date, cells jsonb NOT NULL CHECK(jsonb_typeof(cells)='object'),
 status text NOT NULL CHECK(status IN ('eligible','review_future','review_date')),
 PRIMARY KEY(modalidad,source_row),
 CHECK(status<>'eligible' OR (fecha IS NOT NULL AND fecha<DATE '2026-11-01'))
);
CREATE TABLE IF NOT EXISTS cln_import_private.inventory_stage (
 sheet text NOT NULL,row_number integer NOT NULL,article text NOT NULL,
 details jsonb NOT NULL CHECK(jsonb_typeof(details)='object'),PRIMARY KEY(sheet,row_number)
);
CREATE TABLE IF NOT EXISTS cln_import_private.payroll_stage (
 person text NOT NULL,source_key text NOT NULL,
 fields jsonb NOT NULL CHECK(jsonb_typeof(fields)='array'),PRIMARY KEY(person,source_key)
);
CREATE TABLE IF NOT EXISTS cln_import_private.payroll_review (
 name text PRIMARY KEY,details jsonb NOT NULL CHECK(jsonb_typeof(details)='object')
);
ALTER TABLE cln_import_private.sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE cln_import_private.source_rows ENABLE ROW LEVEL SECURITY;
ALTER TABLE cln_import_private.sales_stage ENABLE ROW LEVEL SECURITY;
ALTER TABLE cln_import_private.inventory_stage ENABLE ROW LEVEL SECURITY;
ALTER TABLE cln_import_private.payroll_stage ENABLE ROW LEVEL SECURITY;
ALTER TABLE cln_import_private.payroll_review ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA cln_import_private FROM PUBLIC,anon,authenticated;
-- No browser access, no triggers on the live inventory, no automatic financial posting.
COMMIT;
