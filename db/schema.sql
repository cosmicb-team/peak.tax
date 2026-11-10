-- Accounting & Tax Core schema (PostgreSQL 15+) — ต้นแบบจากโปรแกรม PEAK
-- One schema, multi-tenant via organization_id.

-- gen_random_uuid() is built-in since PostgreSQL 13; no pgcrypto needed
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============ ENUMS ============
CREATE TYPE contact_type AS ENUM ('none','limited_partnership','company_limited','public_company','shop',
  'ordinary_person','body_of_persons','others','ordinary_partnership','foundation','association','joint_venture');
CREATE TYPE prefix_name_type AS ENUM ('none','khun','mr','mrs','miss','other');
CREATE TYPE account_category AS ENUM ('asset','liability','equity','revenue','expense','suspense');
CREATE TYPE payment_method_type AS ENUM ('others','cash','bank_account','credit_card','ewallet','expense_claim'); -- expense_claim = สำรองรับจ่าย (เงินทดรองพนักงาน)
CREATE TYPE bank_account_type AS ENUM ('current','savings','fixed_deposit');
CREATE TYPE vat_type AS ENUM ('none','zero','seven');            -- 1,2,3
CREATE TYPE tax_status AS ENUM ('exclude_tax','include_tax','non_tax'); -- 0,1,2
CREATE TYPE item_type AS ENUM ('product','service','bundle');   -- PEAK: สินค้า / บริการ / รายการจัดชุด
CREATE TYPE document_type AS ENUM (
  -- sales (PEAK prefix): QO, TDN, DR/DRT, IV/IVT, DN, RE/RT, TIV, CN/CNT, BN, DBN/DBNT
  'quotation','temporary_delivery_note','invoice','delivery_note','receipt','tax_invoice','credit_note','billing_note','debit_note','deposit',
  -- purchase: PR, PO/POA, DP, EXP, CNX, CPN, PA, GR, IR, DBNX
  'purchase_requisition','purchase_order','asset_purchase_order','expense','asset_purchase','credit_note_expense','billing_note_expense','debit_note_expense',
  'deposit_expense','goods_receipt','invoice_receipt',
  -- inventory (PRR, return, cost adjustment, transfer) — ลงบัญชีสินค้าคงเหลือ/ต้นทุน
  'product_requisition','product_requisition_return','cost_adjustment','stock_transfer');
CREATE TYPE document_status AS ENUM (
  'draft','await_approval','approved','outstanding','overdue','paid','got_receipt',
  'issued_invoice_receipt','already_issued','voided');
CREATE TYPE journal_type AS ENUM ('purchase','sales','payment','receive','general','tax'); -- 1..5 + JVTX (PEAK สมุดรายวันภาษี: ย้าย 115402→115401)
-- PEAK UI: ร่าง / รอตรวจสอบ / รออนุมัติ / ควรพิจารณา (AI flag) / อนุมัติแล้ว / ยกเลิก
CREATE TYPE journal_status AS ENUM ('draft','await_review','await_approval','flagged','approved','voided');
CREATE TYPE price_type AS ENUM ('exclude_tax','include_tax');
CREATE TYPE inventory_method AS ENUM ('perpetual','periodic');
CREATE TYPE tax_invoice_default AS ENUM ('issue','not_issue','auto');
CREATE TYPE over_limit_policy AS ENUM ('allow','warn','block');
CREATE TYPE etax_status AS ENUM ('none','pending','submitted','accepted','rejected','voided');
CREATE TYPE wht_remit_status AS ENUM ('pending','filed','paid');
CREATE TYPE cost_allocation_method AS ENUM ('by_value','by_quantity');
CREATE TYPE depreciation_method AS ENUM ('straight_line','declining_balance','none');
CREATE TYPE credit_note_reason AS ENUM ('none','promotion_marketing','office_use','production_use',
  'service_use','donation','damage_or_loss','others');

