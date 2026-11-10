# 05 — ผังบัญชีมาตรฐาน PEAK (264 บัญชี)

ดึงจาก `GetAccountCodes` ของกิจการจำลอง 9 พ.ย. 2569 — ไฟล์ดิบ: `data/chart-of-accounts.csv` / `.json`

โครงสร้างรหัส 6 หลัก: `X YY ZZ NN` → X = หมวดใหญ่ (1-5, 9), YY = กลุ่ม, ZZ = หมวดย่อย, NN = ลำดับ


## หมวด 1 — สินทรัพย์ (Assets)

| รหัส | ชื่อบัญชี | English |
|---|---|---|
| 111101 | เงินสด | Cash |
| 111201 | ธนาคาร - บัญชีกระแสรายวัน | Current accounts |
| 111301 | ธนาคาร - บัญชีออมทรัพย์ | Saving accounts |
| 111401 | เช็ครับที่ครบกำหนดแต่ยังมิได้ฝาก | Uncashed cheques |
| 111501 | กระเป๋าเงินอิเล็กทรอนิกส์ | e-Wallet |
| 112101 | ธนาคาร - ฝากประจำ | Fixed deposites |
| 112201 | เงินลงทุนชั่วคราวอื่น | Other short-term investments |
| 113101 | ลูกหนี้การค้า | Accounts receivable |
| 113102 | เช็ครับลงวันที่ล่วงหน้า | Cheques received in advance |
| 113103 | ค่าเผื่อหนี้สงสัยจะสูญ | Allowances for doubtful accounts |
| 113201 | เงินให้กู้ยืม-บุคคลที่เกี่ยวข้องกัน | Short-term lendings to related parties |
| 113202 | เงินให้กู้ยืม-บุคคลอื่น | Short-term lendings to others |
| 113203 | เงินรับล่วงหน้าที่พนักงาน | Cash received at employee |
| 113301 | ลูกหนี้อื่น | Other receivables |
| 114101 | วัตถุดิบคงเหลือ | Raw materials |
| 114102 | สินค้าสำเร็จรูป | Finished goods |
| 114103 | งานระหว่างทำ | Work-in-process |
| 115101 | ค่าใช้จ่ายจ่ายล่วงหน้า - ค่าสินค้า | Advance payments - inventory |
| 115102 | ค่าใช้จ่ายจ่ายล่วงหน้า - ค่าเช่า | Prepaid expenses - rental |
| 115103 | ค่าใช้จ่ายจ่ายล่วงหน้า - อื่น | Prepaid expenses - others |
| 115104 | เงินจ่ายล่วงหน้า - เงินมัดจำ | Prepayment - Deposit |
| 115105 | เงินจ่ายล่วงหน้า - เงินประกัน | Prepayment - Retention |
| 115201 | เงินทดรองจ่ายพนักงาน | Advance payments to employee |
| 115301 | ดอกเบี้ยค้างรับ | Accrued interest income |
| 115302 | รายได้ค้างรับอื่น | Accrued revenue - others |
| 115401 | ภาษีซื้อ | Purchasing taxes |
| 115402 | ภาษีซื้อยังไม่ถึงกำหนด | Suspense purchasing taxes |
| 115403 | ภาษีถูกหัก ณ ที่จ่าย | Withheld taxes |
| 115404 | ภาษีเงินได้ครึ่งปี | Prepaid income taxes |
| 115405 | ลูกหนี้สรรพากร | Tax returns receivable |
| 115451 | เครดิต ภ.พ.30 ที่ชำระเกินรอนำไปใช้ | Excess PP30 VAT payment carry forward |
| 115452 | ลูกหนี้สรรพากร ภ.พ.30 รอรับคืนจากการขอคืน | PP30 VAT Receivable  |
| 121101 | เงินลงทุนเผื่อขาย | Long-term investments - avaiable for sale |
| 121102 | เงินลงทุนในบริษัทร่วม | Investments in associates |
| 121103 | เงินลงทุนในบริษัทย่อย | Investments in subsidiaries |
| 121104 | เงินลงทุนในการร่วมค้า | Investments in joint ventures |
| 121105 | เงินลงทุนระยะยาวอื่น | Long-term investments - others |
| 122101 | เงินให้กู้ยืมระยะยาวแก่บุคคลที่เกี่ยวข้องกัน | Long-term lendings to related parties |
| 122102 | เงินให้กู้ยืมระยะยาวแก่บุคคลอื่น | Long-term lendings to others |
| 123101 | อสังหาริมทรัพย์เพื่อการลงทุน | Investments - properties |
| 123201 | สินทรัพย์ไม่หมุนเวียนที่ถือไว้เพื่อขาย | Non-current assets held for sale and discontinued operations |
| 124101 | ที่ดิน | Lands |
| 124102 | งานระหว่างก่อสร้าง | Construction in progress |
| 124103 | อาคาร | Buildings |
| 124104 | ส่วนปรับปรุงอาคาร | Building improvements |
| 124105 | เครื่องจักร และอุปกรณ์ | Machineries |
| 124106 | อุปกรณ์สำนักงาน | Office equipments |
| 124107 | เครื่องตกแต่งสำนักงาน | Furnitures and fixtures |
| 124108 | ยานพาหนะ | Vehicles |
| 124203 | ค่าเสื่อมราคาสะสม - อาคาร | Accumulated depreciations - buildings |
| 124204 | ค่าเสื่อมราคาสะสม - ส่วนปรับปรุงอาคาร | Accumulated depreciation - building improvements |
| 124205 | ค่าเสื่อมราคาสะสม - เครื่องจักร | Accumulated depreciations - machineries |
| 124206 | ค่าเสื่อมราคาสะสม - อุปกรณ์สำนักงาน | Accumulated depreciations - equipments |
| 124207 | ค่าเสื่อมราคาสะสม - เครื่องตกแต่งสำนักงาน | Accumulated depreciations - furnitures and fixtures |
| 124208 | ค่าเสื่อมราคาสะสม - ยานพาหนะ | Accumulated depreciations - vehicles |
| 125101 | ซอฟต์แวร์ | Softwares |
| 125102 | สิทธิการเช่าหรือใช้ทรัพย์สิน | Leasehold rights |
| 125103 | สินทรัพย์ไม่มีตัวตนอื่น | Other intangible assets |
| 125201 | ค่าตัดจำหน่ายสะสม - ซอฟต์แวร์ | Accumulated amortization - softwares |
| 125202 | ค่าตัดจำหน่ายสะสม - สิทธิการเช่าหรือใช้ทรัพย์สิน | Accumulated amortization - leasehold rights |
| 125203 | ค่าตัดจำหน่ายสะสม - สินทรัพย์ไม่มีตัวตนอื่น | Accumulated amortization - other intangible assets |
| 126101 | สินทรัพย์ไม่หมุนเวียนอื่น | Other non-current assets |

