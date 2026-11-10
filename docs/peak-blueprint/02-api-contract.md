# 02 — API Contract

ชื่อ operation ตั้งตามเอกสารของ PEAK; envelope ตอบกลับดู 01 §5
รูปแบบนี้คือ **สิ่งที่ระบบเราต้องเลียนแบบ** (ให้ client/AI agent ใช้ได้เหมือนกัน) และ **ส่วนที่ควรทำดีกว่า** (หมายเหตุ ⚠️)

## 0. ข้อตกลงร่วม (Conventions)

| เรื่อง | PEAK | ข้อเสนอสำหรับระบบเรา |
|---|---|---|
| วันที่ | `yyyyMMdd` string, เดือน `yyyyMM` | รับทั้ง yyyyMMdd และ ISO-8601; ตอบ ISO |
| ตัวระบุเอกสาร | `id` (uuid) หรือ `code` (เลขที่) หรือ `reference` | เหมือนกัน; `code` เป็น human key |
| Pagination | `page` (10/หน้า) + `limit`; บาง endpoint ไม่ paginate (≤1000 แถว) | cursor-based + limit ≤100 ทุก list ⚠️ |
| Status filter vs response | **คนละ scale** (list filter 0-7 ≠ statusId ในผลลัพธ์ ≠ string ตอน create) | ใช้ enum string เดียวทุกที่ ⚠️ |
| Contact name ในผลลัพธ์ | ไม่มี — ต้อง join เอง | embed `contact { id, code, name }` ⚠️ |
| Create | ส่ง `status: "Draft"|"Approve"` ได้ทันที | เหมือนกัน + `Idempotency-Key` header ⚠️ |
| Edit | **replace ทั้งเอกสาร** (PUT semantics) เฉพาะ Draft | เหมือนกัน (PUT) + PATCH สำหรับ remark/tags/reference |
| Approve / Void | แยก action; void ถาวร | POST `/{id}:approve`, `/{id}:void` |
| Error | `resCode` string ใน body, HTTP มักเป็น 200 | HTTP status จริง + `code`, `message`, `details[]` ⚠️ |
| Rate limit | รายงาน 10 call/min/user, no concurrency | ระบุ `X-RateLimit-*` header |
| Auth | token ต่อ org | OAuth2 client-credentials ต่อ org + user JWT |

## 1. Endpoint map

### 1.1 Master data
| Operation | Method/Path (เสนอ) | Params หลัก | หมายเหตุ |
|---|---|---|---|
| SearchContacts | `GET /contacts` | searchText (name/tax id), groupId, status 0 All/1 Active/2 Inactive, page, limit | Tax ID match แม่นที่สุด |
| CreateContact | `POST /contacts` | name*, type*, taxNumber, branchCode, address…, purchaseAccount, sellAccount, bank* | เช็ค check digit เลขผู้เสียภาษี 13 หลัก |
| EditContact | `PATCH /contacts/{code}` | ส่งเฉพาะที่เปลี่ยน; ค่าว่าง = คงเดิม; code เปลี่ยนไม่ได้ | ไม่มี clear field ⚠️ ควรรองรับ `null` = clear |
| GetAccountCodes | `GET /accounts` | — | 264 แถว, call ครั้งเดียวแล้ว cache |
| GetSuggestionAccountCodeExpense | `GET /accounts/suggest?contactId|contactCode|taxId` | ต้องมีอย่างน้อย 1 | ตอบ `mostUsed[]` (ของเราเอง) + `suggestion[]` (crowd ตาม tax id) |
| GetPaymentMethod | `GET /payment-methods` `/payment-methods/{code}` | code, id, page, limit | type 1-4 |
| CreatePaymentMethod | `POST /payment-methods` | name*, type*, bankId, accountNumber, accountType, eWalletId, accountCode, isHaveCheque, carringBalanceValue | type=2 ต้อง bankId+accountNumber |
| ListProduct / ListService | `GET /items?type=product|service` | searchText, year, page, limit | PEAK แยก 2 endpoint |
| GetProduct / GetService | `GET /items/{code}` | code หรือ id | |
| CreateProduct / CreateService | `POST /items` | name*, type*, sell*/purchase*, unit*, carryingBalance* | |
| GetClassificationGroup | `GET /classification-groups` | — | |
| CreateTransactionClassification | `POST /documents/{id}/classifications` | classificationGroupCode*, items[{number, percent}]*, transactionType* | |
| GetTransactionClassification | `GET /documents/{id}/classifications` | | |
| InsertTag / RemoveTag | `POST|DELETE /documents/{id}/tags` | tags[] ; batch หลายเอกสาร; ผลต่อรายการ | additive |

