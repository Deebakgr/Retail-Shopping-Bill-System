CLASS lsc_billheader DEFINITION
  INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
    METHODS cleanup_finalize  REDEFINITION.

ENDCLASS.

CLASS lsc_billheader IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    " ✅ Get Singleton instance
    DATA(lo_util) = zbp_i_util=>get_instance( ).

    " ── Get Buffers ──────────────────────────────────────────
    lo_util->get_hdr_value(
      IMPORTING ex_bill_hdr = DATA(lt_bill_hdr) ).

    lo_util->get_itm_value(
      IMPORTING ex_bill_itm = DATA(lt_bill_itm) ).

    lo_util->get_hdr_deletion(
      IMPORTING ex_hdr_keys = DATA(lt_hdr_del) ).

    lo_util->get_itm_deletion(
      IMPORTING ex_itm_keys = DATA(lt_itm_del) ).

    " ── 1. Save Headers (INSERT or UPDATE) ───────────────────
    IF lt_bill_hdr IS NOT INITIAL.
      MODIFY zdbill_hdr FROM TABLE @lt_bill_hdr.
    ENDIF.

    " ── 2. Save Items (INSERT or UPDATE) ─────────────────────
    IF lt_bill_itm IS NOT INITIAL.
      MODIFY zdbill_itm FROM TABLE @lt_bill_itm.
    ENDIF.

    " ── 3. Delete Headers + Cascade Items ────────────────────
    IF lt_hdr_del IS NOT INITIAL.
      LOOP AT lt_hdr_del INTO DATA(ls_del_hdr).
        DELETE FROM zdbill_hdr
          WHERE bill_id = @ls_del_hdr-bill_id.
        DELETE FROM zdbill_itm
          WHERE bill_id = @ls_del_hdr-bill_id.
      ENDLOOP.
    ENDIF.

    " ── 4. Delete Individual Items ───────────────────────────
    IF lt_itm_del IS NOT INITIAL.
      LOOP AT lt_itm_del INTO DATA(ls_del_itm).
        DELETE FROM zdbill_itm
          WHERE bill_id       = @ls_del_itm-bill_id
            AND item_position = @ls_del_itm-item_position.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD cleanup.
    " ✅ Clear all buffers after save
    zbp_i_util=>get_instance( )->cleanup_buffer( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
