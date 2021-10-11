SELECT PARTY_NAME,
      (SUM (OPENING_BALANCE)) OPENING_BALANCE,
      SUM (DEBIT_AMOUNT) DR_TRAN,
      SUM (CREDIT_AMOUNT) CR_TRAN,
      (SUM (OPENING_BALANCE)+nvl(SUM (CREDIT_AMOUNT),0))-(nvl(SUM (DEBIT_AMOUNT),0))CLOSING_BALANCE,
      FND_GLOBAL.USER_NAME CREATED_BY
FROM (    SELECT PARTY_ID,
                 PARTY_NAME,
                 UNIT_NAME,
                 VENDOR_SITE_ID,
                 VENDOR_SITE_CODE,  
                 VENDOR_SITE_CODE VENDOR_SITE_CODE1,
                 VENDOR_SITE_CODE VENDOR_SITE_CODE2,               
                 DEBIT_AMOUNT,
                 CREDIT_AMOUNT,
                 OPENING_BALANCE
FROM (SELECT HP.PARTY_ID,
             HP.PARTY_NAME,
             HOU.NAME UNIT_NAME,
             PSS.VENDOR_SITE_CODE,
             PSS.VENDOR_SITE_ID,
             NVL (OP.OPENING_BALANCE, 0) AS OPENING_BALANCE,
             NVL (DEBIT_AMOUNT, 0) DEBIT_AMOUNT,
             NVL (CREDIT_AMOUNT, 0) CREDIT_AMOUNT,
             (NVL (OP.OPENING_BALANCE, 0) + NVL (CREDIT_AMOUNT, 0) - NVL (DEBIT_AMOUNT, 0)) BALANCE
FROM HZ_PARTIES HP
INNER JOIN HZ_PARTY_SITES HPS
ON HP.PARTY_ID = HPS.PARTY_ID
INNER JOIN POZ_SUPPLIER_SITES_ALL_M PSS
ON HPS.PARTY_SITE_ID = PSS.PARTY_SITE_ID
LEFT OUTER JOIN HR_ORGANIZATION_UNITS hou
ON PSS.PRC_BU_ID = HOU.ORGANIZATION_ID
LEFT OUTER JOIN (SELECT VENDOR_SITE_ID, SUM (NVL (CH.AMOUNT, 0)) DEBIT_AMOUNT
                 FROM AP_CHECKS_ALL CH,IBY_PAYMENTS_ALL IPA
                 WHERE CH.PAYMENT_ID = IPA.PAYMENT_ID
                 AND IPA.PAYMENT_STATUS <> 'VOID'
                 AND CH.CHECK_DATE BETWEEN NVL (:P_DATE_FROM,CH.CHECK_DATE) AND NVL (:P_DATE_TO,CH.CHECK_DATE)
                 GROUP BY VENDOR_SITE_ID) DR
                 ON PSS.VENDOR_SITE_ID= DR.VENDOR_SITE_ID
                 LEFT OUTER JOIN
                 (SELECT VENDOR_SITE_ID,ORG_ID,SUM (NVL (APA.INVOICE_AMOUNT, 0)*(NVL(EXCHANGE_RATE,1))) AS CREDIT_AMOUNT
                  FROM AP_INVOICES_ALL APA
                  WHERE APA.INVOICE_TYPE_LOOKUP_CODE <> 'PREPAYMENT'
                  AND APA.APPROVAL_STATUS <> 'CANCELLED'
                  AND APA.INVOICE_DATE BETWEEN NVL ( :P_DATE_FROM,APA.INVOICE_DATE) AND NVL (:P_DATE_TO,APA.INVOICE_DATE)
                          GROUP BY VENDOR_SITE_ID, ORG_ID) CR
                            ON PSS.VENDOR_SITE_ID = CR.VENDOR_SITE_ID
                         LEFT OUTER JOIN
                         (SELECT PSS.VENDOR_SITE_CODE,
                                 PSS.VENDOR_SITE_ID,
                                 (NVL (T_INV_AMOUNT, 0) - NVL (T_PAY_AMOUNT, 0))
                                    OPENING_BALANCE
                            FROM HZ_PARTIES HP
                                 INNER JOIN HZ_PARTY_SITES HPS
                                    ON HP.PARTY_ID = HPS.PARTY_ID
                                 INNER JOIN POZ_SUPPLIER_SITES_ALL_M PSS
                                    ON HPS.PARTY_SITE_ID = PSS.PARTY_SITE_ID
                                 LEFT OUTER JOIN
                                 (  SELECT AP.VENDOR_SITE_ID,
                                           SUM (NVL (AP.INVOICE_AMOUNT, 0)*(NVL(EXCHANGE_RATE,1)))
                                              T_INV_AMOUNT
                                      FROM AP_INVOICES_ALL AP
                                     WHERE AP.INVOICE_TYPE_LOOKUP_CODE <> 'PREPAYMENT'
                                           AND AP.APPROVAL_STATUS <> 'CANCELLED'
                                           AND TRUNC (AP.INVOICE_DATE) < :P_DATE_FROM
                                  GROUP BY AP.VENDOR_SITE_ID) INV
                                    ON INV.VENDOR_SITE_ID = PSS.VENDOR_SITE_ID
                                 LEFT OUTER JOIN
                                 (  SELECT AC.VENDOR_SITE_ID,
                                           SUM (NVL (AC.AMOUNT, 0)) T_PAY_AMOUNT
                                      FROM AP_CHECKS_ALL AC
                                     WHERE AC.CHECK_DATE < :P_DATE_FROM
                                  GROUP BY AC.VENDOR_SITE_ID) PAY
                                    ON PSS.VENDOR_SITE_ID = PAY.VENDOR_SITE_ID
                           WHERE (NVL (T_INV_AMOUNT, 0) <>
                                     NVL (T_PAY_AMOUNT, 0))) OP
                            ON PSS.VENDOR_SITE_ID = OP.VENDOR_SITE_ID
                         LEFT OUTER JOIN HR_ORGANIZATION_UNITS HOU
                            ON CR.ORG_ID = HOU.ORGANIZATION_ID                                                                             ))
   WHERE VENDOR_SITE_CODE IN  (NVL(:P_VENDOR_SITE_CODE,VENDOR_SITE_CODE),NVL(:P_VENDOR_SITE_CODE2,'1'),NVL(:P_VENDOR_SITE_CODE3,'2'))
   AND PARTY_ID=NVL(:P_PARTY_ID,PARTY_ID)
GROUP BY PARTY_NAME
HAVING (SUM (OPENING_BALANCE)+nvl(SUM (CREDIT_AMOUNT),0))-(nvl(SUM (DEBIT_AMOUNT),0))<>0
ORDER BY PARTY_NAME