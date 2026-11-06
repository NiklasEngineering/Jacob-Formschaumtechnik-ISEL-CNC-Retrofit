(* Meldejournal (Anforderung 2.9.2, Befund 21): Ringpuffer der letzten 100 kommenden Meldungen
   mit Klasse und Zeitstempel (UTC aus F_GetSystemTime). Ablage in GVL_Persistent.stJournal,
   die HMI liest die Kopie GVL_HMI.stJournal. Spaeter optional zusaetzlich Tc3_EventLogger. *)
FUNCTION_BLOCK FB_AlarmJournal
VAR_INPUT
    aCond : ARRAY[0..14] OF BOOL;
    aId   : ARRAY[0..14] OF INT;
    aClass: ARRAY[0..14] OF INT;
    dtNow : DT;
END_VAR
VAR_IN_OUT
    stJournal : ST_HmiJournal;
END_VAR
VAR_OUTPUT
    nEntries : UINT;
    bChanged : BOOL;      (* in diesem Zyklus neuer Eintrag *)
END_VAR
VAR
    aPrev  : ARRAY[0..14] OF BOOL;
    i      : INT;
END_VAR

bChanged := FALSE;
IF stJournal.nHead > 99 THEN stJournal.nHead := 0; END_IF   (* Schutz bei beschaedigten Persistenzdaten *)
FOR i := 0 TO 14 DO
    IF aCond[i] AND NOT aPrev[i] THEN
        stJournal.aEntry[stJournal.nHead].nId    := aId[i];
        stJournal.aEntry[stJournal.nHead].nClass := aClass[i];
        stJournal.aEntry[stJournal.nHead].dtTime := dtNow;
        stJournal.nHead := (stJournal.nHead + 1) MOD 100;
        IF stJournal.nEntries < 100 THEN stJournal.nEntries := stJournal.nEntries + 1; END_IF
        stJournal.nSeq := stJournal.nSeq + 1;
        bChanged := TRUE;
    END_IF
    aPrev[i] := aCond[i];
END_FOR
nEntries := stJournal.nEntries;
END_FUNCTION_BLOCK
