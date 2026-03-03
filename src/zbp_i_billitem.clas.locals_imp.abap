CLASS lhc_billitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      update FOR MODIFY
        IMPORTING entities FOR UPDATE billitem,
      delete FOR MODIFY
        IMPORTING keys FOR DELETE billitem,
      read FOR READ
        IMPORTING keys FOR READ billitem RESULT result,
      validatequantity FOR VALIDATE ON SAVE
        IMPORTING keys FOR billitem~validatequantity,
      validateunitprice FOR VALIDATE ON SAVE
        IMPORTING keys FOR billitem~validateunitprice,
      calcsubtotal FOR DETERMINE ON MODIFY
        IMPORTING keys FOR billitem~calcsubtotal,
      calctotalamount FOR DETERMINE ON MODIFY
        IMPORTING keys FOR billitem~calctotalamount.
ENDCLASS.

CLASS lhc_billitem IMPLEMENTATION.

  METHOD update.
    DATA(lo_util) = zbp_i_util=>get_instance( ).
    LOOP AT entities INTO DATA(entity).
      SELECT SINGLE * FROM zdbill_itm WHERE bill_id = @entity-BillID AND item_position = @entity-ItemPosition INTO @DATA(ls_itm).
      IF sy-subrc = 0.
        IF entity-%control-ProductID   = if_abap_behv=>mk-on. ls_itm-product_id   = entity-ProductID. ENDIF.
        IF entity-%control-ProductName = if_abap_behv=>mk-on. ls_itm-product_name = entity-ProductName. ENDIF.
        IF entity-%control-Quantity    = if_abap_behv=>mk-on. ls_itm-quantity     = entity-Quantity. ENDIF.
        IF entity-%control-UnitPrice   = if_abap_behv=>mk-on. ls_itm-unit_price   = entity-UnitPrice. ENDIF.
        IF entity-%control-Currency    = if_abap_behv=>mk-on. ls_itm-currency     = entity-Currency. ENDIF.
        ls_itm-subtotal = ls_itm-quantity * ls_itm-unit_price.
        GET TIME STAMP FIELD ls_itm-last_changed_at.

        lo_util->set_itm_value( EXPORTING im_bill_itm = ls_itm IMPORTING ex_created = DATA(lv_created) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    DATA(lo_util) = zbp_i_util=>get_instance( ).
    LOOP AT keys INTO DATA(key).
      lo_util->set_itm_deletion( EXPORTING im_itm_key = VALUE zbp_i_util=>ty_itm_key( bill_id = key-BillID item_position = key-ItemPosition ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys INTO DATA(key).
      SELECT SINGLE * FROM zdbill_itm WHERE bill_id = @key-BillID AND item_position = @key-ItemPosition INTO @DATA(ls_itm).
      IF sy-subrc = 0.
        APPEND VALUE #( %tky          = key-%tky
                        BillID        = ls_itm-bill_id
                        ItemPosition  = ls_itm-item_position
                        ProductID     = ls_itm-product_id
                        ProductName   = ls_itm-product_name
                        Quantity      = ls_itm-quantity
                        UnitPrice     = ls_itm-unit_price
                        Subtotal      = ls_itm-subtotal
                        Currency      = ls_itm-currency
                        LastChangedAt = ls_itm-last_changed_at ) TO result.
      ELSE.
        APPEND VALUE #( %tky = key-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Item not found' ) ) TO reported-billitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatequantity.
    READ ENTITIES OF zi_billheader IN LOCAL MODE
      ENTITY billitem FIELDS ( Quantity ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_items).
    LOOP AT lt_items INTO DATA(ls_item).
      IF ls_item-Quantity <= 0.
        APPEND VALUE #( %tky = ls_item-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Quantity must be greater than zero' ) ) TO reported-billitem.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-billitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateunitprice.
    READ ENTITIES OF zi_billheader IN LOCAL MODE
      ENTITY billitem FIELDS ( UnitPrice ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_items).
    LOOP AT lt_items INTO DATA(ls_item).
      IF ls_item-UnitPrice <= 0.
        APPEND VALUE #( %tky = ls_item-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Unit Price must be greater than zero' ) ) TO reported-billitem.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-billitem.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD calcsubtotal.
    READ ENTITIES OF zi_billheader IN LOCAL MODE
      ENTITY billitem FIELDS ( Quantity UnitPrice ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_items).
    DATA lt_update TYPE TABLE FOR UPDATE zi_billheader\\billitem.
    LOOP AT lt_items INTO DATA(ls_item).
      APPEND VALUE #( %tky     = ls_item-%tky
                      Subtotal = ls_item-Quantity * ls_item-UnitPrice
                    ) TO lt_update.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billitem UPDATE FIELDS ( Subtotal ) WITH lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD calctotalamount.
    TYPES: BEGIN OF ty_bill_key,
             BillID   TYPE zbp_i_util=>ty_bill_id,
             is_draft TYPE abp_behv_flag,
           END OF ty_bill_key.

    DATA lt_bill_keys TYPE SORTED TABLE OF ty_bill_key WITH UNIQUE KEY BillID is_draft.

    LOOP AT keys INTO DATA(key).
      INSERT VALUE #( BillID = key-BillID is_draft = key-%is_draft ) INTO TABLE lt_bill_keys.
    ENDLOOP.

    LOOP AT lt_bill_keys INTO DATA(ls_bill_key).
      READ ENTITIES OF zi_billheader IN LOCAL MODE
        ENTITY billheader BY \_Items FIELDS ( Subtotal ) WITH VALUE #( ( BillID = ls_bill_key-BillID %is_draft = ls_bill_key-is_draft ) )
        RESULT DATA(lt_items).

      DATA lv_total TYPE p LENGTH 15 DECIMALS 2 VALUE 0.

      LOOP AT lt_items INTO DATA(ls_itm).
        lv_total = lv_total + ls_itm-Subtotal.
      ENDLOOP.

      GET TIME STAMP FIELD DATA(lv_ts).
      MODIFY ENTITIES OF zi_billheader IN LOCAL MODE
        ENTITY billheader UPDATE FIELDS ( TotalAmount LastChangedAt )
        WITH VALUE #( ( BillID = ls_bill_key-BillID %is_draft = ls_bill_key-is_draft TotalAmount = lv_total LastChangedAt = lv_ts ) ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
