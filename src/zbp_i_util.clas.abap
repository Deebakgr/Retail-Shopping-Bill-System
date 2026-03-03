CLASS zbp_i_util DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES: ty_bill_id TYPE c LENGTH 10.

    TYPES: BEGIN OF ty_hdr_key,
             bill_id TYPE c LENGTH 10,
           END OF ty_hdr_key.

    TYPES: BEGIN OF ty_itm_key,
             bill_id       TYPE c LENGTH 10,
             item_position TYPE i,
           END OF ty_itm_key.

    TYPES: tt_hdr_key     TYPE STANDARD TABLE OF ty_hdr_key     WITH DEFAULT KEY,
           tt_itm_key     TYPE STANDARD TABLE OF ty_itm_key     WITH DEFAULT KEY,
           tt_bill_hdr    TYPE STANDARD TABLE OF zdbill_hdr     WITH DEFAULT KEY,
           tt_bill_itm    TYPE STANDARD TABLE OF zdbill_itm     WITH DEFAULT KEY.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_instance) TYPE REF TO zbp_i_util.

    METHODS set_hdr_value
      IMPORTING im_bill_hdr TYPE zdbill_hdr
      EXPORTING ex_created  TYPE abap_boolean.

    METHODS get_hdr_value
      EXPORTING ex_bill_hdr TYPE tt_bill_hdr.

    METHODS set_itm_value
      IMPORTING im_bill_itm TYPE zdbill_itm
      EXPORTING ex_created  TYPE abap_boolean.

    METHODS get_itm_value
      EXPORTING ex_bill_itm TYPE tt_bill_itm.

    METHODS set_hdr_deletion
      IMPORTING im_hdr_key TYPE ty_hdr_key.

    METHODS set_itm_deletion
      IMPORTING im_itm_key TYPE ty_itm_key.

    METHODS get_hdr_deletion
      EXPORTING ex_hdr_keys TYPE tt_hdr_key.

    METHODS get_itm_deletion
      EXPORTING ex_itm_keys TYPE tt_itm_key.

    METHODS cleanup_buffer.

    CLASS-METHODS generate_bill_id
      EXPORTING ev_bill_id  TYPE ty_bill_id
                ev_success  TYPE abap_boolean
                ev_message  TYPE string.

    CLASS-METHODS generate_invoice_text
      IMPORTING iv_bill_id  TYPE ty_bill_id
      EXPORTING et_invoice  TYPE string_table
                ev_success  TYPE abap_boolean
                ev_message  TYPE string.

    CLASS-METHODS format_date
      IMPORTING iv_date        TYPE d
      RETURNING VALUE(rv_date) TYPE string.

  PRIVATE SECTION.
    CLASS-DATA mo_instance TYPE REF TO zbp_i_util.

    CLASS-DATA gt_hdr_buff     TYPE tt_bill_hdr.
    CLASS-DATA gt_itm_buff     TYPE tt_bill_itm.
    CLASS-DATA gt_hdr_del_buff TYPE tt_hdr_key.
    CLASS-DATA gt_itm_del_buff TYPE tt_itm_key.
ENDCLASS.

