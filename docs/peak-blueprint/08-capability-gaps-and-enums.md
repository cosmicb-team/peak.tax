# 08 — ช่องว่างความสามารถ และ Enum มาตรฐาน

สรุปความสามารถด้านบัญชี/ภาษีที่ระบบต้องมี (ต้นแบบจากโปรแกรม PEAK), enum มาตรฐาน และกฎที่เพิ่มเข้า 04 (ศึกษาเมื่อ 9 พ.ย. 2569)

## 1. ความสามารถที่กระทบบัญชี/ภาษีซึ่งระบบเราต้องสร้าง

| # | ความสามารถ | ทำอะไร | ผลต่อบัญชี/ภาษี | เราต้องมี |
|---|---|---|---|---|
| 1 | รับชำระหลายงวด (ฝั่งขาย) | รับชำระใบแจ้งหนี้ **หลัง** สร้าง — หัก WHT เป็นจำนวนหรือเปอร์เซ็นต์ได้ | สร้าง journal รับ (RV) ต่อครั้ง → ติดตามยอดคงค้างและ WHT คงค้าง → **จ่ายบางส่วนได้หลายงวด** | `POST /documents/{type}/{code}/payments` (มีใน openapi.yaml แล้ว) |
| 2 | ยกเลิกการชำระทีละงวด | ยกเลิกการชำระ 1 งวด | reverse RV journal, เอกสารกลับเป็น WaitingPayment | `POST /payments/{id}:void` |
| 3 | ชำระ / ยกเลิกชำระ ฝั่งจ่าย | เหมือน 1-2 ฝั่งจ่าย (PV) | ต้องอยู่สถานะรอชำระ | เหมือนกัน |
| 4 | ชำระผ่านใบวางบิล / ใบรวมจ่าย | รับ/จ่ายชำระผ่านใบวางบิล/ใบรวมจ่าย | กระจายยอดเข้า invoice/expense ลูก | เหมือนกัน + allocation |
| 5 | บันทึกใบกำกับภาษีซื้อภายหลัง (หลายใบ) | ลงทะเบียนภาษีซื้อ **ภายหลัง** ได้หลายใบกำกับต่อ 1 expense | ย้าย 115402 → 115401; กำหนดเดือนยื่น ภ.พ.30 | `POST /documents/expenses/{code}/tax-invoices` — ตาราง `received_tax_invoice` ต้องเลิก UNIQUE(document_id) |
| 6 | ออกใบเสร็จจากเอกสารต้นทาง | ออกใบเสร็จจากเอกสารต้นทาง (ลิงก์อัตโนมัติ) | RT อ้าง IV → ลดลูกหนี้ ไม่ใช่รับรู้รายได้ซ้ำ | `POST /documents/receipts` รับ `sourceDocumentCode` (มีแล้ว) |
| 7 | แปลงเอกสาร QO→IV, PO→EXP | แปลงเอกสาร | reference chain QO→IV, PO→EXP | มีแล้วใน DocumentInput.sourceDocumentCode |
| 8 | ใบลดหนี้ไม่อ้างอิงเอกสารเดิม | ใบลดหนี้ **ไม่อ้างอิง** เอกสารเดิม | ลด VAT ขาย/ซื้อ ได้ แต่ต้องมีเหตุผลตาม ม.82/10 | รองรับ sourceDocumentCode = null + reasonType บังคับ |
| 9 | แก้ / อนุมัติ GR, IR | แก้/อนุมัติ GR, IR | GR approve → สต๊อก + GR/IR clearing; IR approve → เจ้าหนี้ + ภาษีซื้อ | มีใน generic `:approve` แล้ว |
| 10 | รายการเดินบัญชีธนาคาร | รายการเดินบัญชีธนาคาร (amount ±, date, remark) ต่อช่องทางการเงิน พร้อมสถานะกระทบยอด | **Bank reconciliation** — จับคู่ statement กับ payment/journal | ตาราง `bank_statement_line` + หน้า reconcile |
| 11 | โอนเงินระหว่างช่องทาง | โอนเงินระหว่างช่องทาง (เงินสด→ธนาคาร, ธนาคาร→ธนาคาร) รองรับ WHT และเช็ค | journal Dr [Bank ปลายทาง] / Cr [Bank ต้นทาง] | `POST /payment-methods/transfer` |
| 12 | ปรับยอดสต๊อก | ปรับยอดสต๊อกเป็นจำนวนคงเหลือเป้าหมาย | ต้นทุนสินค้าปรับ → 114102 / 540103 | phase 2 inventory |
| 13 | ส่ง e-Tax Invoice / e-Receipt | ส่ง e-Tax Invoice / e-Receipt ให้สรรพากร ผ่าน provider | หลังส่ง void ต้อง force; สถานะ "ส่ง e-Tax แล้ว" | `POST /documents/{type}/{code}:etax` + ตาราง `etax_submission` |
| 14 | ถอด classification | ถอด classification | ไม่กระทบยอด | DELETE classification |


## 2. Enum มาตรฐาน

### 2.1 สถานะ list filter
| เอกสาร | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Quotation / PO | All | Draft | AwaitApproval | Outstanding | Expired | Accepted | Approved | Voided | Success | | | |
| Invoice / Expense | All | Draft | AwaitApproval | WaitingPayment | Overdue | Paid | AwaitReceipt | GotReceipt | Voided | | | |
| Receipt | All | Draft | AwaitApproval | Approved | Voided | | | | | | | |
| Credit note / Billing note | All | Draft | AwaitApproval | WaitingPayment | OverDue | Paid | AwaitTaxInvoice | GotTaxInvoice | Voided | EtaxInvoiceIssued | AwaitReceipt | GotReceipt |