-- ============ TENANT ============
CREATE TABLE organization (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  tax_number char(13),
  branch_code char(5) DEFAULT '00000',
  is_vat_registered boolean NOT NULL DEFAULT false,
  use_product_code boolean NOT NULL DEFAULT false,
  fiscal_year_start_month smallint NOT NULL DEFAULT 1 CHECK (fiscal_year_start_month BETWEEN 1 AND 12),
  base_currency char(3) NOT NULL DEFAULT 'THB',
  vat_registered_date date,
  business_type text,              -- บริษัทจำกัด / หจก. / บุคคลธรรมดา ...
  company_name_en text,
  registered_date date,
  address_th text, address_en text, delivery_address text,
  phone text, email text, email_backup text, fax text, website text, line_id text,
  logo_url text, stamp_url text,
  locked_before_date date,         -- PEAK "ล็อกข้อมูลการใช้งาน": ห้ามสร้าง/แก้/void เอกสารและ JV ที่วันที่ < ค่านี้
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app_user (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email citext UNIQUE NOT NULL,
  display_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- PEAK built-in roles: ผู้ดูแลระบบ, ผู้ดูแลบัญชีการเงิน, บัญชีการเงิน, บัญชีการเงินและเงินเดือน, จัดการเอกสารทั้งหมด,
-- ร่างเอกสารทั้งหมด, จัดการเอกสารฝั่งรายรับ, จัดการใบเสนอราคา (+ custom ≤100)
CREATE TABLE org_role (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL,              -- admin / finance_admin / finance / finance_payroll / all_docs / draft_all / sales_docs / quotation_only / custom-*
  name text NOT NULL,
  is_system boolean NOT NULL DEFAULT false,
  UNIQUE (organization_id, code)
);
-- permission strings: create|edit|delete|approve|view.<entity>, payment.payment, payment.payment(Expense), create.finance, view.chartOfAccount, create.dailyJournal, lock.period, manage.settings ...
CREATE TABLE role_permission (
  role_id uuid NOT NULL REFERENCES org_role(id) ON DELETE CASCADE,
  permission text NOT NULL,
  PRIMARY KEY (role_id, permission)
);
CREATE TABLE org_member (
  organization_id uuid REFERENCES organization(id) ON DELETE CASCADE,
  user_id uuid REFERENCES app_user(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES org_role(id),
  is_owner boolean NOT NULL DEFAULT false,
  position text, department text, signature_url text,
  invited_at timestamptz, accepted_at timestamptz,
  PRIMARY KEY (organization_id, user_id)
);

-- Document numbering rule per org per type (PEAK หน้า "เลขที่เอกสาร": ตัวอักษรเริ่มต้น ≤2 + ตัวอักษรพิเศษ + ปี + เดือน + วัน + running)
-- series: 'main' = IV/RE/DR/CN/DBN/PO ..., 'tax_invoice' = IVT/RT/DRT/CNT/DBNT (แยกชุดเมื่อ is_tax_invoice), 'asset' = POA
CREATE TABLE document_number_rule (
  organization_id uuid REFERENCES organization(id) ON DELETE CASCADE,
  doc_type document_type NOT NULL,
  series text NOT NULL DEFAULT 'main' CHECK (series IN ('main','tax_invoice','asset')),
  prefix text NOT NULL CHECK (length(prefix) <= 4),      -- IV, IVT, TDN, CPN ...
  special_char text NOT NULL DEFAULT '' CHECK (length(special_char) <= 1),  -- '-' ใน DR-2026...
  include_year boolean NOT NULL DEFAULT true,
  include_month boolean NOT NULL DEFAULT true,
  include_day boolean NOT NULL DEFAULT false,
  running_digits smallint NOT NULL DEFAULT 5 CHECK (running_digits BETWEEN 3 AND 8),
  reset_period text NOT NULL DEFAULT 'month' CHECK (reset_period IN ('never','year','month','day')),
  is_separate_series boolean NOT NULL DEFAULT true,     -- PEAK "แยกเลขที่เรียงใบกำกับภาษี"
  PRIMARY KEY (organization_id, doc_type, series)
);
-- Counter (atomic): one row per rule per period
CREATE TABLE document_sequence (
  organization_id uuid NOT NULL,
  doc_type document_type NOT NULL,
  series text NOT NULL DEFAULT 'main',
  period_key text NOT NULL,        -- '' | yyyy | yyyyMM | yyyyMMdd ตาม reset_period
  next_seq integer NOT NULL DEFAULT 1,
  PRIMARY KEY (organization_id, doc_type, series, period_key),
  FOREIGN KEY (organization_id, doc_type, series) REFERENCES document_number_rule(organization_id, doc_type, series) ON DELETE CASCADE
);
-- Reservation log: เลขที่ที่ถูกใช้แล้ว (void ก็ยังอยู่) → บังคับ "ห้ามใช้เลขใบกำกับภาษีซ้ำ" แม้ policy reuse_voided_number = true
CREATE TABLE document_number_used (
  organization_id uuid NOT NULL,
  doc_type document_type NOT NULL,
  code text NOT NULL,
  document_id uuid,
  is_tax_invoice boolean NOT NULL DEFAULT false,
  used_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, doc_type, code)
);

-- ============ ORG POLICY (PEAK "ตั้งค่านโยบายบัญชี" + "ตั้งค่าเอกสาร") ============
-- ค่าที่ PEAK ให้แก้ได้ใน UI; ค่า default = ค่าของ PEAK (9 พ.ย. 2569)
CREATE TABLE org_accounting_policy (
  organization_id uuid PRIMARY KEY REFERENCES organization(id) ON DELETE CASCADE,
  -- บันทึกบัญชีรายรับ/รายจ่าย (GL mapping ที่แก้ได้)
  debit_note_unref_account text NOT NULL DEFAULT '113301',           -- ใบเพิ่มหนี้ไม่อ้างอิง → ลูกหนี้อื่น
  credit_note_unref_account text NOT NULL DEFAULT '212306',          -- ใบลดหนี้ไม่อ้างอิง → เจ้าหนี้อื่น
  received_debit_note_unref_account text NOT NULL DEFAULT '212306',
  received_credit_note_unref_account text NOT NULL DEFAULT '113301',
  gr_ir_clearing_account text NOT NULL DEFAULT '212305',             -- บันทึกบัญชีกระทบเอกสาร IR/GR
  -- ใบกำกับภาษี / ภ.พ.30
  tax_invoice_default_deposit tax_invoice_default NOT NULL DEFAULT 'issue',
  tax_invoice_default_invoice tax_invoice_default NOT NULL DEFAULT 'auto',   -- auto: สินค้า→ออก, บริการ→ไม่ออก (ออกตอนรับเงิน)
  tax_invoice_default_receipt tax_invoice_default NOT NULL DEFAULT 'issue',
  allow_tax_invoice_without_vat boolean NOT NULL DEFAULT false,
  pp30_file_exempt_sales boolean NOT NULL DEFAULT true,              -- ยื่นยอดขายที่ได้รับยกเว้นทุกรายการ
  pp30_source_doc_types document_type[] NOT NULL DEFAULT ARRAY['deposit','invoice','receipt','credit_note','debit_note']::document_type[],
  -- ราคา / ชื่อซ้ำ / เลขที่
  default_price_type price_type NOT NULL DEFAULT 'exclude_tax',
  allow_duplicate_contact_name boolean NOT NULL DEFAULT true,
  allow_duplicate_item_name boolean NOT NULL DEFAULT true,
  reuse_voided_number boolean NOT NULL DEFAULT false,                -- PEAK default = ใช้ได้; ของเรา default = ไม่ (ใบกำกับภาษีห้ามซ้ำเสมอ)
  -- สมุดรายวัน (PEAK PREMIUM "ตั้งค่าบัญชีรายวัน")
  journal_creator_is_approver boolean NOT NULL DEFAULT true,
  document_journal_default_status journal_status NOT NULL DEFAULT 'await_approval',
  depreciation_journal_default_status journal_status NOT NULL DEFAULT 'await_approval',
  -- สินค้า
  inventory_method inventory_method NOT NULL DEFAULT 'perpetual',
  cogs_on_sale_default boolean NOT NULL DEFAULT true,
  cogs_on_sale_editable boolean NOT NULL DEFAULT true,
  use_sku boolean NOT NULL DEFAULT false,
  default_warehouse_sales uuid, default_warehouse_purchase uuid, default_warehouse_requisition uuid,
  -- วงเงินขายเชื่อ (ตั้งค่าผู้ติดต่อ)
  credit_limit_default_enabled boolean NOT NULL DEFAULT false,
  over_limit_quotation over_limit_policy NOT NULL DEFAULT 'warn',
  over_limit_deposit over_limit_policy NOT NULL DEFAULT 'warn',
  over_limit_invoice over_limit_policy NOT NULL DEFAULT 'warn',
  contact_prefix_none text NOT NULL DEFAULT 'C', contact_prefix_customer text NOT NULL DEFAULT 'C', contact_prefix_vendor text NOT NULL DEFAULT 'V',
  -- ออกเอกสารต่อจาก QO/PO (PREMIUM)
  qo_over_amount over_limit_policy NOT NULL DEFAULT 'warn',
  po_over_amount over_limit_policy NOT NULL DEFAULT 'warn',
  -- ลิงก์สาธารณะ
  public_link_income text NOT NULL DEFAULT 'anyone' CHECK (public_link_income IN ('anyone','org_only')),
  public_link_expense text NOT NULL DEFAULT 'org_only' CHECK (public_link_expense IN ('anyone','org_only')),
  public_link_journal text NOT NULL DEFAULT 'org_only' CHECK (public_link_journal IN ('anyone','org_only')),
  public_link_tax_docs text NOT NULL DEFAULT 'anyone' CHECK (public_link_tax_docs IN ('anyone','org_only')),
  public_link_show_signature boolean NOT NULL DEFAULT false,
  public_link_show_stamp boolean NOT NULL DEFAULT false,
  public_link_password_enabled boolean NOT NULL DEFAULT false,
  -- e-Tax
  etax_provider text CHECK (etax_provider IN ('inet','leceipt','google_timestamp')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
-- หมายเหตุ/วันครบกำหนด default ต่อชนิดเอกสาร (PEAK "หมายเหตุเอกสาร", "วันที่ครบกำหนด")
CREATE TABLE document_type_default (
  organization_id uuid REFERENCES organization(id) ON DELETE CASCADE,
  doc_type document_type NOT NULL,
  default_remark text CHECK (default_remark IS NULL OR length(default_remark) <= 1000),
  due_days integer CHECK (due_days IS NULL OR due_days >= 0),    -- X วันหลังวันที่ออก
  PRIMARY KEY (organization_id, doc_type)
);

-- Locked accounting periods (PEAK: "Locked period" error)
CREATE TABLE accounting_period_lock (
  organization_id uuid REFERENCES organization(id) ON DELETE CASCADE,
  period_month date NOT NULL,      -- 1st of month
  locked_at timestamptz NOT NULL DEFAULT now(),
  locked_by uuid REFERENCES app_user(id),
  PRIMARY KEY (organization_id, period_month)
);

-- ============ MASTER DATA ============

-- ชั้นที่ 2: รายการย่อในงบการเงิน (DBD) — กำหนดเองไม่ได้ ทุกบัญชีต้อง roll up มาที่นี่
CREATE TYPE fs_statement AS ENUM ('BS','PL','NONE');
CREATE TYPE fs_section AS ENUM ('current_asset','non_current_asset','current_liability','non_current_liability','equity',
  'revenue','expense','finance_cost','income_tax','suspense');
CREATE TABLE fs_line_item (
  code text PRIMARY KEY,               -- BS-A-01 ... PL-08, NONE
  statement fs_statement NOT NULL,
  section fs_section NOT NULL,
  sort_order smallint NOT NULL,
  name_th text NOT NULL,
  name_en text,
  cash_flow_section text CHECK (cash_flow_section IN ('operating','investing','financing','cash'))  -- งบกระแสเงินสดทางอ้อม (NULL = ไม่เกี่ยว/PL)
);

CREATE TYPE normal_balance AS ENUM ('debit','credit');
CREATE TYPE tax_kind AS ENUM (
  'vat_output','vat_output_pending','vat_payable','vat_input','vat_input_pending','vat_input_disallowed',
  'vat_credit_carry','vat_refund_receivable','vat_reverse_charge',
  'wht_receivable','wht_payable','cit_prepaid','cit_payable','cit_expense','tax_payable_other',
  'sbt_payable','sbt_expense','sso_payable','sso_expense','ewf_payable','ewf_expense',
  'local_tax','stamp_duty','penalty');
CREATE TYPE tax_form AS ENUM ('PP30','PP36','PND1','PND2','PND3','PND50','PND51','PND53','PND54','PT40','SSO','EWF');
CREATE TYPE cit_deductibility AS ENUM ('full','limited','none');

-- Template กลาง (ผัง PEAK 264 บัญชี) — คัดลอกเข้า org ตอนสร้างกิจการ แล้ว org แก้ชั้นที่ 3 ได้อิสระ
CREATE TABLE account_template (
  code char(6) PRIMARY KEY CHECK (code ~ '^[1-59][0-9]{5}$'),
  name_th text NOT NULL,
  name_en text,
  normal_balance normal_balance NOT NULL,
  is_contra boolean NOT NULL DEFAULT false,
  fs_line_item text NOT NULL REFERENCES fs_line_item(code),
  is_current boolean,
  tax_kind tax_kind,
  tax_form tax_form,
  cit_deductible cit_deductibility,
  ext_codes jsonb NOT NULL DEFAULT '{}'::jsonb      -- {"express":"5210-01",...} สำหรับ plug ระบบอื่น
);

CREATE TABLE account (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL,                                -- ชั้นที่ 3: org กำหนดเองได้ (ไม่บังคับ 6 หลัก)
  name_th text NOT NULL,
  name_en text,
  -- ชั้นที่ 1: หมวดใหญ่ 5 หมวด — derive จาก fs_line_item ไม่ให้ผู้ใช้เลือกขัดกัน
  category account_category NOT NULL,
  normal_balance normal_balance NOT NULL,
  is_contra boolean NOT NULL DEFAULT false,
  -- ชั้นที่ 2: roll-up งบการเงิน — บังคับ
  fs_line_item text NOT NULL REFERENCES fs_line_item(code),
  is_current boolean,
  -- ภาษี
  tax_kind tax_kind,
  tax_form tax_form,
  cit_deductible cit_deductibility,                  -- NULL สำหรับหมวดที่ไม่ใช่ค่าใช้จ่าย
  -- โครงสร้างต้นไม้ (optional) + ที่มา
  parent_code text,
  level smallint NOT NULL DEFAULT 1,
  template_code char(6) REFERENCES account_template(code),  -- NULL = บัญชีที่ org เพิ่มเอง
  ext_codes jsonb NOT NULL DEFAULT '{}'::jsonb,
  allow_posting boolean NOT NULL DEFAULT true,       -- false = header/group account
  is_active boolean NOT NULL DEFAULT true,
  is_system boolean NOT NULL DEFAULT false,          -- true = ระบบใช้โพสต์อัตโนมัติ ห้ามลบ/เปลี่ยนหมวด (113101, 212101, 2151xx, 1154xx ...)
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, code),
  UNIQUE (id),
  FOREIGN KEY (organization_id, parent_code) REFERENCES account(organization_id, code),
  -- category ต้องสอดคล้องกับ fs_line_item (บังคับผ่าน trigger ด้านล่าง)
  CHECK (cit_deductible IS NULL OR category = 'expense')
);
CREATE INDEX account_org_fs_idx ON account(organization_id, fs_line_item);

-- Trigger: category/is_current ต้องตรงกับ section ของ fs_line_item เสมอ
CREATE OR REPLACE FUNCTION account_enforce_fs() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE sec fs_section;
BEGIN
  SELECT section INTO sec FROM fs_line_item WHERE code = NEW.fs_line_item;
  NEW.category := CASE sec
    WHEN 'current_asset' THEN 'asset' WHEN 'non_current_asset' THEN 'asset'
    WHEN 'current_liability' THEN 'liability' WHEN 'non_current_liability' THEN 'liability'
    WHEN 'equity' THEN 'equity' WHEN 'revenue' THEN 'revenue'
    WHEN 'expense' THEN 'expense' WHEN 'finance_cost' THEN 'expense' WHEN 'income_tax' THEN 'expense'
    ELSE 'suspense' END;
  NEW.is_current := CASE sec WHEN 'current_asset' THEN true WHEN 'current_liability' THEN true
    WHEN 'non_current_asset' THEN false WHEN 'non_current_liability' THEN false ELSE NULL END;
  -- normal_balance derive เสมอจาก category + is_contra (ผู้ใช้ตั้งเองไม่ได้)
  NEW.normal_balance := CASE WHEN NEW.category IN ('asset','expense','suspense') THEN 'debit' ELSE 'credit' END;
  IF NEW.is_contra THEN NEW.normal_balance := CASE NEW.normal_balance WHEN 'debit' THEN 'credit' ELSE 'debit' END; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER account_enforce_fs_trg BEFORE INSERT OR UPDATE OF fs_line_item, is_contra, normal_balance, category ON account
  FOR EACH ROW EXECUTE FUNCTION account_enforce_fs();

-- ห้ามเปลี่ยนหมวด/fs ของบัญชีระบบ และห้ามเปลี่ยน fs ของบัญชีที่มี journal แล้วข้ามงบ (BS <-> PL)
CREATE OR REPLACE FUNCTION account_protect_system() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.is_system AND (NEW.fs_line_item <> OLD.fs_line_item OR NEW.tax_kind IS DISTINCT FROM OLD.tax_kind) THEN
    RAISE EXCEPTION 'SYSTEM_ACCOUNT_LOCKED: % is used by automatic posting', OLD.code;
  END IF;
  IF NEW.fs_line_item <> OLD.fs_line_item
     AND (SELECT statement FROM fs_line_item WHERE code=NEW.fs_line_item) <> (SELECT statement FROM fs_line_item WHERE code=OLD.fs_line_item)
     AND EXISTS (SELECT 1 FROM journal_entry je JOIN journal j ON j.id=je.journal_id
                 WHERE j.organization_id=OLD.organization_id AND je.account_code=OLD.code) THEN
    RAISE EXCEPTION 'ACCOUNT_HAS_POSTINGS: cannot move % between statements', OLD.code;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER account_protect_system_trg BEFORE UPDATE ON account FOR EACH ROW EXECUTE FUNCTION account_protect_system();

-- สร้างผังบัญชีให้ org ใหม่จาก template
CREATE OR REPLACE FUNCTION seed_chart_of_accounts(p_org uuid) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE n integer;
BEGIN
  INSERT INTO account (organization_id, code, name_th, name_en, category, normal_balance, is_contra, fs_line_item, is_current,
                       tax_kind, tax_form, cit_deductible, template_code, ext_codes, is_system)
  SELECT p_org, t.code, t.name_th, t.name_en, 'asset', t.normal_balance, t.is_contra, t.fs_line_item, t.is_current,
         t.tax_kind, t.tax_form, t.cit_deductible, t.code, t.ext_codes,
         (t.tax_kind IS NOT NULL OR t.code IN ('111101','113101','212101','212104','115104','114102','410101','410201','410301','410302','330000','999999'))
  FROM account_template t
  ON CONFLICT (organization_id, code) DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT; RETURN n;
END $$;

CREATE TABLE sub_account (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  account_code text NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  FOREIGN KEY (organization_id, account_code) REFERENCES account(organization_id, code),
  UNIQUE (organization_id, account_code, code)
);

CREATE TABLE contact (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL CHECK (length(name) <= 256),
  type contact_type NOT NULL DEFAULT 'none',
  prefix_name_type prefix_name_type,
  prefix_name_other text,
  tax_number text,
  branch_code char(5),
  address text, sub_district text, district text, province text, country text DEFAULT 'Thailand', post_code char(5),
  callcenter_number text, fax_number text, email text, website text,
  contact_first_name text, contact_last_name text, contact_nick_name text,
  contact_position text, contact_phone_number text, contact_email text,
  purchase_account text, sell_account text,
  receivable_account text, payable_account text,   -- PEAK ขั้นสูง "ตั้งค่าการบันทึกบัญชี": AR/AP เฉพาะราย (default 113101/212101)
  bank_id integer, bank_account_no text, bank_account_name text, bank_branch text,
  party_kind text NOT NULL DEFAULT 'none' CHECK (party_kind IN ('none','customer','vendor','both')),  -- ประเภทผู้ติดต่อ (prefix รหัส)
  is_juristic boolean NOT NULL DEFAULT true,       -- นิติบุคคล / บุคคลธรรมดา → เลือก ภ.ง.ด.53 / ภ.ง.ด.3
  is_foreign boolean NOT NULL DEFAULT false,       -- เลขทะเบียนต่างประเทศ → ภ.ง.ด.54 / ภ.พ.36
  delivery_address text,
  credit_term_days integer,                        -- ตั้งค่าครบกำหนดชำระ (override document_type_default.due_days)
  credit_limit numeric(18,2),                      -- NULL = ไม่กำหนดวงเงิน
  default_wht_rate numeric(5,2),
  dbd_synced_at timestamptz,                       -- ค้นหา DBD auto-fill
  is_active boolean NOT NULL DEFAULT true,
  is_system boolean NOT NULL DEFAULT false,  -- DBD/RD/SSO/EWF/Payroll/PEAK/C00000
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code),
  FOREIGN KEY (organization_id, purchase_account) REFERENCES account(organization_id, code),
  FOREIGN KEY (organization_id, sell_account) REFERENCES account(organization_id, code),
  FOREIGN KEY (organization_id, receivable_account) REFERENCES account(organization_id, code),
  FOREIGN KEY (organization_id, payable_account) REFERENCES account(organization_id, code)
);
CREATE INDEX contact_tax_number_idx ON contact(organization_id, tax_number);
-- กลุ่มผู้ติดต่อ: มาตรฐาน (ลูกค้า, ลูกค้าประจำ, ผู้ขาย) + กำหนดเอง
CREATE TABLE contact_group (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  name text NOT NULL, is_system boolean NOT NULL DEFAULT false,
  UNIQUE (organization_id, name)
);
CREATE TABLE contact_group_member (
  group_id uuid REFERENCES contact_group(id) ON DELETE CASCADE,
  contact_id uuid REFERENCES contact(id) ON DELETE CASCADE,
  PRIMARY KEY (group_id, contact_id)
);
-- บุคคลที่ติดต่อได้ (หลายคนต่อผู้ติดต่อ)
CREATE TABLE contact_person (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES contact(id) ON DELETE CASCADE,
  first_name text, last_name text, nick_name text, position text, phone text, email text,
  is_primary boolean NOT NULL DEFAULT false
);
CREATE INDEX contact_name_trgm_idx ON contact USING gin (name gin_trgm_ops);

CREATE TABLE unit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL, name_th text NOT NULL, name_en text,
  UNIQUE (organization_id, code)
);

CREATE TABLE item (   -- PEAK: product (type 1) + service (type 2) share one shape
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL,
  type item_type NOT NULL,
  name text NOT NULL,
  description text,
  sell_value numeric(18,4), sell_vat_type vat_type DEFAULT 'seven', sell_account text,
  purchase_value numeric(18,4), purchase_vat_type vat_type DEFAULT 'seven', purchase_account text,
  unit_id uuid REFERENCES unit(id),
  sku text,
  inventory_account text,          -- 114102 สินค้าสำเร็จรูป (product + track_inventory)
  cogs_account text,               -- 510101 ต้นทุนขาย
  track_inventory boolean NOT NULL DEFAULT false,   -- perpetual: ซื้อ→114102, ขาย→COGS/FIFO
  calc_cogs_on_sale boolean,       -- NULL = ตาม policy.cogs_on_sale_default
  carrying_balance_amount numeric(18,4), carrying_balance_value numeric(18,2), carrying_balance_date date,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (organization_id, code),
  FOREIGN KEY (organization_id, sell_account) REFERENCES account(organization_id, code),
  FOREIGN KEY (organization_id, purchase_account) REFERENCES account(organization_id, code),
  FOREIGN KEY (organization_id, inventory_account) REFERENCES account(organization_id, code),
  FOREIGN KEY (organization_id, cogs_account) REFERENCES account(organization_id, code),
  CHECK (NOT track_inventory OR type = 'product')
);
CREATE TABLE item_image (
  item_id uuid REFERENCES item(id) ON DELETE CASCADE, sort_order smallint NOT NULL, url text NOT NULL,
  PRIMARY KEY (item_id, sort_order), CHECK (sort_order BETWEEN 1 AND 5)
);
-- รายการจัดชุด (bundle) = หลายสินค้า/บริการ ราคารวม
CREATE TABLE item_bundle_component (
  bundle_item_id uuid REFERENCES item(id) ON DELETE CASCADE,
  component_item_id uuid REFERENCES item(id),
  quantity numeric(18,4) NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (bundle_item_id, component_item_id)
);
CREATE TABLE warehouse (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL, name text NOT NULL, description text,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (organization_id, code)
);

CREATE TABLE bank (                -- PEAK bankId lookup (global)
  id integer PRIMARY KEY, name_th text NOT NULL, name_en text, swift text
);

CREATE TABLE payment_method (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  type payment_method_type NOT NULL,
  bank_id integer REFERENCES bank(id),
  bank_name text,
  account_number text,
  account_type bank_account_type,
  ewallet_id integer,
  account_code text,               -- GL account (cash 111101, bank 1112xx/1113xx, ewallet custom)
  is_have_cheque boolean NOT NULL DEFAULT false,
  carrying_balance_value numeric(18,2),
  memo text,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (organization_id, code),
  FOREIGN KEY (organization_id, account_code) REFERENCES account(organization_id, code),
  CHECK (type <> 'bank_account' OR (bank_id IS NOT NULL AND account_number IS NOT NULL)),
  CHECK (type <> 'ewallet' OR account_code IS NOT NULL)
);

CREATE TABLE classification_group (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  number text NOT NULL, name text NOT NULL,
  UNIQUE (organization_id, number)
);
CREATE TABLE classification_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES classification_group(id) ON DELETE CASCADE,
  number text NOT NULL, name text NOT NULL,
  UNIQUE (group_id, number)
);