## หมวด 2 — หนี้สิน (Liabilities)

| รหัส | ชื่อบัญชี | English |
|---|---|---|
| 211101 | เงินเบิกเกินบัญชีธนาคาร | Bank overdraft |
| 211201 | เงินกู้ยืมระยะสั้นธนาคารไม่มีหลักประกัน  | Short-term unsecured loans from bank |
| 211301 | เงินกู้ยืมระยะสั้นธนาคารมีหลักประกัน | Short-term secured loans from bank |
| 212101 | เจ้าหนี้การค้า | Accounts payable |
| 212102 | เช็คจ่าย | Cheques payable |
| 212103 | รายได้รับล่วงหน้า | Unearned Revenue |
| 212104 | เงินรับล่วงหน้า - เงินมัดจำ | Unearned - Deposit |
| 212105 | เงินรับล่วงหน้า - เงินประกัน | Unearned - Retention |
| 212201 | เงินกู้ยืมระยะสั้นจากบุคคลที่เกี่ยวข้องกัน | Short-term loans from related parties |
| 212202 | เงินกู้ยืมระยะสั้นจากบุคคลอื่น | Short-term loans from others |
| 212203 | สำรองจ่ายแทนกิจการที่ยังไม่ได้คืนเงิน | Await reimburse expenses |
| 212301 | เงินเดือนค้างจ่าย | Accrued salary |
| 212302 | กองทุนสำรองเลี้ยงชีพค้างจ่าย | Provident fund payable |
| 212303 | ค่าสอบบัญชีค้างจ่าย | Accrued audit fee |
| 212304 | ค่าทำบัญชีค้างจ่าย | Accrued accounting fee |
| 212305 | ค่าใช้จ่ายค้างจ่ายอื่น | Accrued expense - others |
| 212306 | เจ้าหนี้อื่น | Other payables |
| 212307 | เจ้าหนี้เช่าซื้อ | Leasing payables |
| 212401 | กองทุนสงเคราะห์ลูกจ้างค้างจ่าย | Employee welfare fund payable |
| 213101 | เงินกู้ยืมระยะยาวที่ถึงกำหนดชำระภายในหนึ่งปี | Current portion of long-term loans |
| 213102 | ส่วนของหนี้สินตามสัญญาเช่าเงินทุนที่ถึงกำหนดชำระภายในหนึ่งปี | Current portion of finance lease liabilities |
| 214101 | ประมาณการหนี้สินระยะสั้น | Estimated short-term liability |
| 215101 | ภาษีขาย ภ.พ.30 | Sales tax payable (PP30) |
| 215102 | ภาษีขายรอเรียกเก็บ | Suspense sales tax |
| 215103 | ภ.พ.36 ค้างจ่าย | PP36 payable |
| 215201 | ภ.ง.ด. 1 ค้างจ่าย | Withholding tax payable (PND1) |
| 215202 | ภ.ง.ด. 2 ค้างจ่าย | Withholding tax payable (PND2) |
| 215203 | ภ.ง.ด. 3 ค้างจ่าย | Withholding tax payable (PND3) |
| 215204 | ภ.ง.ด. 53 ค้างจ่าย | Withholding tax payable (PND53) |
| 215205 | ภ.ง.ด. 54 ค้างจ่าย | Withholding tax payable (PND54) |
| 215301 | ภาษีเงินได้นิติบุคคลค้างจ่าย | Income tax payable |
| 215302 | เจ้าหนี้สรรพากร | Payable to Revenue Department |
| 215351 | เจ้าหนี้สรรพากร ภ.พ.30 รอชำระ | PP30 VAT Payable |
| 215352 | เจ้าหนี้สรรพากร ภ.ง.ด. 1 รอชำระ | Filed PND1 Payable |
| 215353 | เจ้าหนี้สรรพากร ภ.ง.ด. 2 รอชำระ | Filed PND2 Payable |
| 215354 | เจ้าหนี้สรรพากร ภ.ง.ด. 3 รอชำระ | Filed PND3 Payable |
| 215355 | เจ้าหนี้สรรพากร ภ.ง.ด. 53 รอชำระ | Filed PND53 Payable |
| 215401 | ภ.ธ. 40 ค้างจ่าย | Special business tax payable (PT40) |
| 215501 | ประกันสังคมค้างจ่าย | Social security contribution payables |
| 216101 | ดอกเบี้ยค้างจ่าย | Accrued interest expenses |
| 216102 | หนี้สินหมุนเวียนอื่น | Other current liability |
| 221101 | เงินกู้ยืมระยะยาวจากธนาคาร | Long-term loan from bank |
| 221102 | เงินกู้ยืมระยะยาวจากบุคคลที่เกี่ยวข้องกัน | Long-term loan from related parties |
| 221103 | เงินกู้ยืมระยะยาวจากบุคคลอื่น | Long-term loan from others |
| 221104 | หนี้สินตามสัญญาเช่าเงินทุน | Finance lease liabilities |
| 222101 | ประมาณการหนี้สินผลประโยชน์พนักงาน | Provision for employee benefit |
| 222102 | ประมาณการหนี้สินระยะยาวอื่น | Other estimated long - term liability |
| 223101 | หนี้สินไม่หมุนเวียนอื่น | Other non - current liability |

