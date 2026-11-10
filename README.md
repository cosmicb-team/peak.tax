# ERP — Accounting & Tax Core

ต้นแบบ Accounting & Tax จากโปรแกรม PEAK ครอบคลุมตั้งแต่เปิดกิจการจนปิดปี เป็นระบบแยกอิสระ
ระบบอื่น เช่น Omnichannel, POS, HR อยู่นอก repo นี้ และเชื่อมผ่าน API Draft + Webhook เท่านั้น ดู [12-accounting-core-boundary.md](docs/peak-blueprint/12-accounting-core-boundary.md)

**สถานะ:** มีพิมพ์เขียวครบ (schema, API, เอกสาร) ยังไม่มีโค้ดแอปพลิเคชัน

## ขอบเขต
- ผังบัญชี 3 ชั้น, สมุดรายวัน, งบทดลอง, งบการเงินตามรูปแบบ DBD
- เอกสาร 25 ชนิด, เลขที่เอกสาร 24 ชุด, ใบกำกับภาษีแยกชุด
- VAT ภ.พ.30/36, WHT ภ.ง.ด.1/2/3/53/54 + 50 ทวิ, CIT ภ.ง.ด.50/51, ประกันสังคม
- e-Tax Invoice / e-Receipt
- สินค้าคงเหลือ FIFO, สินทรัพย์ถาวรและค่าเสื่อม
- รับ-จ่ายเงิน, กระทบยอดธนาคาร, ล็อกงวด, สิทธิ์ผู้ใช้

## โครงสร้าง
```
erp/
├── api/openapi.yaml          OpenAPI 3.1, 90 paths
├── db/
│   ├── schema.sql            PostgreSQL schema
│   ├── validate.mjs          ทดสอบ schema + trigger บน PGlite
│   └── seed/                 รายการย่องบ DBD, ผังบัญชี PEAK 264 บัญชี
└── docs/peak-blueprint/      พิมพ์เขียว 00–12 + data/ (csv/json)
```

## ทดสอบ schema
ไม่ต้องติดตั้ง Postgres ใช้ PGlite แทน

```bash
npm i @electric-sql/pglite@0.3.4
```

```bash
node db/validate.mjs
```

สร้างผังบัญชีให้กิจการใหม่:

```sql
SELECT seed_chart_of_accounts('<organization_id>');
```

## เอกสารที่ควรอ่านก่อน
1. [00-money-and-tax-flow.md](docs/peak-blueprint/00-money-and-tax-flow.md) เส้นเงินและจุดที่ภาษีเกาะ
2. [04-accounting-and-tax.md](docs/peak-blueprint/04-accounting-and-tax.md) Dr/Cr ทุกเอกสาร, VAT, WHT, ปิดงวด
3. [11-operating-workflows.md](docs/peak-blueprint/11-operating-workflows.md) flow การทำงานจริง
4. [06-architecture.md](docs/peak-blueprint/06-architecture.md) สถาปัตยกรรมและแผนส่งมอบ 10 โปรแกรม

สารบัญเต็มอยู่ที่ [docs/peak-blueprint/README.md](docs/peak-blueprint/README.md)

## กฎการเชื่อมต่อจากระบบภายนอก
1. ส่งได้แค่ข้อเท็จจริงทางธุรกิจ ห้ามส่งรหัสบัญชีหรือยอดภาษี core คำนวณเอง
2. สร้างได้แค่เอกสาร Draft การอนุมัติ, void, ชำระเงิน, ล็อกงวด ทำใน core เท่านั้น
3. ทุก POST ต้องมี `Idempotency-Key`
4. ห้ามอ่านหรือเขียน schema `acct` ตรง

## ขั้นถัดไป
เริ่มโปรแกรม #1 (Core + Master data) ตาม [06-architecture.md §6](docs/peak-blueprint/06-architecture.md)
