# db/

- `schema.sql` — PostgreSQL 16 schema (ทดสอบรันผ่านบน PGlite = Postgres 17 WASM)
- `seed/001_fs_line_items.sql` — รายการย่อในงบการเงิน DBD 38 รายการ (global)
- `seed/002_account_template_peak.sql` — ผังบัญชี PEAK 264 บัญชี + mapping งบ/ภาษี (template)
- `validate.mjs` — โหลด schema + seed + ทดสอบ trigger/roll-up บน PGlite (ไม่ต้องติดตั้ง Postgres)

```bash
npm i @electric-sql/pglite@0.3.4 && node db/validate.mjs
```

สร้างผังบัญชีให้กิจการใหม่: `SELECT seed_chart_of_accounts('<organization_id>');`
