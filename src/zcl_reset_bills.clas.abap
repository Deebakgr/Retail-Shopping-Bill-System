CLASS zcl_reset_bills DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_reset_bills IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " 1. Delete all Active Records
    DELETE FROM zdbill_hdr.
    DELETE FROM zdbill_itm.

    " 2. Delete all Hidden Draft Records
    DELETE FROM zdbill_hdr_d.
    DELETE FROM zdbill_itm_d.

    COMMIT WORK.

    " 3. Print Success Message
    out->write( 'All active bills and hidden drafts have been wiped!' ).
    out->write( 'Your counter is successfully reset. The next Bill will be BILL-00001.' ).

  ENDMETHOD.
ENDCLASS.
