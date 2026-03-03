@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bill Item - Interface View'

define view entity ZI_BillItem
  as select from zdbill_itm
  association to parent ZI_BillHeader as _Header
    on $projection.BillID = _Header.BillID
{
  key bill_id             as BillID,
  key item_position       as ItemPosition,

      product_id          as ProductID,
      product_name        as ProductName,

      quantity            as Quantity,

  @Semantics.amount.currencyCode : 'Currency'
      unit_price          as UnitPrice,
       @Semantics.amount.currencyCode : 'Currency'
      subtotal            as Subtotal,
      
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
      currency            as Currency,

      last_changed_at     as LastChangedAt,

      _Header
}
