(* Hilfsfunktionen aus dem NC-Programm (M-Codes). Die Zuordnung orientiert sich an der
   isel-G-/M-Code-Liste (Klaerungsliste Funktionen 2.7). Welche M-Codes der Kunde tatsaechlich
   braucht, bestimmt das Lastenheft (2.8.2). Die Anbindung an die CNC (Tc2_CncHli) folgt.
   Gutachten G-03: M3/M4 wird erst quittiert, wenn die Spindel laeuft (oder bewusst gesperrt ist: Einrichten,
   Trockenlauf). Ein M-Code ohne Ausfuehrungsmoeglichkeit und ein unbekannter M-Code werden nicht quittiert.
   G-04: Das Vakuum bleibt bei Abbruch und NOT-HALT gehalten (Werkstueckspannung), es geht mit M11, M30/M2 oder von Hand aus. *)
FUNCTION_BLOCK FB_MFunctions
VAR_INPUT
    nMCode      : INT;          (* aktive M-Funktion aus der CNC, 0 = keine *)
    bMStrobe    : BOOL;         (* CNC wartet auf Quittung *)
    bSpindleOk  : BOOL;
    bAuxOk      : BOOL;
    bReset      : BOOL;         (* Abbruch, R3/R4, NOT-HALT, Programmende: gehaltene M-Zustaende loeschen (ausser Vakuum) *)
    bOptStop    : BOOL;         (* optionaler Halt M1 aktiv (aus der HMI) *)
    bSpindleRunning : BOOL;     (* Spindel hat Drehzahl erreicht *)
    bSpindleSkip    : BOOL;     (* Einrichten/Trockenlauf: Spindel bewusst aus, M3/M4 ohne Start quittieren *)
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
    bUnknown      : BOOL;       (* unbekannter M-Code: nicht quittiert *)
END_VAR
VAR
    rtStrobe    : R_TRIG;
    bWaitSpindle: BOOL;         (* Quittung zurueckgehalten, bis die Spindel laeuft *)
    bBlockAck   : BOOL;         (* M-Code nicht ausfuehrbar: nie quittieren *)
END_VAR

rtStrobe(CLK := bMStrobe);
bUnknown := FALSE; bToolChangeReq := FALSE; bProgramHalt := FALSE;

IF bReset THEN
    bSpindleCw := FALSE; bSpindleCcw := FALSE; bExtraction := FALSE; bBlowAir := FALSE;
    bWaitSpindle := FALSE;      (* G-04: bVacuum bleibt gehalten *)
END_IF
IF NOT bMStrobe THEN
    bWaitSpindle := FALSE; bBlockAck := FALSE;
END_IF

IF rtStrobe.Q AND NOT bReset THEN
    CASE nMCode OF
        0:  bProgramHalt := TRUE;
        1:  IF bOptStop THEN bProgramHalt := TRUE; END_IF
        3:  IF bSpindleSkip THEN
                bSpindleCw := FALSE; bSpindleCcw := FALSE;     (* Spindel bewusst aus, Programm laeuft weiter *)
            ELSIF bSpindleOk THEN
                bSpindleCw := TRUE; bSpindleCcw := FALSE; bWaitSpindle := TRUE;
            ELSE
                bBlockAck := TRUE;                                (* nicht ausfuehrbar: nicht quittieren *)
            END_IF
        4:  IF bSpindleSkip THEN
                bSpindleCw := FALSE; bSpindleCcw := FALSE;
            ELSIF bSpindleOk THEN
                bSpindleCcw := TRUE; bSpindleCw := FALSE; bWaitSpindle := TRUE;
            ELSE
                bBlockAck := TRUE;
            END_IF
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
        bUnknown := TRUE; bBlockAck := TRUE;
    END_CASE
END_IF

IF bWaitSpindle AND (bSpindleRunning OR bSpindleSkip) THEN bWaitSpindle := FALSE; END_IF

(* Quittung bleibt stehen, bis die CNC den Strobe zurueckgenommen hat; zurueckgehalten bei M3/M4 bis die Spindel laeuft *)
bAck := bMStrobe AND NOT bWaitSpindle AND NOT bBlockAck;
END_FUNCTION_BLOCK
