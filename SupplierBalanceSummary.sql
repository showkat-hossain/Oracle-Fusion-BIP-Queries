/*
Data Model: Supplier Summary Balance Report
Created By: Showkat Hossain
Creation Date: 05-JAN-2021
======================================================
Modification Log:
Modified By: 
Modification Date:
Modification Reason:
*/
  SELECT HP.PARTY_ID AS VENDOR_ID,
         HP.PARTY_NAME,
         (SELECT name
            FROM HR_ORGANIZATION_UNITS HOU
           WHERE HOU.ORGANIZATION_ID = :P_UNIT_NAME)
            UNIT,
         (SELECT PARTY_NAME
            FROM HZ_PARTIES
           WHERE PARTY_ID = :P_PARTY_ID)
            SUPPLIER,
         NVL (OP.OPENING_BALANCE, 0) AS OPENING_BALANCE,
         NVL (DEBIT_AMOUNT, 0) DEBIT_AMOUNT,
         NVL (CREDIT_AMOUNT, 0) CREDIT_AMOUNT,
         (  NVL (OP.OPENING_BALANCE, 0) + NVL (CREDIT_AMOUNT, 0) - NVL (DEBIT_AMOUNT, 0)) BALANCE,
         FND_GLOBAL.USER_NAME CREATED_BY
    FROM HZ_PARTIES HP
         LEFT OUTER JOIN
         (  SELECT PARTY_ID, SUM (NVL (CH.AMOUNT, 0)) DEBIT_AMOUNT
              FROM AP_CHECKS_ALL CH, IBY_PAYMENTS_ALL IPA
             WHERE    CH.PAYMENT_ID = IPA.PAYMENT_ID
                   AND IPA.PAYMENT_STATUS <> 'VOID'
                   AND CH.ORG_ID = NVL (:P_UNIT_NAME, CH.ORG_ID)
                   AND CH.CHECK_DATE BETWEEN NVL (:P_DATE_FROM, CH.CHECK_DATE)
                                         AND NVL (:P_DATE_TO, CH.CHECK_DATE)
          GROUP BY PARTY_ID) DR
            ON HP.PARTY_ID = DR.PARTY_ID
         LEFT OUTER JOIN
         (  SELECT VENDOR_ID,
                   PARTY_ID,
                   SUM (NVL (APA.INVOICE_AMOUNT, 0) * (NVL (EXCHANGE_RATE, 1)))
                      AS CREDIT_AMOUNT
              FROM AP_INVOICES_ALL APA
                   JOIN HR_ORGANIZATION_UNITS HOU
                      ON APA.ORG_ID = HOU.ORGANIZATION_ID
             WHERE     INVOICE_TYPE_LOOKUP_CODE = 'STANDARD'
                   AND APA.APPROVAL_STATUS <> 'CANCELLED'
                   AND APA.INVOICE_DATE BETWEEN NVL (:P_DATE_FROM,
                                                     APA.INVOICE_DATE)
                                            AND NVL (:P_DATE_TO,
                                                     APA.INVOICE_DATE)
                   AND APA.ORG_ID = NVL (:P_UNIT_NAME, APA.ORG_ID)
          GROUP BY PARTY_ID, VENDOR_ID) CR
            ON HP.PARTY_ID = CR.PARTY_ID
         LEFT OUTER JOIN
         (SELECT HP.PARTY_ID,
                 (NVL (T_INV_AMOUNT, 0) - NVL (T_PAY_AMOUNT, 0))
                    OPENING_BALANCE
            FROM HZ_PARTIES HP
                 LEFT OUTER JOIN
                 (  SELECT AP.PARTY_ID,
                           SUM (
                                NVL (AP.INVOICE_AMOUNT, 0)
                              * (NVL (EXCHANGE_RATE, 1)))
                              T_INV_AMOUNT
                      FROM AP_INVOICES_ALL AP
                     WHERE     AP.INVOICE_TYPE_LOOKUP_CODE = 'STANDARD'
                           AND AP.APPROVAL_STATUS <> 'CANCELLED'
                           AND TRUNC (AP.INVOICE_DATE) < :P_DATE_FROM
                           AND AP.ORG_ID = NVL (:P_UNIT_NAME, AP.ORG_ID)
                  GROUP BY AP.PARTY_ID) INV
                    ON INV.PARTY_ID = HP.PARTY_ID
                 LEFT OUTER JOIN
                 (  SELECT AC.PARTY_ID, SUM (NVL (AC.AMOUNT, 0)) T_PAY_AMOUNT
                      FROM AP_CHECKS_ALL AC, IBY_PAYMENTS_ALL IPA
                     WHERE     AC.PAYMENT_ID = IPA.PAYMENT_ID
                           AND IPA.PAYMENT_STATUS <> 'VOID'
                           AND AC.CHECK_DATE < :P_DATE_FROM
                           AND AC.ORG_ID = NVL (:P_UNIT_NAME, AC.ORG_ID)
                  GROUP BY AC.PARTY_ID) PAY
                    ON HP.PARTY_ID = PAY.PARTY_ID) OP
            ON HP.PARTY_ID = OP.PARTY_ID
   WHERE HP.PARTY_ID = NVL (:P_PARTY_ID, HP.PARTY_ID)
   AND (  NVL (OP.OPENING_BALANCE, 0)
          + NVL (CREDIT_AMOUNT, 0)
          - NVL (DEBIT_AMOUNT, 0))<>0
ORDER BY HP.PARTY_NAME