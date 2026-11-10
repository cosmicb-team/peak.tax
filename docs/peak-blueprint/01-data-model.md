# 01 — Data Model

ที่มา: โครงสร้างเอกสารของ PEAK + ข้อมูลจากกิจการทดสอบ
สถานะหลักฐาน: **Observed** = เห็นจากระบบต้นแบบโดยตรง, **Inferred** = อนุมานจากพฤติกรรมที่เอกสารอธิบาย

## 1. ภาพรวม Entity

```mermaid
erDiagram
    ORGANIZATION ||--o{ CONTACT : has
    ORGANIZATION ||--o{ ACCOUNT : "chart of accounts"
    ORGANIZATION ||--o{ PAYMENT_METHOD : has
    ORGANIZATION ||--o{ PRODUCT : catalog
    ORGANIZATION ||--o{ CLASSIFICATION_GROUP : defines

    CONTACT ||--o{ DOCUMENT : "party of"
    DOCUMENT ||--|{ DOCUMENT_LINE : contains
    DOCUMENT ||--o{ PAYMENT : "paid by"
    DOCUMENT ||--o{ JOURNAL : posts
    DOCUMENT }o--o| DOCUMENT : "references (CN→INV, RT→INV, EXP→PO)"
    DOCUMENT ||--o{ DOCUMENT_TAG : tagged
    DOCUMENT ||--o{ TRANSACTION_CLASSIFICATION : classified
    DOCUMENT }o--o| RECEIVED_TAX_INVOICE : "ภาษีซื้อ"

    DOCUMENT_LINE }o--o| PRODUCT : "productCode"
    DOCUMENT_LINE }o--|| ACCOUNT : "accountCode"
    ACCOUNT ||--o{ SUB_ACCOUNT : "บัญชีย่อย"

    PAYMENT }o--|| PAYMENT_METHOD : via
    PAYMENT }o--o| CHEQUE : "isCheque"

    JOURNAL ||--|{ JOURNAL_ENTRY : lines
    JOURNAL_ENTRY }o--|| ACCOUNT : debit/credit
    JOURNAL_ENTRY }o--o| SUB_ACCOUNT : optional

    BILLING_NOTE ||--|{ BILLING_NOTE_TRANSACTION : "รวมเอกสาร"
    BILLING_NOTE_TRANSACTION }o--|| DOCUMENT : invoice/expense

    CLASSIFICATION_GROUP ||--|{ CLASSIFICATION_ITEM : has
    TRANSACTION_CLASSIFICATION }o--|| CLASSIFICATION_ITEM : "number + percent"
```

## 2. Master Data

### 2.1 Contact (ผู้ติดต่อ) — Observed
| Field | Type | หมายเหตุ |
|---|---|---|
| id | uuid | PK (PEAK gen) |
| code | string | unique ใน org เช่น `C00001`; เปลี่ยนไม่ได้ |
| name | string(256) | ไม่รวมคำนำหน้านิติบุคคล |
| type | int enum | 0 None, 1 หจก., 2 บจก., 3 บมจ., 4 ร้านค้า, 5 บุคคลธรรมดา, 6 คณะบุคคล, 7 อื่นๆ, 8 หสม., 9 มูลนิธิ, 10 สมาคม, 11 กิจการร่วมค้า |
| prefixNameType | int enum | ใช้เมื่อ type=5: 0 None, 1 คุณ, 2 นาย, 3 นาง, 4 นางสาว, 5 Other (+prefixNameOther) |
| taxNumber | string(13) | เลขผู้เสียภาษี; ไทยต้องผ่าน check digit |
| branchCode | string(5) | `00000` = สำนักงานใหญ่ |
| address, subDistrict, district, province, country, postCode | string | address = บ้านเลขที่/หมู่/ซอย/ถนน เท่านั้น |
| callcenterNumber, faxNumber, email, website | string | ระดับองค์กร |
| contactFirstName/LastName/NickName/Position/PhoneNumber/Email | string | บุคคลติดต่อ |
| purchaseAccount, sellAccount | account code | default GL สำหรับเอกสารซื้อ/ขาย |
| bankId, bankAccountNo, bankAccountName, bankBranch | — | บัญชีธนาคารของคู่ค้า |
| status | int | 1 Active, 2 Inactive |

Default contacts ที่ PEAK สร้างให้ทุกกิจการ: `DBD` กรมพัฒน์ฯ, `RD` กรมสรรพากร, `SSO` ประกันสังคม, `EWF` กองทุนสงเคราะห์ลูกจ้าง, `Payroll` เงินเดือนพนักงาน, `PEAK` ผู้ให้บริการ, และ `C00000` default contact สำหรับ journal