-- ============ DOCUMENTS ============
CREATE TABLE document (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  doc_type document_type NOT NULL,
  code text NOT NULL,
  contact_id uuid REFERENCES contact(id),
  issued_date date NOT NULL,
  due_date date CHECK (due_date IS NULL OR due_date >= issued_date),
  reference text CHECK (reference IS NULL OR length(reference) <= 32),
  remark text,
  status document_status NOT NULL DEFAULT 'draft',
  is_void boolean NOT NULL DEFAULT false,
  void_reason text,
  currency char(3) NOT NULL DEFAULT 'THB',
  exchange_rate numeric(18,6) NOT NULL DEFAULT 1,
  tax_status tax_status NOT NULL DEFAULT 'exclude_tax',
  is_tax_invoice boolean NOT NULL DEFAULT false,
  discount_total text,             -- "100" or "5%"
  pre_tax_amount numeric(18,2) NOT NULL DEFAULT 0,
  vat_amount numeric(18,2) NOT NULL DEFAULT 0,
  net_amount numeric(18,2) NOT NULL DEFAULT 0,
  wht_amount numeric(18,2) NOT NULL DEFAULT 0,
  paid_amount numeric(18,2) NOT NULL DEFAULT 0,
  remain_amount numeric(18,2) GENERATED ALWAYS AS (net_amount - wht_amount - paid_amount) STORED,
  -- credit note specifics
  reason_type credit_note_reason,
  reason_description text,
  goods_return boolean,
  -- link to source document (CN→INV/EXP, RT→INV, EXP→PO, IR→GR, INV→QO)
  source_document_id uuid REFERENCES document(id),
  -- PEAK-observed extras
  valid_until date,                -- QO/PO: Expired status
  accepted_at timestamptz,         -- QO: Accepted status
  vendor_doc_status text CHECK (vendor_doc_status IN ('await_tax_invoice','got_tax_invoice','await_receipt','got_receipt')),
  voided_at timestamptz,
  -- e-Tax
  etax_status etax_status NOT NULL DEFAULT 'none',
  etax_submitted_at timestamptz,
  etax_ref text,
  -- PEAK UI extras
  price_type price_type NOT NULL DEFAULT 'exclude_tax',
  is_locked boolean NOT NULL DEFAULT false, locked_by uuid REFERENCES app_user(id), locked_at timestamptz,  -- "ล็อกเอกสาร"
  public_token uuid NOT NULL DEFAULT gen_random_uuid(),        -- ลิงก์สาธารณะ
  public_password_hash text,
  warehouse_id uuid REFERENCES warehouse(id),
  warehouse_to_id uuid REFERENCES warehouse(id),               -- stock_transfer ปลายทาง
  cost_allocation cost_allocation_method,                      -- cost_adjustment: เฉลี่ยตามมูลค่า/จำนวน
  requisition_reason text,                                     -- PRR / transfer: สาเหตุ
  adjust_expense_account text,                                 -- PRR: "ค่าใช้จ่ายที่ต้องการปรับปรุง" ตามมูลค่าต้นทุน
  tax_invoice_number text,                                     -- EXP/PA: เลขที่ใบกำกับภาษีของผู้ขาย (35)
  recurring_template_id uuid,                                  -- "เอกสารอัตโนมัติ"
  created_by uuid REFERENCES app_user(id),
  approved_by uuid REFERENCES app_user(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, doc_type, code),
  UNIQUE (public_token)
);
CREATE INDEX document_org_type_date_idx ON document(organization_id, doc_type, issued_date DESC);
CREATE INDEX document_contact_idx ON document(contact_id);
CREATE INDEX document_status_idx ON document(organization_id, status) WHERE NOT is_void;

