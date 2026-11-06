(* Hilfsfunktionen aus dem NC-Programm (M-Codes). Die Zuordnung orientiert sich an der
   isel-G-/M-Code-Liste (Klaerungsliste Funktionen 2.7). Welche M-Codes der Kunde tatsaechlich
   braucht, bestimmt das Lastenheft (2.8.2). Die Anbindung an die CNC (Tc2_CncHli) folgt,
   sobald die Usermode Runtime laeuft. *)
FUNCTION_BLOCK FB_MFunctions
VAR_INPUT
    nMCode      : INT;          (* aktive M-Funktion aus der CNC, 0 = keine *)
    bMStrobe    : BOOL;         (* CNC wartet auf Quittung *)
    bSpindleOk  : BOOL;
    bAuxOk      : BOOL;
    bReset      : BOOL;         (* Abbruch, R3/R4, NOT-HALT, Programmende: alle gehaltenen M-Zustaende loeschen *)
    bOptStop    : BOOL;         (* optionaler Halt M1 aktiv (aus der HMI) *)
END_VAR
VAR_OUTPUT
    bSpindleCw    : BOOL;       (* M3 *)
    bSpindleCcw   : BOOL;       (* M4 *)
    bExtraction   : BOOL;       (* M43 ein, M44 aus [Annahme: Belegung klaeren] *)
    bBlowAir      : BOOL;       (* M8 ein, M9 aus *)
    bVacuum       : BOOL;       (* M10 ein, M11 aus *)
    bToolChangeReq: BOOL;       (* M6: manuelle Aufforderung am Panel *)
    bProgramHalt  : BOOL;       (* M0 *)
    bAck          : BOOL;       (* Quittung an die CNC *)
    bUnknown      : BOOL;       (* unbekannter M-Code: Meldung, kein Stillstand der Quittung *)
END_VAR
VAR
    rtStrobe : R_TRIG;
END_VAR

rtStrobe(CLK := bMStrobe);
bUnknown := FALSE; bToolChangeReq := FALSE; bProgramHalt := FALSE;

IF bReset THEN
    bSpindleCw := FALSE; bSpindleCcw := FALSE; bExtraction := FALSE; bBlowAir := FALSE; bVacuum := FALSE;
END_IF

IF rtStrobe.Q AND NOT bReset THEN
    CASE nMCode OF
        0:  bProgramHalt := TRUE;
        1:  IF bOptStop THEN bProgramHalt := TRUE; END_IF
        3:  IF bSpindleOk THEN bSpindleCw := TRUE; bSpindleCcw := FALSE; END_IF
        4:  IF bSpindleOk THEN bSpindleCcw := TRUE; bSpindleCw := FALSE; END_IF
        5:  bSpindleCw := FALSE; bSpindleCcw := FALSE;
        6:  bToolChangeReq := TRUE;
        8:  IF bAuxOk THEN bBlowAir := TRUE; END_IF
        9:  bBlowAir := FALSE;
        10: IF bAuxOk THEN bVacuum := TRUE; END_IF
        11: bVacuum := FALSE;
        2, 30: bSpindleCw := FALSE; bSpindleCcw := FALSE; bBlowAir := FALSE; bExtraction := FALSE; bVacuum := FALSE;
        43: IF bAuxOk THEN bExtraction := TRUE; END_IF
        44: bExtraction := FALSE;
    ELSE
        bUnknown := TRUE;
    END_CASE
END_IF
(* Quittung bleibt stehen, bis die CNC den Strobe zurueckgenommen hat (Befund 12) *)
bAck := bMStrobe;
END_FUNCTION_BLOCK