### 1.2 Sales documents
| Operation | Path (เสนอ) | Params เฉพาะ | Status scale ที่ PEAK ใช้ |
|---|---|---|---|
| ListQuotation | `GET /quotations` | dateStart, dateEnd, status, searchText, page, limit | filter: 0 None,1 Voided,2 Draft,3 AwaitApproval,4 Outstanding,5 Overdue,6 PaidOrAwaitReceipt |
| GetQuotation | `GET /quotations/{code}` | id/code/reference | ตอบ Draft/Approve/Voided |
| CreateQuotation | `POST /quotations` | header + products[] + payment (optional) | |
| EditQuotation | `PUT /quotations/{code}` | ต้องส่ง contactId (contactCode ไม่พอ), products ครบ | |
| ApproveQuotation / VoidQuotation | `POST /quotations/{code}:approve|:void` | | void ไม่ได้ถ้าแปลงเป็น INV แล้ว |
| ListInvoice / GetInvoice / CreateInvoice / EditInvoice / ApproveInvoice / VoidInvoice | `/invoices` | เหมือน QO + `isTaxInvoice`, `taxStatus`, payment, WHT | Void: `isVoidETaxInvoice` |
| ListReceipt / GetReceipt / CreateReceipt / EditReceipt / ApproveReceipt / VoidReceipt | `/receipts` | payment แทบบังคับ | |
| ListBillingNote / GetBillingNote / CreateBillingNote / VoidBillingNote | `/billing-notes` | transactions[{id, code, amount}]*, issuedDate*, dueDate*, payment/cheque | ไม่มี Edit, ไม่มี Approve แยก |
| ListCreditNote / GetCreditNote / CreateCreditNote / VoidCreditNote | `/credit-notes` | transactionId/Code*, transactionType*, reasonType*, reasonDescription*, goodsReturn*, returnPayment* | ไม่มี Edit |
| ListDeposit / GetDeposit / CreateDeposit / VoidDeposit | `/deposits` | fromDate*, toDate* (≤1000 แถว, ไม่ paginate), contactCode, transactionNumber | list filter: 0 All,1 Draft,2 AwaitApproval,3 WaitingPayment,4 Overdue,5 Paid,6 AlreadyIssued,7 Voided ; Get ไม่คืน voided |

### 1.3 Purchase documents
| Operation | Path (เสนอ) | Params เฉพาะ | หมายเหตุ |
|---|---|---|---|
| ListPurchaseOrder / Get / Create / Edit / Approve / Void | `/purchase-orders` | เหมือน QO | Void ไม่ได้ถ้ามี EXP จาก PO |
| ListExpense / Get / Create / Edit / Approve / Void | `/expenses` | line ใช้ accountCode เสมอ; `receivedTaxInvoice{taxInvoiceNumber*, taxInvoiceDate*, journalDate*, periodDate}` ; `isTaxInvoice` | ดูกฎ VAT ใน 04 §3 |
| ListGoodsReceipt / GetGoodsReceipt / CreateGoodsReceipt / VoidGoodsReceipt | `/goods-receipts` | fromDate, toDate, page, limit(1-100) ; Get/Void ใช้ code เท่านั้น | create ได้แค่ Draft หรือ AwaitApproval; list status raw -2 Draft,-1 AwaitApproval,0 Approved,1 IssuedIR ; get status 0 None,1 Voided,2 Draft,3 AwaitApproval,4 Approved,5 IssuedInvoiceReceipt |
| ListInvoiceReceipt / Get / Create / Void | `/invoice-receipts` | dueDate default +7, receivedTaxInvoice | create: Draft หรือ Outstanding; list raw -2,-1,0,1 Outstanding/Overdue,2 Paid,3 GotReceipt ; get 0-8 |
| ListBillingNoteExpense / Get / Create / Void | `/billing-note-expenses` | transactions[] ของ expense | |
| ListCreditNoteExpense / Get / Create / Void | `/credit-note-expenses` | เหมือน CN | |
| ListDepositExpense / Get / Create / Void | `/deposit-expenses` | เหมือน DR | GL 115104 |

### 1.4 Ledger & reports
| Operation | Path (เสนอ) | Params | ข้อจำกัด PEAK |
|---|---|---|---|
| CreateDailyJournal | `POST /journals` | issuedDate*, journalTypeId* 1-5, description*, journalEntries[]*, contactId | balanced check |
| GetDailyJournal | `GET /journals/{code|id}` | | code ซ้ำได้หลัง void |
| VoidDailyJournal | `POST /journals/{id}:void` | | 384 = not found หรือ voided แล้ว |
| GetTrialBalance | `GET /reports/trial-balance?fromMonth&toMonth&isShowSubAccount` | yyyyMM | 10/min, no concurrency, 600 = role denied |
| GetGeneralLedger | `GET /reports/general-ledger?accountCode&fromDate&toDate&isShowSubAccount` | ≤ 1 ปี, หมวด 1-5 + 999999 | 90 s timeout; sub-account = query ต่อบัญชีย่อย |

## 2. Request body มาตรฐาน (Document)