CREATE TABLE document_line (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  line_no smallint NOT NULL,
  item_id uuid REFERENCES item(id),
  account_code text,
  sub_account_id uuid REFERENCES sub_account(id),
  description text,
  is_description_only boolean NOT NULL DEFAULT false,
  quantity numeric(18,4) NOT NULL DEFAULT 1,
  price numeric(18,4) NOT NULL DEFAULT 0,
  discount text,
  vat_type vat_type NOT NULL DEFAULT 'seven',
  wht_rate numeric(5,2),           -- PEAK ต่อบรรทัด: 0.75/1/1.5/2/3/5/10/15/กำหนดเอง (NULL = ยังไม่ระบุ)
  wht_amount numeric(18,2) NOT NULL DEFAULT 0,
  asset_group_id uuid,             -- PA/POA: กลุ่มสินทรัพย์
  unit_cost numeric(18,4),         -- inventory docs: ต้นทุน/หน่วยที่ใช้ (FIFO)
  line_pre_tax numeric(18,2) NOT NULL DEFAULT 0,
  line_vat numeric(18,2) NOT NULL DEFAULT 0,
  line_total numeric(18,2) NOT NULL DEFAULT 0,
  UNIQUE (document_id, line_no),
  CHECK (is_description_only OR item_id IS NOT NULL OR account_code IS NOT NULL),
  CHECK (NOT (item_id IS NOT NULL AND account_code IS NOT NULL))   -- XOR productCode / accountCode
);