## หมวด 3 — ส่วนของเจ้าของ (Equity)

| รหัส | ชื่อบัญชี | English |
|---|---|---|
| 311000 | หุ้นสามัญ | Ordinary shares |
| 312000 | ส่วนเกินมูลค่าหุ้นสามัญ | Share premium account - ordinary shares |
| 313000 | หุ้นบุริมสิทธิ | Preference shares |
| 314000 | ส่วนเกินมูลค่าหุ้นบุริมสิทธิ | Share premium account - preference shares |
| 321000 | สำรองตามกฎหมาย | Legal reserve  |
| 322000 | สำรองอื่น | Other reserve |
| 330000 | กำไร(ขาดทุน)สะสม | Retained earnings |
| 331000 | เงินปันผล | Dividends |
| 332000 | ผลกระทบของการเปลี่ยนแปลงนโยบายการบัญชี | Financial effects of changes in accounting policies |
| 333000 | ผลสะสมจากการแก้ไขข้อผิดพลาดทางการบัญชี | Financial effects of corrections of accounting errors |
| 341000 | ผลต่างของอัตราแลกเปลี่ยนจากการแปลงค่างบการเงิน | Exchange difference on translating financial statements |
| 342000 | ผลกำไร (ขาดทุน) จากการวัดมูลค่าเงินลงทุนเผื่อขาย | Gains (losses) on remeasuring available-for-sale investments |
| 343000 | ผลกำไร (ขาดทุน) ที่ยังไม่เกิดขึ้นจริงอื่น | Other unrealized gains (losses) |
| 344000 | องค์ประกอบอื่นของส่วนของผู้ถือหุ้น อื่นๆ | Other components of shareholders equity - Others |

