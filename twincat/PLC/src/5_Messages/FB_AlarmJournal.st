(* Meldejournal (Anforderung 2.9.2): Ringpuffer der letzten 100 kommenden Meldungen.
   Persistente Ablage und Zeitstempel folgen im Adapter zum Tc3_EventLogger. *)
FUNCTION_BLOCK FB_AlarmJournal
VAR_INPUT
    aCond : ARRAY[0..14] OF BOOL;
    aId   : ARRAY[0..14] OF INT;
    dtNow : DT;
END_VAR
VAR_OUTPUT
    nEntries : UINT;
END_VAR
VAR
    aJId   : ARRAY[0..99] OF INT;
    aJTime : ARRAY[0..99] OF DT;
    aPrev  : ARRAY[0..14] OF BOOL;
    nHead  : INT;
    i      : INT;
END_VAR

FOR i := 0 TO 14 DO
    IF aCond[i] AND NOT aPrev[i] THEN
        aJId[nHead] := aId[i];
        aJTime[nHead] := dtNow;
        nHead := (nHead + 1) MOD 100;
        IF nEntries < 100 THEN nEntries := nEntries + 1; END_IF
    END_IF
    aPrev[i] := aCond[i];
END_FOR
END_FUNCTION_BLOCK