-- Billing note / combine-payment: bundle of approved invoices or expenses
CREATE TABLE document_bundle_item (
  bundle_document_id uuid NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  target_document_id uuid NOT NULL REFERENCES document(id),
  amount numeric(18,2) NOT NULL,
  PRIMARY KEY (bundle_document_id, target_document_id)
);

CREATE TABLE payment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  direction text NOT NULL CHECK (direction IN ('in','out','return')),  -- return = credit-note refund
  payment_group_id smallint NOT NULL DEFAULT 1,     -- PEAK paymentGroupId: 1 งวด = 1 journal; void ได้ทีละงวด
  wht_form text CHECK (wht_form IN ('PND1','PND2','PND3','PND53','PND54')),  -- PEAK เลือกจาก contact.type เอง (บุคคล→PND1!) เราให้ระบุได้
  payment_method_id uuid REFERENCES payment_method(id),
  account_code text,
  sub_account_id uuid REFERENCES sub_account(id),
  payment_date date NOT NULL,
  amount numeric(18,2) NOT NULL,
  wht_amount numeric(18,2) NOT NULL DEFAULT 0,
  note text,
  is_cheque boolean NOT NULL DEFAULT false,
  cheque_no text, cheque_date date, cheque_bank_id integer REFERENCES bank(id),
  cheque_branch_no text, cheque_account_no text, cheque_amount numeric(18,2),
  cheque_payment_method_id uuid REFERENCES payment_method(id),
  is_void boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- WHT certificate (50 ทวิ) derived from payment.wht_amount
CREATE TABLE wht_certificate (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  payment_id uuid NOT NULL REFERENCES payment(id),
  contact_id uuid NOT NULL REFERENCES contact(id),
  form_type text NOT NULL,        -- PND3 / PND53
  income_type text NOT NULL,      -- 40(2) 40(8) ...
  rate numeric(5,2) NOT NULL,
  base_amount numeric(18,2) NOT NULL,
  wht_amount numeric(18,2) NOT NULL,
  issued_date date NOT NULL,
  book_no text, running_no text,
  is_ewht boolean NOT NULL DEFAULT false,            -- e-Withholding Tax ผ่านธนาคาร
  remit_status wht_remit_status NOT NULL DEFAULT 'pending',   -- PEAK คอลัมน์ "การนำส่ง"
  remittance_id uuid,
  is_void boolean NOT NULL DEFAULT false
);
-- นำส่ง ภ.ง.ด. รายเดือน → Text file (รูปแบบ RD e-filing) + JV: Dr 2152xx Cr [Bank]
CREATE TABLE wht_remittance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  form_type text NOT NULL CHECK (form_type IN ('PND1','PND2','PND3','PND53','PND54')),
  period_month date NOT NULL,
  total_base numeric(18,2) NOT NULL DEFAULT 0, total_wht numeric(18,2) NOT NULL DEFAULT 0,
  filed_at timestamptz, paid_at timestamptz, text_file_url text, journal_id uuid,
  UNIQUE (organization_id, form_type, period_month)
);
-- ภาษีถูกหัก ณ ที่จ่าย (ลูกค้าหักเรา) ที่ได้รับหนังสือรับรอง — สำหรับเครดิต ภ.ง.ด.50
CREATE TABLE wht_received (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  payment_id uuid REFERENCES payment(id),
  contact_id uuid NOT NULL REFERENCES contact(id),
  form_type text, rate numeric(5,2), base_amount numeric(18,2) NOT NULL, wht_amount numeric(18,2) NOT NULL,
  certificate_date date, certificate_no text, is_ewht boolean NOT NULL DEFAULT false,
  received_certificate boolean NOT NULL DEFAULT false
);

-- Purchase tax invoice received (ภาษีซื้อ) — one per expense/IR/DP
CREATE TABLE received_tax_invoice (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES document(id) ON DELETE CASCADE,   -- 1:N (PEAK รับ array ของใบกำกับต่อ 1 expense)
  contact_id uuid NOT NULL REFERENCES contact(id),
  tax_invoice_number text NOT NULL,
  tax_invoice_date date NOT NULL,
  journal_date date NOT NULL,
  period_date date NOT NULL,       -- 1st of VAT reporting month
  vat_amount numeric(18,2) NOT NULL,
  CHECK (period_date >= date_trunc('month', tax_invoice_date)
     AND period_date <= date_trunc('month', tax_invoice_date) + interval '6 months')
);
-- duplicate tax invoice no. per vendor only enforced on approve → partial unique via trigger
CREATE UNIQUE INDEX received_tax_invoice_vendor_no_idx ON received_tax_invoice(contact_id, tax_invoice_number);

CREATE TABLE document_tag (
  document_id uuid NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  tag text NOT NULL,
  PRIMARY KEY (document_id, tag)
);

