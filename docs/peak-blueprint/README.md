# PEAK Blueprint — พิมพ์เขียว Accounting & Tax Core

ต้นแบบ Accounting & Tax จากโปรแกรม PEAK (ศึกษาเมื่อ 9 พ.ย. 2569)
ใช้เป็นฐานสร้าง core บัญชี-ภาษีของเราเอง; Omnichannel (บริการลูกค้า) แยกอยู่นอกขอบเขต ดู 12

## สารบัญ
| ไฟล์ | เนื้อหา |
|---|---|
| [00-money-and-tax-flow.md](00-money-and-tax-flow.md) | **อ่านก่อน**: โครงเส้นเงินขาย/ซื้อ และจุดที่ภาษีทุกตัวเกาะ, ตารางภาษีครบชุด, ปฏิทินยื่น, จุดพลาดบ่อย |
| [01-data-model.md](01-data-model.md) | Entity ทั้งหมด, field, enum, ERD (mermaid) |
| [02-api-contract.md](02-api-contract.md) | Endpoint map, request/response, status scales, error catalogue |
| [03-document-flows.md](03-document-flows.md) | วงจรขาย/ซื้อ, state machine ทุกเอกสาร, reference integrity |
| [04-accounting-and-tax.md](04-accounting-and-tax.md) | **หัวใจ**: Dr/Cr ทุกเอกสาร, VAT (ภ.พ.30/36), WHT (ภ.ง.ด.1/3/53, 50 ทวิ), ประกันสังคม, CIT, ปิดงวด, sub-ledger reconcile, gap list |
| [05-chart-of-accounts.md](05-chart-of-accounts.md) | ผังบัญชี 264 บัญชี (ไทย/อังกฤษ) — raw: `data/chart-of-accounts.{csv,json}` |
| [07-chart-of-accounts-mapping.md](07-chart-of-accounts-mapping.md) | ผังบัญชี 3 ชั้น (ล็อก/แก้ได้), mapping 264 บัญชี → รายการย่องบ DBD 38 รายการ + tax_kind 36 บัญชี, วิธี plug ระบบอื่น — seed: `db/seed/*.sql` |
| [08-capability-gaps-and-enums.md](08-capability-gaps-and-enums.md) | ความสามารถบัญชี/ภาษี 14 ข้อที่ต้องสร้าง, enum มาตรฐาน, กฎใหม่ (ชำระหลายงวด, ภาษีซื้อหลายใบ, statement), สิ่งที่ต้องยืนยัน |
| [09-peak-journal-verification.md](09-peak-journal-verification.md) | **ผลตรวจ journal จริงจาก PEAK**: 11 เอกสารทดสอบ, Dr/Cr ที่ PEAK ลงจริง, กฎที่ค้นพบ (WHT ตาม contact type, IR→212305, CN ลดรายได้ตรง, void แบบ soft), สิ่งที่ต้องทดสอบรอบ 2 หลังเปิด VAT |
| [10-peak-feature-inventory.md](10-peak-feature-inventory.md) | **Feature inventory ทั้งระบบจากหน้าเว็บ PEAK จริง**: sitemap 9 เมนู, 24 ชุดเลขที่เอกสาร, ฟอร์ม/รายละเอียดเอกสาร, 33 หน้าตั้งค่า, 40 รายงาน, แพ็กเกจ, **§8 การเชื่อมต่อ/Marketplace 33 แอป/e-Tax**, gap list 14 ข้อ |
| [11-operating-workflows.md](11-operating-workflows.md) | **Flow การทำงานจริง**: onboarding → ตั้งค่า 12 ขั้น → ยอดยกมา → ขาย 4 แบบ → ซื้อ 4 แบบ → สินค้า → การเงิน/กระทบยอด → ภาษีรายเดือน → ปิดเดือน/ปิดปี → API/Webhook/Marketplace/Agent; ระบุ role, หน้า, JV, สิ่งที่ระบบต้องบังคับ (14 ข้อ) |
| [12-accounting-core-boundary.md](12-accounting-core-boundary.md) | **ขอบเขต core บัญชี-ภาษี แยกอิสระ**: Omnichannel = บริการลูกค้า ไม่เกี่ยวภาษี; ระบบภายนอกทุกตัวเชื่อมผ่าน API Draft + Webhook เท่านั้น |
| [06-architecture.md](06-architecture.md) | Frontend / Backend / API / DB ของ core บัญชี-ภาษี / delivery plan 10 โปรแกรม |
| [../../db/schema.sql](../../db/schema.sql) | PostgreSQL schema พร้อมใช้ (master data, documents, payments, tax, ledger) + ส่วนเพิ่ม: policy, number rules, roles, inventory FIFO, fixed assets, WHT/VAT filing, webhooks/API clients, period-lock trigger (ผ่าน PGlite) |
| [../../api/openapi.yaml](../../api/openapi.yaml) | OpenAPI 3.1 skeleton — 90 paths: documents (25 ชนิด) + settings, inventory, assets, tax, integrations (API keys, webhooks self-service, marketplace, bank feed, inbound payment), reports 40 รายการ |

## สถานะหลักฐาน
- **Observed**: โครงสร้าง field, enum, status scale, error code, ผังบัญชี, default contacts — จากการทดสอบ
- **Observed (journal จริง)**: Dr/Cr ของ IV, IV+payment, RT, DR, CN, EXP, EXP+payment+WHT, IR, DP, BN — ดู 09
- **Observed รอบ 2 (VAT)**: ภาษีขาย 215101/215102, ภาษีซื้อ 115402 → JVTX → 115401, ปัดเศษระดับเอกสาร, ราคารวม VAT, CN มี VAT, ชุดเลขใบกำกับแยก — ดู 09 §4
- **Inferred (ยังไม่ได้ทดสอบ)**: GR approve, ชำระหลายงวด, void payment, ภ.พ.36, ปิด VAT รายเดือน
- **Observed (UI crawl)**: ทุกเมนู/ตั้งค่า/ฟอร์ม/รายงานของ PEAK v2.199.0 — ดู 10
- **Gap**: สิ่งที่ต้นแบบไม่มีแต่เราต้องสร้าง — ดู 04 §10 และ 10 §10

## ขั้นถัดไป
เริ่มโปรแกรม #1 (Core + Master data) ตาม 06 §6 — core บัญชี-ภาษีสร้างได้อิสระ ไม่ต้องรอระบบอื่น