CLASS zbp_i_util IMPLEMENTATION.

  METHOD get_instance.
    IF mo_instance IS INITIAL.
      CREATE OBJECT mo_instance.
    ENDIF.
    ro_instance = mo_instance.
  ENDMETHOD.

  METHOD set_hdr_value.
    IF im_bill_hdr-bill_id IS NOT INITIAL.
      READ TABLE gt_hdr_buff WITH KEY bill_id = im_bill_hdr-bill_id TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        MODIFY gt_hdr_buff FROM im_bill_hdr INDEX sy-tabix.
      ELSE.
        APPEND im_bill_hdr TO gt_hdr_buff.
      ENDIF.
      ex_created = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD get_hdr_value.
    ex_bill_hdr = gt_hdr_buff.
  ENDMETHOD.

  METHOD set_itm_value.
    IF im_bill_itm-bill_id IS NOT INITIAL.
      READ TABLE gt_itm_buff WITH KEY bill_id = im_bill_itm-bill_id item_position = im_bill_itm-item_position TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        MODIFY gt_itm_buff FROM im_bill_itm INDEX sy-tabix.
      ELSE.
        APPEND im_bill_itm TO gt_itm_buff.
      ENDIF.
      ex_created = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD get_itm_value.
    ex_bill_itm = gt_itm_buff.
  ENDMETHOD.

  METHOD set_hdr_deletion.
    APPEND im_hdr_key TO gt_hdr_del_buff.
  ENDMETHOD.

  METHOD set_itm_deletion.
    APPEND im_itm_key TO gt_itm_del_buff.
  ENDMETHOD.

  METHOD get_hdr_deletion.
    ex_hdr_keys = gt_hdr_del_buff.
  ENDMETHOD.

  METHOD get_itm_deletion.
    ex_itm_keys = gt_itm_del_buff.
  ENDMETHOD.

  METHOD cleanup_buffer.
    CLEAR: gt_hdr_buff, gt_itm_buff, gt_hdr_del_buff, gt_itm_del_buff.
  ENDMETHOD.


  METHOD generate_bill_id.
    ev_success = abap_true.
    ev_message = ''.

    DATA: lv_highest TYPE ty_bill_id,
          lv_next_num TYPE i.

    TRY.
        SELECT SINGLE MAX( bill_id ) FROM zdbill_hdr INTO @DATA(lv_max_act).
        SELECT SINGLE MAX( billid ) FROM zdbill_hdr_d INTO @DATA(lv_max_drf).

        lv_highest = lv_max_act.
        IF lv_max_drf > lv_highest.
          lv_highest = lv_max_drf.
        ENDIF.

        IF lv_highest IS INITIAL.
          lv_next_num = 1.
        ELSE.
          FIND FIRST OCCURRENCE OF 'BILL-' IN lv_highest.
          IF sy-subrc = 0.
            DATA(lv_str_num) = substring( val = lv_highest off = 5 len = 5 ).
            lv_next_num = CONV i( lv_str_num ) + 1.
          ELSE.
            lv_next_num = 1.
          ENDIF.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        " Fallback if parsing ever fails
        lv_next_num = 999.
    ENDTRY.

    DATA(lv_padded) = |{ lv_next_num WIDTH = 5 ALIGN = RIGHT PAD = '0' }|.
    ev_bill_id = |BILL-{ lv_padded }|.
  ENDMETHOD.

  METHOD generate_invoice_text.
    ev_success = abap_false.
    ev_message = ''.
    CLEAR et_invoice.

    DATA ls_hdr TYPE zdbill_hdr.
    DATA lt_items TYPE STANDARD TABLE OF zdbill_itm.

    " Try Active Table First
    SELECT SINGLE * FROM zdbill_hdr WHERE bill_id = @iv_bill_id INTO @ls_hdr.

    " Try Draft Table if not in active
    IF sy-subrc <> 0.
      SELECT SINGLE * FROM zdbill_hdr_d WHERE BillID = @iv_bill_id INTO CORRESPONDING FIELDS OF @ls_hdr.
      IF sy-subrc <> 0.
        ev_message = |Bill ID { iv_bill_id } not found|.
        RETURN.
      ENDIF.
    ENDIF.

    " Get Items
    SELECT * FROM zdbill_itm WHERE bill_id = @iv_bill_id ORDER BY item_position INTO TABLE @lt_items.
    IF lt_items IS INITIAL.
      SELECT * FROM zdbill_itm_d WHERE BillID = @iv_bill_id ORDER BY ItemPosition INTO CORRESPONDING FIELDS OF TABLE @lt_items.
    ENDIF.

    APPEND '╔══════════════════════════════════════════════════════════╗' TO et_invoice.
    APPEND '║          RETAIL SHOP BILLING SYSTEM                      ║' TO et_invoice.
    APPEND '║                  TAX INVOICE                             ║' TO et_invoice.
    APPEND '╚══════════════════════════════════════════════════════════╝' TO et_invoice.
    APPEND '' TO et_invoice.
    APPEND |  Bill ID       : { iv_bill_id }|           TO et_invoice.
    APPEND |  Customer Name : { ls_hdr-customer_name }| TO et_invoice.
    APPEND |  Billing Date  : { format_date( ls_hdr-billing_date ) }| TO et_invoice.
    APPEND |  Currency      : { ls_hdr-currency }|      TO et_invoice.
    APPEND |  Payment Status: { ls_hdr-payment_status }| TO et_invoice.
    APPEND '──────────────────────────────────────────────────────────' TO et_invoice.
    APPEND ' Pos | Product ID           | Qty    | Unit Price | Subtotal' TO et_invoice.
    APPEND '──────────────────────────────────────────────────────────' TO et_invoice.

    LOOP AT lt_items INTO DATA(ls_item).
      DATA(lv_pos)   = |{ ls_item-item_position WIDTH = 4 ALIGN = RIGHT }|.
      DATA(lv_prod)  = |{ ls_item-product_id    WIDTH = 20 ALIGN = LEFT }|.
      DATA(lv_qty)   = |{ ls_item-quantity       WIDTH = 7 ALIGN = RIGHT DECIMALS = 2 }|.
      DATA(lv_price) = |{ ls_item-unit_price     WIDTH = 10 ALIGN = RIGHT DECIMALS = 2 }|.
      DATA(lv_sub)   = |{ ls_item-subtotal       WIDTH = 10 ALIGN = RIGHT DECIMALS = 2 }|.

      APPEND |  | && lv_pos  && | | && lv_prod && | | && lv_qty  && | | && lv_price && | | && lv_sub TO et_invoice.
    ENDLOOP.

    APPEND '──────────────────────────────────────────────────────────' TO et_invoice.
    APPEND |{ '' WIDTH = 34 }GRAND TOTAL :| &&
           |{ ls_hdr-total_amount WIDTH = 12 ALIGN = RIGHT DECIMALS = 2 }| &&
           | { ls_hdr-currency }| TO et_invoice.
    APPEND '──────────────────────────────────────────────────────────' TO et_invoice.
    APPEND '' TO et_invoice.

    DATA(lv_sys_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_sys_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_sys_user) = cl_abap_context_info=>get_user_technical_name( ).

    APPEND |  Generated On : { format_date( lv_sys_date ) }  | &&
           |{ lv_sys_time+0(2) }:| && |{ lv_sys_time+2(2) }:| && |{ lv_sys_time+4(2) }| TO et_invoice.
    APPEND |  Generated By : { lv_sys_user }| TO et_invoice.
    APPEND '' TO et_invoice.
    APPEND '  *** Thank you for shopping with us! ***' TO et_invoice.
    APPEND '══════════════════════════════════════════════════════════' TO et_invoice.

    ev_success = abap_true.

  ENDMETHOD.

  METHOD format_date.
    IF iv_date IS INITIAL OR iv_date = '00000000'.
      rv_date = ''.
    ELSE.
      rv_date = |{ iv_date+6(2) }.{ iv_date+4(2) }.{ iv_date+0(4) }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
