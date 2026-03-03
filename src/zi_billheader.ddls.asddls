@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bill Header - Interface View'
define root view entity ZI_BillHeader
  as select from zdbill_hdr
  composition [0..*] of ZI_BillItem as _Items
{
  key bill_id              as BillID,
      customer_name        as CustomerName,
      billing_date         as BillingDate,
      @Semantics.amount.currencyCode : 'Currency'
      total_amount         as TotalAmount,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
      currency             as Currency,
      payment_status       as PaymentStatus,
      
      // ✅ NEW: Determines the color of the status badge (3 = Green, 1 = Blue)
      case payment_status
        when 'Paid' then 3
        when 'Draft' then 1
        else 0
      end as StatusCriticality,

      last_changed_at      as LastChangedAt,
      // ... your other fields like payment_status, last_changed_at ...
      
      @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName',
        contentDispositionPreference: #ATTACHMENT
      }
      invoice_file         as InvoiceFile,
      
      @Semantics.mimeType: true
      mimetype             as MimeType,
      filename             as FileName,
      
      _Items
}
      
