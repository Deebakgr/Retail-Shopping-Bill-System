@EndUserText.label: 'Bill Item - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_BillItem
  as projection on ZI_BillItem
{
  key BillID,
  key ItemPosition,

      ProductID,
      ProductName,

      Quantity,
      @Semantics.amount.currencyCode : 'Currency'
      UnitPrice,
      Subtotal,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
      Currency,

      LastChangedAt,

      _Header : redirected to parent ZC_BillHeader
}