### 2.2 Account (ผังบัญชี) — Observed
| Field | Type |
|---|---|
| code | string(6) PK, รูปแบบ `XYYZZNN` |
| name | string (ไทย) |
| nameEn | string |
| category | derived จากหลักแรก: 1 สินทรัพย์, 2 หนี้สิน, 3 ทุน, 4 รายได้, 5 ค่าใช้จ่าย, 9 พัก |

ข้อจำกัด: General Ledger รองรับเฉพาะหมวด 1-5 และ 999999; หมวด 4-5 ไม่มียอดยกมา (beginningBalance = null)

### 2.3 Sub-account (บัญชีย่อย) — Inferred
ผูกกับ account; ใช้กับบัญชีธนาคาร/ลูกหนี้/เจ้าหนี้ ระบุได้ผ่าน `accountSubId` หรือ `accountSubCode` ในทุก line item และ journal entry

### 2.4 Payment Method (ช่องทางการเงิน) — Observed
| Field | Type | หมายเหตุ |
|---|---|---|
| id | uuid | |
| code | string | เช่น `CSH001`, `BSV003` |
| name | string | |
| type | int enum | 0 Others, 1 Cash, 2 BankAccount, 3 CreditCard, 4 eWallet |
| bankId | int | รหัสสถาบันการเงินของ PEAK (จำเป็นเมื่อ type=2) |
| bankName | string | ใช้เมื่อ bankId=0 |
| accountNumber | string | |
| accountType | int | 1 Current, 2 Savings, 3 FixedDeposit |
| eWalletId | int | type=4 |
| accountCode | account | GL ที่ผูก (type=4 required) |
| isHaveCheque | 0/1 | ออกเช็คได้ |
| carringBalanceValue | number | ยอดยกมา |

### 2.5 Product / Service (สินค้า / บริการ) — Observed
PEAK แยก catalog เป็น 2 ตาราง แต่โครงสร้างเหมือนกัน (`type` 1 = Product, 2 = Service)
| Field | Type |
|---|---|
| id | uuid |
| code | string เช่น `P00001` |
| name, description | string |
| type | 1 สินค้า / 2 บริการ |
| sellValue, sellVatType, sellAccount | ฝั่งขาย |
| purchaseValue, purchaseVatType, purchaseAccount | ฝั่งซื้อ |
| unitId, unitCode, unitNameTh, unitNameEn | หน่วยนับ |
| carryingBalanceAmount, carryingBalanceValue | ยอดยกมา (จำนวน/มูลค่า) |

VAT type: 1 None, 2 ZeroPercent, 3 SevenPercent

### 2.6 Classification Group / Item — Observed (ว่างในกิจการนี้)
```
ClassificationGroup { number, name, classificationItemList: [{ number, name }] }
TransactionClassification { transactionId, transactionType, classificationGroupCode, items: [{ number, percent }] }
```

### 2.7 Tag — Observed
free text ต่อเอกสาร, additive, match ตรงตัวอักษร

## 3. Transactional Documents

### 3.1 Document type registry (transactionType) — Observed
| Code | Prefix (default) | ไทย | ฝั่ง |
|---|---|---|---|
| 101 | QO / QOU | ใบเสนอราคา Quotation | Sales |
| 102 | IV / IVS | ใบแจ้งหนี้ Invoice | Sales |
| 103 | RT / RTZ | ใบเสร็จรับเงิน Receipt | Sales |
| 104 | — | ใบกำกับภาษี Tax Invoice | Sales (flag บน 102/103) |
| 105 | CN / CNT | ใบลดหนี้ Credit Note | Sales |
| 106 | BN | ใบวางบิล Billing Note | Sales |
| 107 | — | ใบเพิ่มหนี้ Debit Note | Sales (ไม่มีใน API นี้) |
| 121 | DR- | ใบมัดจำรับ Deposit | Sales |
| 201 | PO | ใบสั่งซื้อ Purchase Order | Purchase |
| 202 | EXP | บันทึกค่าใช้จ่าย Expense | Purchase |
| 205 | CNX | ใบลดหนี้ซื้อ | Purchase |
| 206 | BNX / CPN | ใบรวมจ่าย | Purchase |
| 207 | — | ใบเพิ่มหนี้ซื้อ | Purchase (ไม่มีใน API) |
| 221 | DP- | ใบมัดจำจ่าย | Purchase |
| 222 | GR- | ใบรับสินค้า Goods Receipt | Purchase |
| 223 | IR- | บันทึกรับเอกสารแจ้งหนี้ Invoice Receipt | Purchase |