CREATE TABLE transaction_classification (
  document_id uuid NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  classification_item_id uuid NOT NULL REFERENCES classification_item(id),
  percent numeric(5,2),
  PRIMARY KEY (document_id, classification_item_id)
);

-- ============ LEDGER ============
CREATE TABLE journal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL,              -- RV-/PV-/JV- ...; PEAK reuses code after void
  journal_type journal_type NOT NULL,
  issued_date date NOT NULL,
  description text NOT NULL,
  contact_id uuid REFERENCES contact(id),
  source_document_id uuid REFERENCES document(id),   -- null = manual
  status journal_status NOT NULL DEFAULT 'approved',
  is_void boolean NOT NULL DEFAULT false,
  reference text,
  created_by uuid REFERENCES app_user(id), approved_by uuid REFERENCES app_user(id), approved_at timestamptz,
  flag_reason text,                -- status = flagged ("ควรพิจารณา"): เหตุผลจาก rule/AI
  total_debit numeric(18,2) NOT NULL,
  total_credit numeric(18,2) NOT NULL CHECK (total_credit = total_debit),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX journal_org_date_idx ON journal(organization_id, issued_date);

CREATE TABLE journal_entry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_id uuid NOT NULL REFERENCES journal(id) ON DELETE CASCADE,
  line_no smallint NOT NULL,
  account_code text NOT NULL,
  sub_account_id uuid REFERENCES sub_account(id),
  description text,
  debit numeric(18,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
  credit numeric(18,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
  CHECK ((debit > 0) <> (credit > 0)),               -- one side only
  UNIQUE (journal_id, line_no)
);
CREATE INDEX journal_entry_account_idx ON journal_entry(account_code);


-- ============ INVENTORY (perpetual, FIFO) ============
-- ชั้นต้นทุน: 1 แถวต่อการรับเข้า (ซื้อ/ยอดยกมา/ส่งคืนเบิก/โอนเข้า); ขาย/เบิก/โอนออก ตัดจากชั้นเก่าสุด
CREATE TABLE stock_layer (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES item(id),
  warehouse_id uuid REFERENCES warehouse(id),
  source_line_id uuid REFERENCES document_line(id),
  received_date date NOT NULL,
  quantity_in numeric(18,4) NOT NULL CHECK (quantity_in > 0),
  quantity_remaining numeric(18,4) NOT NULL CHECK (quantity_remaining >= 0),
  unit_cost numeric(18,6) NOT NULL CHECK (unit_cost >= 0),
  CHECK (quantity_remaining <= quantity_in)
);
CREATE INDEX stock_layer_fifo_idx ON stock_layer(organization_id, item_id, warehouse_id, received_date, id) WHERE quantity_remaining > 0;
-- การเคลื่อนไหว (ทุกเอกสารที่กระทบสต๊อก) — ยอดคงเหลือ = SUM(quantity) ต่อ item/warehouse
CREATE TABLE stock_movement (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES item(id),
  warehouse_id uuid REFERENCES warehouse(id),
  document_id uuid REFERENCES document(id),
  document_line_id uuid REFERENCES document_line(id),
  layer_id uuid REFERENCES stock_layer(id),
  movement_date date NOT NULL,
  quantity numeric(18,4) NOT NULL CHECK (quantity <> 0),      -- + รับเข้า / - จ่ายออก
  unit_cost numeric(18,6) NOT NULL,
  reason text CHECK (reason IN ('purchase','sale','sale_return','purchase_return','requisition','requisition_return','transfer_out','transfer_in','opening','cost_adjustment','count_adjustment'))
);
CREATE INDEX stock_movement_item_idx ON stock_movement(organization_id, item_id, warehouse_id, movement_date);
-- ใบปรับต้นทุน: ค่าใช้จ่าย (EXP อ้างอิง หรือไม่อ้างอิง) ปันเข้าชั้นต้นทุนของสินค้าที่รับจากเอกสารซื้อ
CREATE TABLE cost_adjustment_source (
  document_id uuid REFERENCES document(id) ON DELETE CASCADE,   -- ใบปรับต้นทุน
  expense_document_id uuid REFERENCES document(id),            -- EXP ที่นำมาปัน (NULL = ไม่อ้างอิง → account_code)
  account_code text, amount numeric(18,2) NOT NULL CHECK (amount > 0),
  PRIMARY KEY (document_id, expense_document_id, account_code)
);

-- ============ FIXED ASSETS (PEAK Asset: กลุ่มสินทรัพย์ + ค่าเสื่อม JV อัตโนมัติ) ============
CREATE TABLE asset_group (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  code text NOT NULL, name text NOT NULL,
  asset_account text NOT NULL,                 -- 1241xx ที่ดิน อาคาร อุปกรณ์ / 1251xx ไม่มีตัวตน
  accumulated_depreciation_account text,       -- 1242xx / 1252xx
  depreciation_expense_account text,           -- 530xxx ค่าเสื่อมราคา
  method depreciation_method NOT NULL DEFAULT 'straight_line',
  useful_life_months integer CHECK (useful_life_months IS NULL OR useful_life_months > 0),
  residual_rate numeric(5,2) NOT NULL DEFAULT 0,   -- % มูลค่าซาก (ปกติ 1 บาทต่อหน่วยตามสรรพากร → ใช้ residual_value รายตัว)
  UNIQUE (organization_id, code),
  FOREIGN KEY (organization_id, asset_account) REFERENCES account(organization_id, code),
  FOREIGN KEY (organization_id, accumulated_depreciation_account) REFERENCES account(organization_id, code),
  FOREIGN KEY (organization_id, depreciation_expense_account) REFERENCES account(organization_id, code),
  CHECK (method = 'none' OR (accumulated_depreciation_account IS NOT NULL AND depreciation_expense_account IS NOT NULL AND useful_life_months IS NOT NULL))
);
ALTER TABLE document_line ADD FOREIGN KEY (asset_group_id) REFERENCES asset_group(id);
CREATE TABLE fixed_asset (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  asset_group_id uuid NOT NULL REFERENCES asset_group(id),
  code text NOT NULL, name text NOT NULL,
  source_line_id uuid REFERENCES document_line(id),   -- จาก PA (บันทึกซื้อสินทรัพย์) รวม "ต้นทุนอื่น" ที่ capitalize
  acquired_date date NOT NULL, start_depreciation_date date NOT NULL,
  cost numeric(18,2) NOT NULL CHECK (cost >= 0),
  residual_value numeric(18,2) NOT NULL DEFAULT 1,
  useful_life_months integer NOT NULL CHECK (useful_life_months > 0),
  method depreciation_method NOT NULL DEFAULT 'straight_line',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','fully_depreciated','disposed','written_off')),
  disposed_date date, disposal_amount numeric(18,2),
  UNIQUE (organization_id, code)
);
-- ตารางค่าเสื่อมรายเดือน → JV ทั่วไป (Dr 530xxx / Cr 1242xx) สถานะตาม policy.depreciation_journal_default_status
CREATE TABLE depreciation_entry (
  fixed_asset_id uuid REFERENCES fixed_asset(id) ON DELETE CASCADE,
  period_month date NOT NULL,
  amount numeric(18,2) NOT NULL CHECK (amount >= 0),
  accumulated numeric(18,2) NOT NULL,
  journal_id uuid REFERENCES journal(id),
  PRIMARY KEY (fixed_asset_id, period_month)
);

-- ============ DOCUMENT UX (PEAK: template, recurring, lock, attachments, comments, history) ============
CREATE TABLE document_template (          -- "รายการโปรด" ต่อชนิดเอกสาร
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  doc_type document_type NOT NULL, name text NOT NULL,
  payload jsonb NOT NULL,                 -- header + lines (DocumentInput)
  created_by uuid REFERENCES app_user(id)
);
CREATE TABLE recurring_document (         -- "เอกสารอัตโนมัติ"
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  doc_type document_type NOT NULL, name text NOT NULL,
  payload jsonb NOT NULL,
  frequency text NOT NULL CHECK (frequency IN ('weekly','monthly','quarterly','yearly')),
  day_of_period smallint, start_date date NOT NULL, end_date date, next_run_date date,
  auto_approve boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true
);
ALTER TABLE document ADD FOREIGN KEY (recurring_template_id) REFERENCES recurring_document(id);
CREATE TABLE document_attachment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES document(id) ON DELETE CASCADE,
  journal_id uuid REFERENCES journal(id) ON DELETE CASCADE,
  file_name text NOT NULL, content_type text, size_bytes integer CHECK (size_bytes <= 26214400), storage_key text NOT NULL,
  uploaded_by uuid REFERENCES app_user(id), uploaded_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((document_id IS NOT NULL) <> (journal_id IS NOT NULL))
);
CREATE TABLE document_comment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  author_id uuid REFERENCES app_user(id), body text NOT NULL,
  mentions uuid[] NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE document_history (           -- "ข้อมูลประวัติ" (audit trail)
  id bigserial PRIMARY KEY,
  document_id uuid NOT NULL REFERENCES document(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES app_user(id), actor_kind text NOT NULL DEFAULT 'user' CHECK (actor_kind IN ('user','api','agent','system')),
  action text NOT NULL,                   -- create / edit / approve / void / lock / unlock / pay / void_payment / send_email / etax_submit ...
  diff jsonb, at timestamptz NOT NULL DEFAULT now()
);
-- คลังเอกสาร + กล่องขาเข้า (คู่ค้า / LINE / อีเมล / API)
CREATE TABLE file_vault (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  file_name text NOT NULL, content_type text, storage_key text NOT NULL,
  source text NOT NULL DEFAULT 'upload' CHECK (source IN ('upload','line','email','partner_connect','api','ocr')),
  sender_contact_id uuid REFERENCES contact(id),
  linked_document_id uuid REFERENCES document(id),     -- NULL = "ยังไม่ออกเอกสาร"
  ocr_payload jsonb,                                   -- ผล AI อ่านใบเสร็จ → prefill EXP
  uploaded_by uuid REFERENCES app_user(id), uploaded_at timestamptz NOT NULL DEFAULT now()
);

-- ============ VAT FILING (ภ.พ.30 / ภ.พ.36 รายเดือน) ============
CREATE TABLE vat_return (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id),
  form_type text NOT NULL CHECK (form_type IN ('PP30','PP36')),
  period_month date NOT NULL,
  output_base numeric(18,2) NOT NULL DEFAULT 0, output_vat numeric(18,2) NOT NULL DEFAULT 0,
  exempt_sales numeric(18,2) NOT NULL DEFAULT 0, zero_rated_sales numeric(18,2) NOT NULL DEFAULT 0,
  input_base numeric(18,2) NOT NULL DEFAULT 0, input_vat numeric(18,2) NOT NULL DEFAULT 0,
  credit_brought_forward numeric(18,2) NOT NULL DEFAULT 0,
  net_payable numeric(18,2) NOT NULL DEFAULT 0,        -- >0 ชำระ (215351) / <0 เครดิตยกไป (115451) หรือขอคืน (115452)
  carry_or_refund text CHECK (carry_or_refund IN ('carry','refund')),
  closing_journal_id uuid REFERENCES journal(id),
  filed_at timestamptz, paid_at timestamptz,
  UNIQUE (organization_id, form_type, period_month)
);

