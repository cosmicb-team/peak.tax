import { PGlite } from '@electric-sql/pglite';
import { citext } from '@electric-sql/pglite/contrib/citext';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { readFileSync } from 'node:fs';
const db = new PGlite({ extensions: { citext, pg_trgm } });
import { fileURLToPath } from 'node:url'; import { dirname, join } from 'node:path';
const R = join(dirname(fileURLToPath(import.meta.url)), '..') + '/';
const run = async (label, sql) => { try { await db.exec(sql); console.log('OK  ', label); } catch (e) { console.log('FAIL', label, '\n   ', e.message); process.exitCode = 1; } };
await run('schema.sql', readFileSync(R+'db/schema.sql','utf8'));
await run('seed 001', readFileSync(R+'db/seed/001_fs_line_items.sql','utf8'));
await run('seed 002', readFileSync(R+'db/seed/002_account_template_peak.sql','utf8'));
const org = await db.query(`INSERT INTO organization (name) VALUES ('ทดสอบ') RETURNING id`);
const oid = org.rows[0].id;
const n = await db.query(`SELECT seed_chart_of_accounts($1) AS n`, [oid]);
// role + member + policy + number rules 
const role = await db.query(`INSERT INTO org_role (organization_id, code, name, is_system) VALUES ($1,'admin','ผู้ดูแลระบบ',true) RETURNING id`, [oid]);
await db.query(`INSERT INTO role_permission (role_id, permission) VALUES ($1,'create.invoice'),($1,'approve.invoice'),($1,'payment.payment')`, [role.rows[0].id]);
const usr = await db.query(`INSERT INTO app_user (email, display_name) VALUES ('owner@test.local','Owner') RETURNING id`);
await db.query(`INSERT INTO org_member (organization_id, user_id, role_id, is_owner) VALUES ($1,$2,$3,true)`, [oid, usr.rows[0].id, role.rows[0].id]);
await db.query(`INSERT INTO org_accounting_policy (organization_id) VALUES ($1)`, [oid]);
const pol = await db.query(`SELECT gr_ir_clearing_account, credit_note_unref_account, pp30_source_doc_types, inventory_method FROM org_accounting_policy WHERE organization_id=$1`, [oid]);
console.log('policy defaults:', JSON.stringify(pol.rows[0]));
await db.query(`INSERT INTO document_number_rule (organization_id, doc_type, series, prefix) VALUES ($1,'invoice','main','IV'),($1,'invoice','tax_invoice','IVT'),($1,'deposit','main','DR'),($1,'deposit','tax_invoice','DRT')`, [oid]);
await db.query(`INSERT INTO document_sequence (organization_id, doc_type, series, period_key, next_seq) VALUES ($1,'invoice','tax_invoice','202611',1)`, [oid]);
const rules = await db.query(`SELECT doc_type, series, prefix FROM document_number_rule WHERE organization_id=$1 ORDER BY 1,2`, [oid]);
console.log('number rules:', rules.rows.map(r=>r.doc_type+'/'+r.series+'='+r.prefix).join(', '));
// warehouse, item with inventory, asset group, webhook, api client
const wh = await db.query(`INSERT INTO warehouse (organization_id, code, name) VALUES ($1,'WH01','คลังหลัก') RETURNING id`, [oid]);
const it = await db.query(`INSERT INTO item (organization_id, code, type, name, sell_account, purchase_account, inventory_account, cogs_account, track_inventory) VALUES ($1,'P001','product','สินค้า A','410101','510101','114102','510101',true) RETURNING id`, [oid]);
await db.query(`INSERT INTO stock_layer (organization_id, item_id, warehouse_id, received_date, quantity_in, quantity_remaining, unit_cost) VALUES ($1,$2,$3,'2026-11-01',10,10,80)`, [oid, it.rows[0].id, wh.rows[0].id]);
await db.query(`INSERT INTO stock_movement (organization_id, item_id, warehouse_id, movement_date, quantity, unit_cost, reason) VALUES ($1,$2,$3,'2026-11-01',10,80,'purchase'),($1,$2,$3,'2026-11-05',-3,80,'sale')`, [oid, it.rows[0].id, wh.rows[0].id]);
const stk = await db.query(`SELECT quantity, value FROM v_stock_balance WHERE organization_id=$1`, [oid]);
console.log('stock balance:', JSON.stringify(stk.rows[0]), '(expect 7 / 560)');
await db.query(`INSERT INTO asset_group (organization_id, code, name, asset_account, accumulated_depreciation_account, depreciation_expense_account, useful_life_months) VALUES ($1,'AG01','อุปกรณ์สำนักงาน','124106','124206','530301',60)`, [oid]).catch(e=>console.log('asset_group note:', e.message.split('\n')[0]));
const wh1 = await db.query(`INSERT INTO webhook_endpoint (organization_id, url, secret, event_types) VALUES ($1,'https://example.test/hook','s3cret',ARRAY['invoice.created','invoice.paid_payment']) RETURNING id`, [oid]);
await db.query(`INSERT INTO webhook_delivery (endpoint_id, event_id, event_type, payload, next_attempt_at) VALUES ($1, gen_random_uuid(), 'invoice.created', '{"code":"IV-1"}', now())`, [wh1.rows[0].id]);
await db.query(`INSERT INTO api_client (organization_id, name, kind, key_hash, key_prefix, scopes) VALUES ($1,'Hermes','mcp','hash1','****-15ea',ARRAY['view.invoice','create.invoice'])`, [oid]);
console.log('integration tables OK');
console.log('seeded accounts:', n.rows[0].n);
const cats = await db.query(`SELECT category, COUNT(*)::int c FROM account WHERE organization_id=$1 GROUP BY 1 ORDER BY 1`, [oid]);
console.log('by category:', JSON.stringify(cats.rows));
const sys = await db.query(`SELECT COUNT(*)::int c FROM account WHERE organization_id=$1 AND is_system`, [oid]);
console.log('system accounts:', sys.rows[0].c);
// trigger tests
await db.query(`INSERT INTO account (organization_id, code, name_th, fs_line_item, is_contra, category, normal_balance) VALUES ($1,'520220','ค่าโฆษณา TikTok','PL-04',false,'asset','credit')`, [oid]);
const chk = await db.query(`SELECT category, normal_balance, is_current FROM account WHERE organization_id=$1 AND code='520220'`, [oid]);
console.log('custom account derived:', JSON.stringify(chk.rows[0]), '(expect expense/debit/null)');
// balanced journal + roll-up
await db.query(`INSERT INTO journal (id, organization_id, code, journal_type, issued_date, description, total_debit, total_credit)
  VALUES ('00000000-0000-0000-0000-000000000001',$1,'JV-1','sales','2026-11-09','ขายบริการ 10,000 + VAT หัก WHT 3%',10700,10700)`, [oid]);
