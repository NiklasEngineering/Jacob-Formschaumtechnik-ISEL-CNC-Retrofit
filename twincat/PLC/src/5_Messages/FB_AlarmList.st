(* Zentrale Meldeliste. Die Logik setzt aCond[Slot] jeden Zyklus, solange die Ursache besteht.
   R3 und R4 bleiben nach Wegfall der Ursache gespeichert, bis quittiert wird (Wiederanlauf nie
   automatisch). Hoechste Klasse gewinnt, bei gleicher Klasse die kleinste ID.
   Anzeige an die HMI spaeter ueber Tc3_EventLogger (Adapter), die Logik bleibt unabhaengig. *)
FUNCTION_BLOCK FB_AlarmList
VAR_INPUT
    aCond : ARRAY[0..14] OF BOOL;        (* Index = E_AlarmSlot *)
    bAck  : BOOL;                        (* Impuls: gespeicherte Meldungen quittieren *)
END_VAR
VAR_OUTPUT
    nActive        : UINT;
    nTopId         : INT;
    nTopClass      : INT;                (* 0..4 = E_FaultClass, Umwandlung mit F_ToFaultClass *)
    bAnyR2OrHigher : BOOL;
    bAnyR3OrHigher : BOOL;
    bAnyR4         : BOOL;
    bAckPending    : BOOL;               (* gespeicherte R3/R4 warten auf Quittierung *)
    aList          : ARRAY[0..14] OF ST_Alarm;   (* fuer die HMI *)
END_VAR
VAR
    aId    : ARRAY[0..14] OF INT;      (* Kopie aus GVL_AlarmCatalog *)
    aClass : ARRAY[0..14] OF INT;
    aLatch : ARRAY[0..14] OF BOOL;
    i      : INT;
    rtAck  : R_TRIG;
    nCls   : INT;
END_VAR

aId := GVL_AlarmCatalog.aAlarmId;
aClass := GVL_AlarmCatalog.aAlarmClass;
rtAck(CLK := bAck);
nActive := 0; nTopId := 0; nTopClass := 0;
bAnyR2OrHigher := FALSE; bAnyR3OrHigher := FALSE; bAnyR4 := FALSE; bAckPending := FALSE;

FOR i := 0 TO 14 DO
    nCls := aClass[i];
    IF aCond[i] AND nCls >= 3 THEN
        aLatch[i] := TRUE;
    END_IF
    IF rtAck.Q AND NOT aCond[i] THEN
        aLatch[i] := FALSE;
    END_IF
    aList[i].nId := aId[i];
    aList[i].eClass := F_ToFaultClass(nCls);
    aList[i].bActive := aCond[i];
    aList[i].bLatched := aLatch[i] AND NOT aCond[i];
    IF aCond[i] OR aLatch[i] THEN
        nActive := nActive + 1;
        IF nCls >= 2 THEN bAnyR2OrHigher := TRUE; END_IF
        IF nCls >= 3 THEN bAnyR3OrHigher := TRUE; END_IF
        IF nCls = 4  THEN bAnyR4 := TRUE; END_IF
        IF aLatch[i] AND NOT aCond[i] THEN bAckPending := TRUE; END_IF
        IF nTopId = 0 OR nCls > nTopClass OR (nCls = nTopClass AND aId[i] < nTopId) THEN
            nTopId := aId[i];
            nTopClass := nCls;
        END_IF
    END_IF
END_FOR
END_FUNCTION_BLOCK
