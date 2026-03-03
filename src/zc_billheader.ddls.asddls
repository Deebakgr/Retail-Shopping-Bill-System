@EndUserText.label: 'Bill Header - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_BillHeader
  provider contract transactional_query
  as projection on ZI_BillHeader
{
  key BillID,
      CustomerName,
      BillingDate,
      TotalAmount,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
      Currency,
      PaymentStatus,
      StatusCriticality, // ✅ NEW: Exposed to UI
      InvoiceFile,
      MimeType,
      FileName,
      LastChangedAt,
      _Items : redirected to composition child ZC_BillItem
}
