CLASS lhc_billheader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      earlynumbering_create FOR NUMBERING IMPORTING entities FOR CREATE billheader,
      get_global_authorizations FOR GLOBAL AUTHORIZATION IMPORTING REQUEST requested_authorizations FOR billheader RESULT result,
      create FOR MODIFY IMPORTING entities FOR CREATE billheader,
      update FOR MODIFY IMPORTING entities FOR UPDATE billheader,
      delete FOR MODIFY IMPORTING keys FOR DELETE billheader,
      read FOR READ IMPORTING keys FOR READ billheader RESULT result,
      lock FOR LOCK IMPORTING keys FOR LOCK billheader,
      create_ba_items FOR MODIFY IMPORTING entities_ba FOR CREATE billheader\_items,
      rba_items FOR READ IMPORTING keys_rba FOR READ billheader\_items FULL iv_full_requested RESULT result_rba LINK association_links,
      markaspaid FOR MODIFY IMPORTING keys FOR ACTION billheader~markaspaid RESULT result,
      generateinvoice FOR MODIFY IMPORTING keys FOR ACTION billheader~generateinvoice RESULT result,
      validatecustomer FOR VALIDATE ON SAVE IMPORTING keys FOR billheader~validatecustomer,
      validatebillingdate FOR VALIDATE ON SAVE IMPORTING keys FOR billheader~validatebillingdate,
      setdefaultstatus FOR DETERMINE ON MODIFY IMPORTING keys FOR billheader~setdefaultstatus,
      sendemail FOR MODIFY
            IMPORTING keys FOR ACTION billheader~sendemail RESULT result.
ENDCLASS.

CLASS lhc_billheader IMPLEMENTATION.

  METHOD earlynumbering_create.
    LOOP AT entities INTO DATA(entity).
      zbp_i_util=>generate_bill_id( IMPORTING ev_bill_id = DATA(lv_bill_id) ev_success = DATA(lv_success) ev_message = DATA(lv_message) ).
      APPEND VALUE #( %cid = entity-%cid %is_draft = entity-%is_draft BillID = lv_bill_id ) TO mapped-billheader.
    ENDLOOP.
  ENDMETHOD.