```jsonc
{
  "code": null,                 // auto-generate
  "contactId": "uuid" | "contactCode": "C00001",
  "issuedDate": "20261109", "dueDate": "20261209",
  "reference": "PO-123", "remark": "...",
  "status": "Draft" | "Approve",
  "currencyId": null, "exchangeRate": null,
  "taxStatus": 0 | 1 | 2, "isTaxInvoice": 0 | 1,
  "discountTotal": "5%" | "100",
  "products": [
    { "productCode": "P00001" /* XOR */ "accountCode": "410101",
      "accountSubId": null, "description": "...", "isDescription": 0,
      "quantity": 2, "price": 1000, "discount": "0",
      "vatType": 3, "withHoldingTaxAmount": "60" }
  ],
  "preTaxAmount": null, "vatAmount": null, "netAmount": null,   // auto-calc
  // payment (optional, 1 รายการ)
  "paymentMethodCode": "BSV001", "paymentAccountCode": null,
  "paymentDate": "20261109", "paymentAmount": 2080, "paidPaymentsWithHoldingTaxAmount": "60",
  "paymentNote": "...", "isCheque": 0,
  // expense/IR/DP เท่านั้น
  "receivedTaxInvoice": { "taxInvoiceNumber": "TX001", "taxInvoiceDate": "20261105", "journalDate": "20261109", "periodDate": "20261101" },
  "tags": ["Q4-2026"]
}
```

## 3. Response body มาตรฐาน (Get/List)

```jsonc
{
  "PeakInvoices": {
    "invoices": [{
      "id": "uuid", "code": "IV202611001", "contactId": "uuid", "contactCode": "C00001",
      "issuedDate": "20261109", "dueDate": "20261209", "reference": "", "remark": "",
      "status": "Approve", "statusId": 4, "isVoid": 0, "isTaxInvoice": 1, "taxStatus": 0,
      "preTaxAmount": 2000, "vatAmount": 140, "netAmount": 2140, "whtAmount": 60,
      "paymentAmount": 2080, "remainAmount": 0,
      "products": [ /* line items */ ],
      "paidPayments": [ /* payments */ ],
      "journals": [{ "code": "RV-2026110001" }],
      "documentLink": "https://<host>/documents/..."
    }],
    "totalInvoice": 1, "resCode": "200", "resDesc": "Success"
  },
  "eventType": "Retrieve", "apiType": "ApiInvoice"
}
```

## 4. Error catalogue (จาก PEAK) → แปลงเป็น HTTP ของเรา

| PEAK resCode / message | ความหมาย | HTTP เรา |
|---|---|---|
| 200 | สำเร็จ | 200/201 |
| 384 Transaction not found | ไม่พบ หรือ void แล้ว | 404 |
| 400 | input ผิดรูปแบบ (date, range, missing) | 400 `VALIDATION_ERROR` |
| 429 | rate/concurrency limit | 429 + Retry-After |
| 500 (generic) | business rule: unknown contact/account/product, duplicate number, discount mix VAT, tax period out of range | 422 `BUSINESS_RULE` พร้อม detail ⚠️ |
| 600 | role ไม่มีสิทธิ์ดูรายงาน | 403 |
| "Should be paid full amount" | มี WHT แต่ paymentAmount ไม่ลด | 422 `WHT_PAYMENT_MISMATCH` |
| "Invoice net amount less than payment" | payment + WHT > net | 422 `OVERPAYMENT` |
| "Bank Account not found" | paymentMethodCode ผิด/เป็นเช็ค | 422 `PAYMENT_METHOD_INVALID` |
| "Locked period" | งวดถูกล็อก | 423 `PERIOD_LOCKED` |
| "Account was not found" | GL code ไม่มี | 422 `ACCOUNT_NOT_FOUND` |
| duplicate tax invoice | เลขใบกำกับซ้ำต่อ vendor | 409 `DUPLICATE_TAX_INVOICE` |
| void refused (referenced) | มีเอกสารอ้างอิง | 409 `DOCUMENT_REFERENCED` |
| void refused (e-Tax) | ส่งสรรพากรแล้ว | 409 `ETAX_SUBMITTED` ต้อง `force=true` |

## 5. Webhooks
**PEAK มี webhook** สำหรับ 9 ชนิดข้อมูล (Quotation, PurchaseOrder, Receipt, Invoice, Expense, Product, Service, Contact, PaymentMethod) แต่ไม่ได้ระบุ retry หรือ signature

**ของเรา (self-service + HMAC + retry)**: `document.created`, `document.approved`, `document.voided`, `payment.recorded`, `payment.voided`, `journal.posted`, `period.locked`, `contact.created/updated`, `item.created/updated`, `payment_method.created` — ครอบคลุม event มาตรฐานของระบบบัญชี; payload = document summary + `eventType` เดียวกับ envelope; header `X-Signature: sha256=HMAC(secret, body)`, `X-Event-Id` สำหรับ idempotency, retry 5 ครั้ง backoff 1m→1h, replay จากหน้า log