## หมวด 4 — รายได้ (Revenue)

| รหัส | ชื่อบัญชี | English |
|---|---|---|
| 410101 | รายได้จากการขายสินค้า | Sales from product |
| 410201 | รายได้จากการให้บริการ | Sales from service |
| 410301 | รับคืน | Sales returns |
| 410302 | ส่วนลดจ่าย | Sales discounts |
| 410401 | รายได้ค่าก่อสร้าง | Contract revenue |
| 420101 | กำไรจากการจำหน่ายสินทรัพย์ | Gains on disposal of property |
| 420102 | กำไรจากอัตราแลกเปลี่ยนที่ยังไม่รับรู้ | Unrealized gain on foreign exchange rate |
| 420103 | กำไรจากอัตราแลกเปลี่ยน | Gains on foreign exchange |
| 420104 | ดอกเบี้ยรับ | Interest income |
| 420105 | เงินปันผลหรือส่วนแบ่งกำไร | Dividend income |
| 420106 | เงินชดเชยค่าภาษีอากร | Tax compensation |
| 420107 | เงินรางวัล หรือ เงินสนับสนุน  | Awards and grants |
| 420108 | รายได้อื่น | Other revenue |

## หมวด 5 — ค่าใช้จ่าย (Expenses)

| รหัส | ชื่อบัญชี | English |
|---|---|---|
| 510101 | ต้นทุนผลิตสินค้า | Production cost |
| 510102 | ค่าเสื่อมราคา - เครื่องจักร | Depreciation - machineries |
| 510103 | ต้นทุนขายสินค้า | Cost of goods sold |
| 510104 | ต้นทุนการให้บริการ | Cost of service provided |
| 510105 | ค่าลิขสิทธิ์ กู๊ดวิลล์ | Licenses and goodwills |
| 510106 | ค่าประกันภัยสินค้า | Insurance |
| 510107 | ค่าขนส่งสินค้า | Freight |
| 510108 | ค่าอากรขาเข้า | Import duty |
| 510109 | ค่าใช้จ่ายอื่นๆในการซื้อสินค้า | Other purchasing cost |
| 510201 | ต้นทุนการก่อสร้าง | Contract cost |
| 510301 | ส่วนลดรับ | Purchase Discount |
| 520101 | ค่านายหน้า ส่วนแบ่งการขาย | Sales commission |
| 520102 | โบนัสจากยอดขาย | Bonus on sales |
| 520201 | ค่าโฆษณา Google Adwords | Advertising expenses - Google Adwords |
| 520202 | ค่าโฆษณา Facebook Ads | Advertising expenses - Facebook Ads |
| 520203 | ค่าโฆษณาออนไลน์อื่น | Advertising expenses - other online advertisement |
| 520204 | ค่าโฆษณาวิทยุ | Advertising expenses - radio |
| 520205 | ค่าโฆษณาโทรทัศน์ | Advertising expenses - television |
| 520206 | ค่าโฆษณาสิ่งพิมพ์ | Advertising expenses - publishing |
| 520207 | ค่าโฆษณาสื่อนอกบ้าน | Advertising expenses - out of home media |
| 520208 | ค่าจ้างบริการเว็บไซต์ | Website development and maintenance cost |
| 520209 | ค่าจ้างทำ SEO | SEO service expenses |
| 520210 | ค่าจ้างผลิตสื่อโฆษณา | Advertising media production cost |
| 520211 | ค่าจ้างที่ปรึกษาการตลาด | Marketing consulting service expenses |
| 520212 | รางวัลในการประกวดแข่งขัน ชิงโชค | Prize or reward expenses |
| 520213 | ค่าส่งเสริมการขาย | Sales promotions |
| 520214 | ค่าสินค้าตัวอย่าง | Sample goods expenses |
| 520215 | ค่าใช้จ่ายเกี่ยวกับบูท | Space rental and event related expenses |
| 520216 | ค่าจ้างงานบุคคลงานอิเวนต์ | Event worker expenses |
| 520217 | ค่าจ้างนักแสดงสาธารณะ | Celebrity hiring expenses |
| 520218 | ค่าโฆษณาอื่นๆ | Other advertising expenses |
| 520301 | ค่าเดินทางในประเทศ | Transportation expenses - national |
| 520302 | ค่าเดินทางต่างประเทศ | Transportation expenses - international |
| 520303 | ค่าน้ำมัน | Gasoline expenses |
| 520304 | ค่าที่พัก | Accommodation expenses |
| 520305 | ค่าเบี้ยเลี้ยงเดินทาง | Travel allowance expenses |
| 520306 | ค่าโทรศัพท์ฝ่ายขาย | Sales communication expenses |
| 520307 | ค่ารับรอง | Entertainment and gift expenses |
| 520308 | หนี้สงสัยจะสูญ | Doubtful debts |
| 520309 | หนี้สูญ | Bad debts |
| 520401 | ค่าขนส่งสินค้าขาย | Freight on Sales |
| 530101 | เงินเดือน ค่าจ้าง | Wages and salary |
| 530102 | โบนัส | Bonus |
| 530103 | ค่าตอบแทนกรรมการ | Board of director compensation |
| 530104 | เงินสมทบประกันสังคม และกองทุนทดแทน | Social security contributions |
| 530105 | เงินสมทบกองทุนสำรองเลี้ยงชีพ | Provident fund contribution expense |
| 530106 | ค่ารักษาพยาบาล | Medical expenses |
| 530107 | ค่าอบรม สัมมนา | Seminar and training cost |
| 530108 | ค่าสวัสดิการอาหาร เครื่องดื่ม | Office welfare expenses - foods and drinks |
| 530109 | เงินช่วยเหลือยานพาหนะ | Car allowance |
| 530110 | ค่าประกันชีวิตกลุ่ม | Group life insurance expense |
| 530111 | ค่าประกันสุขภาพกลุ่ม | Group health insurance expense |
| 530112 | ค่าสวัสดิการอื่นๆ | Other welfare expenses |
| 530113 | เงินชดเชยการเลิกจ้าง | Severance pay |
| 530114 | ค่าใช้จ่ายในการจัดหาพนักงาน | Recruitment expenses |
| 530115 | ค่าจ้างเพื่อการวิจัยและพัฒนาเทคโนโลยี | R&D personel cost |
| 530201 | ค่าเช่าสำนักงาน | Office rental expenses |
| 530202 | ค่าส่วนกลางสำนักงาน | Common space expenses |
| 530203 | ค่าเช่ายานพาหนะ | Vehicles rental expenses |
| 530204 | ค่าเช่าอุปกรณ์ | Equipment rental expenses |
| 530205 | ค่าบริการสำนักงานเสมือน | Virtual office expenses |
| 530206 | ค่าเครื่องเขียน วัสดุ | Stationery and supplies expenses |
| 530207 | ค่าหนังสือ วารสาร | Books and magazines expenses |
| 530208 | ค่าสมาชิกสมาคมฯ | Association member expenses |
| 530209 | ค่ารักษาความปลอดภัย | Security expenses |
| 530210 | ค่ารักษาความสะอาด | Cleaning expenses |
| 530211 | ค่าซ่อมแซม | Repairing expenses |
| 530212 | ค่าไปรษณีย์ และขนส่ง | Postal, mailing, and carrier expenses  |
| 530301 | ค่าไฟฟ้า | Utility expenses - electricity |
| 530302 | ค่าประปา | Utility expenses - water supply |
| 530303 | ค่าโทรศัพท์สำนักงาน | Utility expenses - telephone |
| 530304 | ค่าอินเทอร์เน็ต | Utility expenses - internet |
| 530305 | ค่าบริการโฮสติ้ง และเว็บไซต์ | Utility expenses - hosting service |
| 530306 | ค่าบริการคลาวด์เซอร์วิซ | Utility expenses - cloud service |
| 530401 | ค่าบริการบัญชี | Professional service expenses - bookkeeping |
| 530402 | ค่าบริการสอบบัญชี | Professional service expenses - auditing fee |
| 530403 | ค่าบริการด้านกฎหมาย | Professional service expenses - legal fee |
| 530404 | บริการวิชาชีพอื่นๆ | Professional service expenses - others |
| 530405 | ค่าจ้างรับทำงานให้ | Service expenses |
| 530406 | ค่าจ้างรับเหมา | Contract work expenses |
| 530407 | ค่าจ้างทำของ | Hire of work expenses |
| 530408 | ค่าบริการอื่นๆ | Other service expenses |
| 530501 | ค่าธรรมเนียมธนาคาร | Bank fee |
| 530502 | ค่าธรรมเนียมราชการ | Government fee |
| 530503 | ค่าธรรมเนียมในการให้คำแนะนำและปรึกษา | Consulting fee |
| 530504 | ค่าธรรมเนียมอื่นๆ | Other fee |
| 530505 | ภาษีธุรกิจเฉพาะ | Special business tax |
| 530506 | ภาษีที่ดินและสิ่งปลูกสร้าง | Land and Building Tax |
| 530507 | ภาษีบำรุงท้องที่ | Local maintenance tax |
| 530508 | ภาษีป้าย | Signage tax |
| 530509 | อากรแสตมป์ | Stamp tax |
| 530601 | รายจ่ายเพื่อสนับสนุนการศึกษา | Donation for supporting education |
| 530602 | รายจ่ายเพื่อสนับสนุนการเรียนรู้และนันทนาการ | Donation for supporting learning and activitiy |
| 530603 | รายจ่ายในการจัดหาหนังสือหรือสื่ออิเล็กทรอนิกส์เพื่อสถานศึกษา | Donation for supporting book and digital media for education institutes |
| 530604 | รายจ่ายในการจัดให้คนพิการได้รับสิทธิประโยชน์ | Donation for supporting physical chanllenged people |
| 530605 | รายจ่ายเพื่อพัฒนาครู คณาจารย์ และบุคคลกรทางการศึกษา | Donation for educator development |
| 530606 | รายจ่ายในการตั้งศูนย์พัฒนาเด็กเล็กในสังกัด อปท | Donation for child development center |
| 530607 | รายจ่ายเพื่อโครงการฝึกอบรมอาชีพฯ | Donation for jobs development center |
| 530608 | รายจ่ายบริจาคให้แก่สถานศึกษา | Donation for educational organizations |
| 530609 | รายจ่ายบริจาคให้แก่องค์กรกีฬา | Donation for sport organizations |
| 530610 | รายจ่ายเพื่อการกุศลอื่นๆ | Donation for other charitable organization  |
| 530611 | รายจ่ายเพื่อการศึกษาหรือเพื่อการกีฬา | Donation for education and sport |
| 530703 | ค่าเสื่อมราคา - อาคาร | Depreciations - buildings |
| 530704 | ค่าเสื่อมราคา- ส่วนปรับปรุงอาคาร | Depreciation - building Improvements |
| 530706 | ค่าเสื่อมราคา - อุปกรณ์สำนักงาน | Depreciations - equipments |
| 530707 | ค่าเสื่อมราคา - เครื่องตกแต่งสำนักงาน | Depreciations - furnitures and fixtures |
| 530708 | ค่าเสื่อมราคา - ยานพาหนะ | Depreciations - vehicles |
| 530801 | ค่าตัดจำหน่าย - ซอฟต์แวร์ | Amortization - software |
| 530802 | ค่าตัดจำหน่าย - สิทธิการเช่าหรือใช้ทรัพย์สิน | Amortization - leasehold rights |
| 530803 | ค่าตัดจำหน่าย - สินทรัพย์ไม่มีตัวตนอื่น | Amortization - other intangible assets |
| 530901 | เงินสมทบกองทุนสงเคราะห์ลูกจ้าง | Employee welfare fund contribution |
| 530902 | ค่าเดินทางทั่วไป | General Travelling Expense |
| 540101 | ค่าใช้จ่ายอื่น | Other expenses |
| 540102 | ขาดทุนจากการจำหน่ายทรัพย์สิน | Losses on disposal of property |
| 540103 | ขาดทุนจากสินค้าสูญเสีย หรือสูญหาย | Losses from inventory adjustment |
| 540104 | ขาดทุนจากอัตราแลกเปลี่ยนที่ยังไม่รับรู้ | Unrealized loss on foreign exchange rate |
| 540105 | ขาดทุนจากอัตราแลกเปลี่ยน | Realized loss on foreign exchange rate |
| 540190 | ขาดทุน(กำไร)จากการปัดเศษ | Loss (gain) from round up |
| 540201 | ภาษีซื้อไม่ขอคืน | Unclaimable purchasing taxs |
| 540202 | ภาษีซื้อขอคืนไม่ได้ | Unclaimed purchasing taxes |
| 540203 | เครดิตภาษีไม่ขอคืน | Unclaimed tax return |
| 540204 | เบี้ยปรับเงินเพิ่ม | Tax fines and penalties |
| 580101 | ดอกเบี้ยจ่าย | Interest expenses |
| 580102 | ส่วนลดจากการขายเช็ค | Cheque discounts |
| 580201 | ค่าธรรมเนียมการกู้ยืม | Loan fees |
| 590000 | ภาษีเงินได้ | Income tax |

## หมวด 9 — บัญชีพัก (Suspense)

| รหัส | ชื่อบัญชี | English |
|---|---|---|
| 999999 | บัญชีพัก | Suspense Account |