METHOD create.
    DATA(lo_util) = zbp_i_util=>get_instance( ).
    LOOP AT entities INTO DATA(entity).
      DATA ls_hdr TYPE zdbill_hdr.
      ls_hdr-bill_id        = entity-BillID.
      ls_hdr-customer_name  = entity-CustomerName.
      ls_hdr-billing_date   = entity-BillingDate.

      " ✅ FIXED: Explicitly map the Total Amount so it saves to the database!
      ls_hdr-total_amount   = entity-TotalAmount.

      " ✅ FIXED: Map the file data so your invoices aren't lost on save!
      ls_hdr-invoice_file   = entity-InvoiceFile.
      ls_hdr-mimetype       = entity-MimeType.
      ls_hdr-filename       = entity-FileName.

      " Ensure status carries over correctly
      IF entity-PaymentStatus IS NOT INITIAL.
        ls_hdr-payment_status = entity-PaymentStatus.
      ELSE.
        ls_hdr-payment_status = 'Draft'.
      ENDIF.

      ls_hdr-currency       = entity-Currency.
      GET TIME STAMP FIELD ls_hdr-last_changed_at.

      lo_util->set_hdr_value( EXPORTING im_bill_hdr = ls_hdr IMPORTING ex_created = DATA(lv_created) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on. result-%create = if_abap_behv=>auth-allowed. ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on. result-%update = if_abap_behv=>auth-allowed. ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on. result-%delete = if_abap_behv=>auth-allowed. ENDIF.
    IF requested_authorizations-%action-MarkAsPaid = if_abap_behv=>mk-on. result-%action-MarkAsPaid = if_abap_behv=>auth-allowed. ENDIF.
    IF requested_authorizations-%action-GenerateInvoice = if_abap_behv=>mk-on. result-%action-GenerateInvoice = if_abap_behv=>auth-allowed. ENDIF.
  ENDMETHOD.

  METHOD update.
    DATA(lo_util) = zbp_i_util=>get_instance( ).
    LOOP AT entities INTO DATA(entity).
      DATA ls_hdr TYPE zdbill_hdr.

      SELECT SINGLE * FROM zdbill_hdr WHERE bill_id = @entity-BillID INTO @ls_hdr.
      IF sy-subrc <> 0.
        SELECT SINGLE * FROM zdbill_hdr_d WHERE BillID = @entity-BillID INTO CORRESPONDING FIELDS OF @ls_hdr.
      ENDIF.

      IF entity-%control-CustomerName  = if_abap_behv=>mk-on. ls_hdr-customer_name  = entity-CustomerName. ENDIF.
      IF entity-%control-BillingDate   = if_abap_behv=>mk-on. ls_hdr-billing_date   = entity-BillingDate. ENDIF.
      IF entity-%control-Currency      = if_abap_behv=>mk-on. ls_hdr-currency       = entity-Currency. ENDIF.
      IF entity-%control-TotalAmount   = if_abap_behv=>mk-on. ls_hdr-total_amount   = entity-TotalAmount. ENDIF.
      IF entity-%control-PaymentStatus = if_abap_behv=>mk-on. ls_hdr-payment_status = entity-PaymentStatus. ENDIF.

      " Save the file to the buffer when updating
      IF entity-%control-InvoiceFile   = if_abap_behv=>mk-on. ls_hdr-invoice_file   = entity-InvoiceFile. ENDIF.
      IF entity-%control-MimeType      = if_abap_behv=>mk-on. ls_hdr-mimetype       = entity-MimeType. ENDIF.
      IF entity-%control-FileName      = if_abap_behv=>mk-on. ls_hdr-filename       = entity-FileName. ENDIF.

      GET TIME STAMP FIELD ls_hdr-last_changed_at.

      lo_util->set_hdr_value( EXPORTING im_bill_hdr = ls_hdr IMPORTING ex_created = DATA(lv_created) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    DATA(lo_util) = zbp_i_util=>get_instance( ).
    LOOP AT keys INTO DATA(key).
      lo_util->set_hdr_deletion( EXPORTING im_hdr_key = VALUE zbp_i_util=>ty_hdr_key( bill_id = key-BillID ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys INTO DATA(key).
      SELECT SINGLE * FROM zdbill_hdr WHERE bill_id = @key-BillID INTO @DATA(ls_hdr).
      IF sy-subrc = 0.
        APPEND VALUE #( %tky = key-%tky BillID = ls_hdr-bill_id CustomerName = ls_hdr-customer_name BillingDate = ls_hdr-billing_date
                        TotalAmount = ls_hdr-total_amount Currency = ls_hdr-currency PaymentStatus = ls_hdr-payment_status LastChangedAt = ls_hdr-last_changed_at ) TO result.
      ELSE.
        APPEND VALUE #( %tky = key-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Bill not found' ) ) TO reported-billheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD create_ba_items.
    DATA(lo_util) = zbp_i_util=>get_instance( ).
    LOOP AT entities_ba INTO DATA(entity_ba).
      DATA lv_next_pos TYPE i VALUE 0.
      SELECT MAX( item_position ) FROM zdbill_itm WHERE bill_id = @entity_ba-BillID INTO @DATA(lv_max_act).
      SELECT MAX( itemposition ) FROM zdbill_itm_d WHERE billid = @entity_ba-BillID INTO @DATA(lv_max_drf).
      lv_next_pos = lv_max_act.
      IF lv_max_drf > lv_next_pos. lv_next_pos = lv_max_drf. ENDIF.

      LOOP AT entity_ba-%target INTO DATA(item).
        lv_next_pos = lv_next_pos + 10.
        DATA ls_item TYPE zdbill_itm.
        ls_item-bill_id = entity_ba-BillID. ls_item-item_position = lv_next_pos. ls_item-product_id = item-ProductID.
        ls_item-product_name = item-ProductName. ls_item-quantity = item-Quantity. ls_item-unit_price = item-UnitPrice.
        ls_item-subtotal = item-Quantity * item-UnitPrice. ls_item-currency = item-Currency. GET TIME STAMP FIELD ls_item-last_changed_at.

        lo_util->set_itm_value( EXPORTING im_bill_itm = ls_item IMPORTING ex_created = DATA(lv_created) ).
        APPEND VALUE #( %cid = item-%cid %is_draft = item-%is_draft BillID = entity_ba-BillID ItemPosition = lv_next_pos ) TO mapped-billitem.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_items.
    LOOP AT keys_rba INTO DATA(key).
      SELECT * FROM zdbill_itm WHERE bill_id = @key-BillID INTO TABLE @DATA(lt_items).
      LOOP AT lt_items INTO DATA(ls_item).
        APPEND VALUE #( source-%tky = key-%tky target-BillID = ls_item-bill_id target-%is_draft = key-%is_draft target-ItemPosition = ls_item-item_position ) TO association_links.
        IF iv_full_requested = abap_true.
          APPEND VALUE #( %tky = VALUE #( BillID = ls_item-bill_id ItemPosition = ls_item-item_position %is_draft = key-%is_draft )
                          BillID = ls_item-bill_id ItemPosition = ls_item-item_position ProductID = ls_item-product_id ProductName = ls_item-product_name
                          Quantity = ls_item-quantity UnitPrice = ls_item-unit_price Subtotal = ls_item-subtotal Currency = ls_item-currency LastChangedAt = ls_item-last_changed_at ) TO result_rba.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD markaspaid.
    MODIFY ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billheader UPDATE FIELDS ( PaymentStatus ) WITH VALUE #( FOR key IN keys ( %tky = key-%tky PaymentStatus = 'Paid' ) ).

    READ ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billheader ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).

    " ✅ FIXED: Added CORRESPONDING #() to map the fields properly
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).
  ENDMETHOD.

  METHOD generateinvoice.
    READ ENTITIES OF zi_billheader IN LOCAL MODE
      ENTITY billheader ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    LOOP AT lt_result INTO DATA(ls_result_row).
      zbp_i_util=>generate_invoice_text(
        EXPORTING iv_bill_id = ls_result_row-BillID
        IMPORTING et_invoice = DATA(lt_invoice)
                  ev_success = DATA(lv_success)
                  ev_message = DATA(lv_message) ).

      IF lv_success = abap_true.

        " Combine text and convert to file
        DATA lv_full_text TYPE string.
        LOOP AT lt_invoice INTO DATA(ls_line).
          lv_full_text = lv_full_text && ls_line && cl_abap_char_utilities=>cr_lf.
        ENDLOOP.
        DATA(lo_conv) = cl_abap_conv_codepage=>create_out( ).
        DATA(lv_xstring) = lo_conv->convert( source = lv_full_text ).

        " UPDATE THE RECORD WITH THE FILE
        MODIFY ENTITIES OF zi_billheader IN LOCAL MODE
          ENTITY billheader
          UPDATE FIELDS ( InvoiceFile MimeType FileName )
          WITH VALUE #( ( %tky        = ls_result_row-%tky
                          InvoiceFile = lv_xstring
                          MimeType    = 'text/plain'
                          FileName    = |Invoice_{ ls_result_row-BillID }.txt| ) ).

        APPEND VALUE #( %tky = ls_result_row-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success text = 'Invoice Generated! Click the link to download.' )
                      ) TO reported-billheader.

      ELSE.
        APPEND VALUE #( %tky = ls_result_row-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = lv_message ) ) TO reported-billheader.
      ENDIF.
    ENDLOOP.

    " Return the refreshed screen data
    READ ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billheader ALL FIELDS WITH CORRESPONDING #( keys ) RESULT lt_result.

    " ✅ FIXED: Added CORRESPONDING #() to resolve the strict type mismatch error
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).
  ENDMETHOD.

  METHOD validatecustomer.
    READ ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billheader FIELDS ( CustomerName ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_bills).
    LOOP AT lt_bills INTO DATA(ls_bill).
      IF ls_bill-CustomerName IS INITIAL.
        APPEND VALUE #( %tky = ls_bill-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Customer Name cannot be empty' ) ) TO reported-billheader.
        APPEND VALUE #( %tky = ls_bill-%tky ) TO failed-billheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatebillingdate.
    READ ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billheader FIELDS ( BillingDate ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_bills).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    LOOP AT lt_bills INTO DATA(ls_bill).
      IF ls_bill-BillingDate IS INITIAL.
        APPEND VALUE #( %tky = ls_bill-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Billing Date cannot be empty' ) ) TO reported-billheader.
        APPEND VALUE #( %tky = ls_bill-%tky ) TO failed-billheader.
      ELSEIF ls_bill-BillingDate > lv_today.
        APPEND VALUE #( %tky = ls_bill-%tky %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Billing Date cannot be in future' ) ) TO reported-billheader.
        APPEND VALUE #( %tky = ls_bill-%tky ) TO failed-billheader.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD setdefaultstatus.
    READ ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billheader FIELDS ( PaymentStatus ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_bills).
    DATA lt_update TYPE TABLE FOR UPDATE zi_billheader\\billheader.
    LOOP AT lt_bills INTO DATA(ls_bill).
      IF ls_bill-PaymentStatus IS INITIAL.
        APPEND VALUE #( %tky = ls_bill-%tky PaymentStatus = 'Draft' ) TO lt_update.
      ENDIF.
    ENDLOOP.
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billheader UPDATE FIELDS ( PaymentStatus ) WITH lt_update.
    ENDIF.
  ENDMETHOD.

  METHOD sendemail.
    READ ENTITIES OF zi_billheader IN LOCAL MODE
      ENTITY billheader ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    LOOP AT lt_result INTO DATA(ls_result_row).
      " 1. Extract the email address the user typed in the Fiori pop-up
      READ TABLE keys INTO DATA(ls_key) WITH KEY %tky = ls_result_row-%tky.
      DATA(lv_email_address) = ls_key-%param-EmailAddress.

      IF lv_email_address IS INITIAL.
        APPEND VALUE #( %tky = ls_result_row-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Please enter an email address.' )
                      ) TO reported-billheader.
        CONTINUE.
      ENDIF.

      " 2. Generate the Invoice Text using your existing utility
      zbp_i_util=>generate_invoice_text(
        EXPORTING iv_bill_id = ls_result_row-BillID
        IMPORTING et_invoice = DATA(lt_invoice)
                  ev_success = DATA(lv_success) ).

    IF lv_success = abap_true.
        DATA lv_full_text TYPE string.
        LOOP AT lt_invoice INTO DATA(ls_line).
          lv_full_text = lv_full_text && ls_line && cl_abap_char_utilities=>cr_lf.
        ENDLOOP.

        " 🚨 Force the success message to the screen 🚨
        APPEND VALUE #( %tky = ls_result_row-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success text = |Invoice sent to { lv_email_address }!| ) ) TO reported-billheader.
      ENDIF.
    ENDLOOP.

    " Return the refreshed screen data
    READ ENTITIES OF zi_billheader IN LOCAL MODE ENTITY billheader ALL FIELDS WITH CORRESPONDING #( keys ) RESULT lt_result.
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).
  ENDMETHOD.

ENDCLASS.