### 2.2 ReasonType ใบลดหนี้ (ล้อตาม ป.รัษฎากร ม.82/10)
| code | เหตุผล |
|---|---|
| 1 | ลดราคาสินค้า (ชำรุด/ขาด/ราคาผิด) |
| 2 | ลดราคาบริการ |
| 3 | รับคืนสินค้า |
| 4 | จ่ายค่าปรับ/ชดเชยตามสัญญา |
| 5 | คืนเงินจ่ายล่วงหน้า/ประกัน/มัดจำ/ค่าจอง |
| 6 | รับคืน/เปลี่ยนสินค้า (ระหว่างผู้จด VAT) |
| 7 | รับคืน/เปลี่ยนสินค้า (ผู้บริโภค ภายในกำหนด) |
| 8 | ยกเลิกบริการ |
| 9 | ลดราคาบริการ (ซ้ำกับ 2) |
| 10 | อื่นๆ |


### 2.3 TaxStatus มีแค่ `0 ExcludeTax`, `1 IncludeTax` — ไม่มี `2 NonTax` → ระบบเรา: กิจการไม่จด VAT ใช้ `taxStatus=0 + vatType=1 ทุกบรรทัด`

### 2.4 Enum อื่น
TransactionType 101-107, 201-207 (+121/221/222/223) · VatType 1 None, 2 0%, 3 7% · ContactType 1-11 · PrefixNameType 0-5 · PaymentMethod type 1 Cash, 2 Bank, **3 Expense claim**, 4 e-Wallet · AccountType 1-3 · JournalType 1-5 · CurrencyId 0 THB … 48 PKR (49 สกุล)

### 2.5 BankId (37 ธนาคาร)
0 Other · 1 BBL · 2 KBANK · 3 SCB · 4 SME · 5 KTB · 6 BAY · 7 KK · 8 CIMB · 9 TMB (ปัจจุบัน ttb) · 10 TISCO · 11 TCR · 12 TCAP · 13 BAAC · 14 EXIM · 15 UOB · 16 LHBANK · 17 SCBT · 18 GSB · 20 IBANK · 21 ICBC · 22 JPMORGAN · 23 CITIBANK · 24 SMBC · 25 DB · 26 BNP · 27 MIZUHO · 28 THAIPR · 29 BOC · 30 BOA · 31 RBS · 32 RHB · 33 IOB · 34 HSBC · 35 ANZ · 36 OCBC · 37 GHBANK (ไม่มี 19) → seed ตาราง `bank`

### 2.6 EWalletId
1 2C2P · 2 Omise · 3 TrueWallet · 4 LINE Pay/WePay · 5 PayPal · 6 PaySolutions · 7 Xendit · 8 Lazada Wallet · 9 Shopee Wallet · 10 JD Wallet

## 3. กฎบัญชี/ภาษีเพิ่มเติม (รวมไว้ใน 04 แล้ว)

1. **ชำระหลายงวด**: เอกสาร 1 ใบรับ payment ได้หลายครั้ง แต่ละครั้งสร้าง journal แยกเป็นกลุ่มการชำระ; void ได้ทีละกลุ่ม → ตาราง `payment` ต้องมี `payment_group_id` และ WHT ถูกหักได้ **ต่องวด**
2. **WHT เป็นเปอร์เซ็นต์ได้** → ระบบคำนวณจากฐานก่อน VAT ของยอดที่ชำระงวดนั้น
3. **ภาษีซื้อหลายใบกำกับต่อ 1 expense** → `received_tax_invoice` เป็น 1:N
4. **Statement = รายการเดินบัญชี** แยกจาก payment; reconcile = จับคู่ statement.amount/date กับ payment หรือ journal entry ของบัญชีธนาคารนั้น
5. **Transfer ระหว่างช่องทาง** มี WHT ได้ (กรณีโอนจ่ายที่ต้องหัก) และเช็ค (accountNo ≤12, branchNo ≤6, chequeNo ≤8)
6. **Lock by period** ตรวจจาก "วันที่เอกสาร" → ระบบเรา: `accounting_period_lock` ตรวจ issuedDate, paymentDate, taxInvoiceDate/journalDate ของ received tax invoice
7. **Expired / Accepted / Success** สถานะ QO/PO → ใบเสนอราคามีวันหมดอายุและสถานะลูกค้ายอมรับ → เพิ่ม `valid_until`, `accepted_at` ใน document
8. **AwaitTaxInvoice / GotTaxInvoice / AwaitReceipt / GotReceipt** → เอกสารฝั่งซื้อติดตาม "ได้รับใบกำกับภาษี/ใบเสร็จจาก vendor แล้วหรือยัง" แยกจากสถานะชำระ → เพิ่ม `vendor_doc_status`
9. **Approve ของ journal** มี `status: Draft | Approve` (default Approve) → journal มี draft ได้

## 4. สิ่งที่ยังต้องยืนยัน
| คำถาม | ผลที่ใช้ |
|---|---|
| ชำระหลายงวด + ยกเลิก 1 งวด | โครง payment_group |
| Dr/Cr ของ PR, GR, PA, PRR, ปรับต้นทุน | ยืนยัน 04 §2 ฝั่งซื้อ + บัญชี GR/IR clearing |
| ปัดเศษ VAT ระดับบรรทัด vs เอกสาร (ตรวจแล้วรอบ 2 ดู 09 §4) | กฎ rounding |