| — | TDN / DN | ใบส่งของชั่วคราว / ใบส่งของ | Sales (UI เท่านั้น) |
| — | PR | ใบขอซื้อ | Purchase (PREMIUM, UI) |
| — | POA / PA | ใบสั่งซื้อสินทรัพย์ / บันทึกซื้อสินทรัพย์ | Purchase (UI) |
| — | CPN | ใบรวมจ่าย (= 206) | Purchase |
| — | PRR / คืนเบิก / ปรับต้นทุน / โอนย้าย | เอกสารสินค้า | Inventory (UI) |
| — | DBN / DBNT, DBNX | ใบเพิ่มหนี้ขาย/ซื้อ | (= 107/207, UI มี) |

**เลขที่เอกสาร** ตั้งค่าได้ต่อ org ต่อชนิด ต่อชุด (main / tax_invoice / asset): prefix ≤4 + อักษรพิเศษ + ปี + เดือน + วัน + running 3-8 หลัก + reset; ชุดใบกำกับภาษีแยก (IVT/RT/DRT/CNT/DBNT); รูปแบบที่เห็น: `IVS202308020`, `DR-20260800007`, `GR-20261000001`, `QOU-230118000000000`, `IVT-20261100001` → `document_number_rule` + `document_sequence` + `document_number_used`

### 3.2 Document header (ร่วมทุกประเภท 101/102/103/105/201/202) — Observed
| Field | Type | หมายเหตุ |
|---|---|---|
| id | uuid | |
| code | string | เลขที่เอกสาร unique |
| transactionType | int | ดู registry |
| contactId / contactCode | FK | |
| issuedDate | yyyyMMdd | |
| dueDate | yyyyMMdd | ต้อง ≥ issuedDate |
| reference | string(32) | เลขอ้างอิงภายนอก |
| remark | text | |
| status | string / int | ดู state machine ใน 03 |
| isVoid | 0/1 | |
| currencyId, exchangeRate | | THB default; GR บันทึก rate=1 เสมอ |
| taxStatus | int | 0 ExcludeTax, 1 IncludeTax, 2 NonTax |
| isTaxInvoice | 0/1 | เอกสารนี้เป็นใบกำกับภาษี |
| discountTotal | string | จำนวนหรือ `%`; ใช้ได้เมื่อทุก line มี vatType เดียวกัน |
| preTaxAmount, vatAmount, netAmount | decimal | auto-calc ถ้า null |
| whtAmount | decimal | รวม WHT (read-only) |
| paymentAmount, remainAmount | decimal | |
| tags | string[] | |
| documentLink | url | หน้าเอกสารใน PEAK |

### 3.3 Document line (InvoiceProduct) — Observed
| Field | Type | หมายเหตุ |
|---|---|---|
| id | uuid | |
| productId / productCode | FK | XOR กับ accountCode |
| accountCode (+accountSubId/Code) | FK | Expense ใช้ account เสมอ |
| description | text | |
| isDescription | 0/1 | บรรทัดคำอธิบายล้วน (ไม่มีจำนวนเงิน) |
| quantity | decimal | |
| price | decimal | ต่อหน่วย |
| discount | string | จำนวนหรือ `%` |
| vatType | int | 1 None, 2 0%, 3 7% (default 3) |
| withHoldingTaxAmount | decimal string | WHT ของบรรทัดนี้ |

### 3.4 Payment (การชำระเงิน) — Observed
ฝังอยู่ในเอกสาร (`paidPayments[]`) ไม่มี endpoint แยก
| Field | หมายเหตุ |
|---|---|
| paymentMethodId / paymentMethodCode | FK |
| paymentAccountCode (+Sub) | GL override |
| paymentDate | default = issuedDate |
| paymentAmount | = netAmount − WHT |
| paidPaymentsWithHoldingTaxAmount | WHT ระดับการชำระ |
| paymentNote | |
| isCheque + cheque{No, Date, BankId, BranchNo, AccountNo, Amount, PaymentMethodId} | เมื่อจ่ายด้วยเช็ค |

Credit note มีชุดที่สอง `returnPayment*` สำหรับคืนเงิน

### 3.5 Credit Note เพิ่มเติม — Observed
`reasonType` 0 None, 1 PromotionAndMarketing, 2 OfficeUse, 3 ProductionUse, 4 ServiceUse, 5 Donation, 6 DamageOrLoss, 7 Others; `reasonDescription`, `goodsReturn` 0/1, `creditNoteStyleType` 0 General, อ้างอิง `transactionId/transactionCode` + `transactionType` ของต้นทาง

### 3.6 Billing Note — Observed
header ไม่มี line item แต่มี `transactions[]: { id, code, amount }` ชี้ไปยัง invoice/expense ที่ Approve แล้ว + ชุด payment/cheque

### 3.7 Deposit (DR/DP) — Observed
header เหมือน 3.2 + lines + payment; `remainAmount` = ยอดที่ยังไม่ถูก draw down; GL: DR → 212104 เงินมัดจำรับล่วงหน้า (หนี้สิน), DP → 115104 เงินมัดจำจ่ายล่วงหน้า (สินทรัพย์); journal: DR สร้าง RV-, DP สร้าง PV-