-- ============ INTEGRATION: API clients, webhooks, partner connections, usage ============
CREATE TABLE api_client (                 -- self-service API key / OAuth client / MCP key
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  name text NOT NULL,
  kind text NOT NULL DEFAULT 'api_key' CHECK (kind IN ('api_key','oauth_client','mcp')),
  key_hash text NOT NULL UNIQUE,          -- เก็บ hash เท่านั้น
  key_prefix text NOT NULL,               -- แสดง masked ****-15ea
  scopes text[] NOT NULL DEFAULT '{}',    -- permission strings เดียวกับ role_permission
  rate_limit_per_min integer NOT NULL DEFAULT 60,
  monthly_credit_limit integer,           -- NULL = ไม่จำกัด (PEAK: 100 / 1,000)
  created_by uuid REFERENCES app_user(id), created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz, revoked_at timestamptz
);
CREATE TABLE api_usage_log (              -- หน้า "การใช้งาน API" รายวัน/รายผู้ใช้
  id bigserial PRIMARY KEY,
  organization_id uuid NOT NULL, api_client_id uuid REFERENCES api_client(id),
  at timestamptz NOT NULL DEFAULT now(), method text, path text, status_code smallint, credits smallint NOT NULL DEFAULT 1,
  duration_ms integer
);
CREATE INDEX api_usage_log_org_day_idx ON api_usage_log(organization_id, at);
-- Webhook ขาออกของเรา (ครอบคลุม event ของ PEAK ทั้ง 9 ApiType + ของเราเพิ่ม)
CREATE TABLE webhook_endpoint (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  url text NOT NULL,
  secret text NOT NULL,                   -- HMAC-SHA256 → header X-Signature
  auth_header_name text, auth_header_value text,   -- custom auth header (เช่น x-api-key)
  event_types text[] NOT NULL,            -- 'invoice.created','invoice.paid_payment','expense.void_payment','contact.edited', ...
  environment text NOT NULL DEFAULT 'production' CHECK (environment IN ('uat','production')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE webhook_delivery (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  endpoint_id uuid NOT NULL REFERENCES webhook_endpoint(id) ON DELETE CASCADE,
  event_id uuid NOT NULL,                 -- X-Event-Id (idempotency ฝั่งรับ)
  event_type text NOT NULL,
  payload jsonb NOT NULL,
  attempts smallint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','delivered','failed','dead')),
  last_response_code smallint, last_error text,
  next_attempt_at timestamptz, delivered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX webhook_delivery_pending_idx ON webhook_delivery(next_attempt_at) WHERE status = 'pending';
-- การเชื่อมต่อผู้ให้บริการภายนอก (marketplace ของเรา: e-commerce, payment QR, bank feed, e-Tax, PEAK ขาเข้า, Omni channel)
CREATE TABLE integration_connection (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  provider text NOT NULL,                 -- shopee / lazada / tiktok / line_shopping / scb_qr / krungsri_statement / inet_etax / peak / line_oa / facebook ...
  category text NOT NULL CHECK (category IN ('ecommerce','oms','wms','crm','hr','payment','bank_feed','etax','accounting','messaging','ai')),
  display_name text, external_account_id text,
  credentials_ref text,                   -- key ใน secret store (ไม่เก็บ token ในตาราง)
  config jsonb NOT NULL DEFAULT '{}',     -- biller id, warehouse mapping, default accounts ...
  status text NOT NULL DEFAULT 'connected' CHECK (status IN ('pending','connected','error','disconnected')),
  connected_by uuid REFERENCES app_user(id), connected_at timestamptz NOT NULL DEFAULT now(),
  last_sync_at timestamptz, last_error text,
  UNIQUE (organization_id, provider, external_account_id)
);
-- Bank feed (Krungsri Statement API / นำเข้า statement) → กระทบยอดกับ payment
CREATE TABLE bank_statement_line (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  payment_method_id uuid NOT NULL REFERENCES payment_method(id),
  connection_id uuid REFERENCES integration_connection(id),
  txn_date date NOT NULL, amount numeric(18,2) NOT NULL, description text, external_ref text,
  matched_payment_id uuid REFERENCES payment(id),
  matched_journal_id uuid REFERENCES journal(id),
  reconciled_at timestamptz,
  UNIQUE (payment_method_id, external_ref)
);
-- ออเดอร์จากแพลตฟอร์ม (Shopee ฯลฯ) ก่อนแปลงเป็นเอกสาร (idempotency ด้วย external_order_id)
CREATE TABLE external_order (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id uuid NOT NULL REFERENCES integration_connection(id) ON DELETE CASCADE,
  external_order_id text NOT NULL,
  payload jsonb NOT NULL, order_status text, order_date timestamptz,
  document_id uuid REFERENCES document(id),
  imported_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (connection_id, external_order_id)
);
-- คำขอใบกำกับภาษีจากลูกค้า (ฟอร์ม/QR สาธารณะ)
CREATE TABLE tax_invoice_request (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  receipt_reference text, requester_name text NOT NULL, tax_number char(13), branch_code char(5), address text, email text, phone text,
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','issued','rejected')),
  document_id uuid REFERENCES document(id), created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ PERIOD LOCK ENFORCEMENT ============
CREATE OR REPLACE FUNCTION enforce_period_lock() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_lock date; v_date date;
BEGIN
  v_date := COALESCE(NEW.issued_date, OLD.issued_date);
  SELECT locked_before_date INTO v_lock FROM organization WHERE id = COALESCE(NEW.organization_id, OLD.organization_id);
  IF v_lock IS NOT NULL AND v_date < v_lock THEN
    RAISE EXCEPTION 'PERIOD_LOCKED: % is before lock date %', v_date, v_lock USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM accounting_period_lock l WHERE l.organization_id = COALESCE(NEW.organization_id, OLD.organization_id)
             AND l.period_month = date_trunc('month', v_date)::date) THEN
    RAISE EXCEPTION 'PERIOD_LOCKED: month % is locked', to_char(v_date,'YYYY-MM') USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER journal_period_lock_trg BEFORE INSERT OR UPDATE OF issued_date, is_void, status ON journal
  FOR EACH ROW EXECUTE FUNCTION enforce_period_lock();
CREATE TRIGGER document_period_lock_trg BEFORE INSERT OR UPDATE OF issued_date, is_void, status ON document
  FOR EACH ROW EXECUTE FUNCTION enforce_period_lock();

-- ============ REPORT VIEWS ============
CREATE VIEW v_ledger AS
SELECT j.organization_id, j.issued_date, j.code AS journal_number, je.account_code, je.sub_account_id,
       je.description, je.debit, je.credit
FROM journal j JOIN journal_entry je ON je.journal_id = j.id
WHERE NOT j.is_void AND j.status = 'approved';   -- งบ/รายงานนับเฉพาะ JV ที่อนุมัติแล้ว (PEAK: รออนุมัติยังไม่เข้างบ? — ต้องยืนยัน; ของเรานับเฉพาะ approved)

-- Trial balance for a month range: call with params in app layer
-- SELECT account_code,
--   SUM(debit) FILTER (WHERE issued_date <  :from) - SUM(credit) FILTER (WHERE issued_date < :from) AS opening,
--   SUM(debit) FILTER (WHERE issued_date BETWEEN :from AND :to) AS change_dr, ...

-- ============ FINANCIAL STATEMENT ROLL-UP ============
-- ยอดคงเหลือต่อบัญชี (signed ตาม normal balance: บวก = ตามด้านปกติ)
CREATE VIEW v_account_balance AS
SELECT a.organization_id, a.code, a.name_th, a.category, a.fs_line_item, a.normal_balance,
       COALESCE(SUM(CASE WHEN a.normal_balance='debit' THEN je.debit - je.credit ELSE je.credit - je.debit END),0) AS balance,
       MIN(j.issued_date) AS first_posting, MAX(j.issued_date) AS last_posting
FROM account a
LEFT JOIN journal_entry je ON je.account_code = a.code
LEFT JOIN journal j ON j.id = je.journal_id AND j.organization_id = a.organization_id AND NOT j.is_void AND j.status = 'approved'
GROUP BY a.organization_id, a.code, a.name_th, a.category, a.fs_line_item, a.normal_balance;

-- งบการเงินตามรายการย่อ DBD (ใช้กับ WHERE issued_date filter ใน application layer)
CREATE VIEW v_fs_rollup AS
SELECT b.organization_id, f.statement, f.section, f.sort_order, f.code AS fs_code, f.name_th, SUM(b.balance) AS amount
FROM v_account_balance b JOIN fs_line_item f ON f.code = b.fs_line_item
GROUP BY b.organization_id, f.statement, f.section, f.sort_order, f.code, f.name_th;

-- บัญชีภาษีคงค้าง (สำหรับ dashboard "ภาษีที่ต้องนำส่ง")
CREATE VIEW v_tax_positions AS
SELECT b.organization_id, a.tax_form, a.tax_kind, a.code, a.name_th, b.balance
FROM v_account_balance b JOIN account a ON a.organization_id=b.organization_id AND a.code=b.code
WHERE a.tax_kind IS NOT NULL;


-- ============ REPORT VIEWS (เพิ่มจาก PEAK "รวมรายงาน") ============
-- รายการค้างรับ/ค้างจ่าย (อายุลูกหนี้/เจ้าหนี้): ใช้ CURRENT_DATE หรือ as-of ใน app layer
CREATE VIEW v_open_items AS
SELECT d.organization_id, d.doc_type, d.id AS document_id, d.code, d.contact_id, d.issued_date, d.due_date,
       d.net_amount, d.wht_amount, d.paid_amount, d.remain_amount,
       CASE WHEN d.doc_type IN ('invoice','debit_note','deposit') THEN 'receivable' ELSE 'payable' END AS side,
       GREATEST(0, CURRENT_DATE - COALESCE(d.due_date, d.issued_date)) AS days_overdue,
       CASE WHEN CURRENT_DATE <= COALESCE(d.due_date, d.issued_date) THEN 'current'
            WHEN CURRENT_DATE - COALESCE(d.due_date, d.issued_date) <= 30 THEN '1-30'
            WHEN CURRENT_DATE - COALESCE(d.due_date, d.issued_date) <= 60 THEN '31-60'
            WHEN CURRENT_DATE - COALESCE(d.due_date, d.issued_date) <= 90 THEN '61-90'
            ELSE '>90' END AS bucket
FROM document d
WHERE NOT d.is_void AND d.status IN ('approved','outstanding','overdue','got_receipt','await_approval')
  AND d.doc_type IN ('invoice','debit_note','deposit','expense','asset_purchase','invoice_receipt','debit_note_expense','deposit_expense')
  AND d.remain_amount > 0;

-- สต๊อกคงเหลือต่อสินค้า/คลัง (perpetual)
CREATE VIEW v_stock_balance AS
SELECT organization_id, item_id, warehouse_id, SUM(quantity) AS quantity,
       SUM(quantity * unit_cost) AS value
FROM stock_movement GROUP BY organization_id, item_id, warehouse_id;

-- ภาษีหัก ณ ที่จ่ายรอนำส่ง (ต่อแบบ/เดือน) — ตรงกับ 215201-215205
CREATE VIEW v_wht_pending AS
SELECT organization_id, form_type, date_trunc('month', issued_date)::date AS period_month,
       COUNT(*) AS certificates, SUM(base_amount) AS base_amount, SUM(wht_amount) AS wht_amount
FROM wht_certificate WHERE NOT is_void AND remit_status = 'pending'
GROUP BY organization_id, form_type, date_trunc('month', issued_date);

-- รายงานภาษีซื้อรายเดือน (ตาม periodDate ที่เลือกยื่น ไม่ใช่วันที่ใบกำกับ)
CREATE VIEW v_vat_input_report AS
SELECT d.organization_id, r.period_date, r.tax_invoice_date, r.tax_invoice_number, c.name AS vendor_name, c.tax_number, c.branch_code,
       d.pre_tax_amount AS base_amount, r.vat_amount, d.code AS document_code
FROM received_tax_invoice r JOIN document d ON d.id = r.document_id JOIN contact c ON c.id = r.contact_id
WHERE NOT d.is_void;

-- รายงานภาษีขายรายเดือน (เอกสารที่เป็นใบกำกับภาษี ตาม policy.pp30_source_doc_types)
CREATE VIEW v_vat_output_report AS
SELECT d.organization_id, date_trunc('month', d.issued_date)::date AS period_month, d.issued_date, d.code AS tax_invoice_number,
       c.name AS customer_name, c.tax_number, c.branch_code, d.pre_tax_amount AS base_amount, d.vat_amount,
       CASE WHEN d.doc_type = 'credit_note' THEN -1 ELSE 1 END AS sign
FROM document d LEFT JOIN contact c ON c.id = d.contact_id
WHERE NOT d.is_void AND d.is_tax_invoice AND d.status <> 'draft';