await db.query(`INSERT INTO journal_entry (journal_id, line_no, account_code, debit, credit) VALUES
  ('00000000-0000-0000-0000-000000000001',1,'111301',10400,0),
  ('00000000-0000-0000-0000-000000000001',2,'115403',300,0),
  ('00000000-0000-0000-0000-000000000001',3,'410201',0,10000),
  ('00000000-0000-0000-0000-000000000001',4,'215101',0,700)`);
const fs = await db.query(`SELECT statement, fs_code, name_th, amount FROM v_fs_rollup WHERE organization_id=$1 AND amount<>0 ORDER BY statement, sort_order`, [oid]);
console.table(fs.rows);
const tax = await db.query(`SELECT tax_form, code, name_th, balance FROM v_tax_positions WHERE organization_id=$1 AND balance<>0`, [oid]);
console.table(tax.rows);
// period lock: lock Oct 2026 then try to post a journal there
await db.query(`INSERT INTO accounting_period_lock (organization_id, period_month) VALUES ($1,'2026-10-01')`, [oid]);
const open = await db.query(`SELECT COUNT(*)::int c FROM v_open_items WHERE organization_id=$1`, [oid]);
console.log('open items view OK, rows:', open.rows[0].c);
// exception tests last (PGlite may crash after RAISE inside trigger)
try { await db.query(`INSERT INTO journal_entry (journal_id, line_no, account_code, debit, credit) VALUES ('00000000-0000-0000-0000-000000000001',5,'111101',5,5)`); console.log('FAIL one-side check'); }
catch (e) { console.log('OK   one-side-only CHECK:', e.message.split('\n')[0]); }
try { await db.query(`UPDATE account SET fs_line_item='PL-05' WHERE organization_id=$1 AND code='215101'`, [oid]); console.log('FAIL system lock not enforced'); }
catch (e) { console.log('OK   system lock trigger:', e.message.split('\n')[0]); }
try { await db.query(`INSERT INTO journal (organization_id, code, journal_type, issued_date, description, total_debit, total_credit) VALUES ($1,'JV-OLD','general','2026-10-15','ลงงวดที่ล็อก',0,0)`, [oid]); console.log('FAIL period lock not enforced'); }
catch (e) { console.log('OK   period lock trigger:', e.message.split('\n')[0]); }