### 3.8 Goods Receipt / Invoice Receipt — Observed
GR: ไม่มี dueDate, ไม่มี tax invoice, ไม่มี payment; IR: มี dueDate (default +7 วัน), `receivedTaxInvoice`, ไม่มี payment ผ่าน API

### 3.9 Received Tax Invoice (ภาษีซื้อ) — Observed
```
{ taxInvoiceNumber, taxInvoiceDate, journalDate, periodDate? }
```
periodDate = เดือนที่ยื่น ภ.พ.30 ต้องอยู่ในเดือน taxInvoiceDate ถึง +6 เดือน; เลขซ้ำต่อ vendor ถูกปฏิเสธตอน Approve

## 4. Ledger

### 4.1 Journal (สมุดรายวัน) — Observed
| Field | หมายเหตุ |
|---|---|
| id, code | PEAK reuse code หลัง void → ใช้ id |
| issuedDate | |
| journalTypeId | 1 ซื้อ, 2 ขาย, 3 จ่าย, 4 รับ, 5 ทั่วไป |
| description | |
| contactId / contactCode | default C00000 |
| referenceNumber, referenceTransactionType | เอกสารต้นทาง (null = manual) |
| isVoid | 1 / null |
| totalDebit, totalCredit | ต้องเท่ากัน |
| journalEntries[] | { accountCode, accountSubId?, description, debit, credit } |

### 4.2 Reports — Observed
- **Trial Balance** (`fromMonth..toMonth` yyyyMM): ต่อบัญชี → beginningBalance / change / endingBalance แต่ละตัวมี debit+credit; summary รวม
- **General Ledger** (`accountCode`, `fromDate..toDate` ≤ 1 ปี): summary + transactions[] { date, journalNumber, description, debit, credit }
- ทั้งสองแชร์ rate limit 10 call/นาที/user, ห้าม concurrent, timeout 90 วินาที

## 4.3 Entity ที่เพิ่มจากหน้าเว็บ PEAK (10) — Observed UI, schema ใน db/schema.sql
| กลุ่ม | ตาราง | ที่มาใน PEAK |
|---|---|---|
| นโยบาย | `org_accounting_policy`, `document_type_default`, `document_number_rule`, `document_number_sequence/used` | ตั้งค่า 33 หน้า |
| สิทธิ์ | `org_role`, `role_permission` (permission string = Open API access rights), `org_member.role_id` | ผู้ใช้งาน / สิทธิ์การใช้งาน |
| ผู้ติดต่อ | `contact.receivable_account/payable_account/credit_term_days/credit_limit/is_juristic/is_foreign`, `contact_group(+member)`, `contact_person` | ฟอร์มผู้ติดต่อขั้นสูง |
| สินค้า | `item.type=bundle`, `item.inventory_account/cogs_account/track_inventory/sku`, `item_image`, `item_bundle_component`, `warehouse`, `stock_layer` (FIFO), `stock_movement`, `cost_adjustment_source` | สินค้า / คลัง / ใบเบิก-โอน-ปรับต้นทุน |
| สินทรัพย์ | `asset_group`, `fixed_asset`, `depreciation_entry` | PA + PEAK Asset |
| ภาษี | `wht_certificate.is_ewht/remit_status`, `wht_remittance`, `wht_received`, `vat_return`, `document.etax_status` | การเงิน › WHT, ภ.พ.30, e-Tax |
| สมุดรายวัน | `journal.status` (6 ขั้น), `journal_type='tax'` (JVTX), approver | บัญชีรายวัน |
| เอกสาร UX | `document.is_locked/public_token/public_password_hash/price_type/warehouse_id/tax_invoice_number`, `document_template`, `recurring_document`, `document_attachment`, `document_comment`, `document_history`, `file_vault` | หน้ารายละเอียด, รายการโปรด, เอกสารอัตโนมัติ, คลังเอกสาร |
| เชื่อมต่อ | `api_client`, `api_usage_log`, `webhook_endpoint`, `webhook_delivery`, `integration_connection`, `bank_statement_line`, `external_order`, `tax_invoice_request` | เชื่อมต่อแอปพลิเคชันภายนอก, PEAK MCP, Open API |
| ล็อก | `organization.locked_before_date` + trigger `enforce_period_lock` | ล็อกข้อมูลการใช้งาน |

## 5. Response envelope — Observed
```json
{ "Peak<Entity>s": { "<entity>s": [...], "total<Entity>": n, "resCode": "200", "resDesc": "Success" },
  "eventType": "Retrieve|Create|Edit|Approve|Void", "apiType": "Api<Entity>" }
```
resCode: 200 OK, 384 Transaction not found, 400 bad input, 429 rate limit, 500 generic business-rule failure, 600 role not permitted
