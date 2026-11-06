(* Manueller Werkzeugwechsel (Anforderung 2.6.2). M6 mit Werkzeugnummer: Spindel aus, Aufforderung
   am Panel, Programm wartet auf Quittung. Kein Werkzeugwechsler im Umfang (offen: "SW"). *)
FUNCTION_BLOCK FB_ToolChange
VAR_INPUT
    bM6Request   : BOOL;      (* aus FB_MFunctions *)
    nToolNo      : UINT;      (* angeforderte Werkzeugnummer aus der CNC *)
    bSpindleStopped : BOOL;
    bConfirm     : BOOL;      (* Impuls HMI: Wechsel erledigt *)
    bAbort       : BOOL;
END_VAR
VAR_OUTPUT
    bRequest     : BOOL;      (* Aufforderung am Panel *)
    nRequestedTool : UINT;
    bHoldProgram : BOOL;      (* CNC wartet, bis quittiert *)
    bSpindleLock : BOOL;      (* Spindel gesperrt waehrend Wechsel *)
    bDoorRelease : BOOL;      (* Tuer darf geoeffnet werden: Werkzeugwechsel angefordert und Spindel steht. Eine offene Tuer bricht dann das Programm nicht ab. *)
END_VAR
VAR
    rtM6 : R_TRIG;
    rtConfirm : R_TRIG;
END_VAR

rtM6(CLK := bM6Request);
rtConfirm(CLK := bConfirm);

IF rtM6.Q THEN
    bRequest := TRUE; nRequestedTool := nToolNo;
END_IF
bHoldProgram := bRequest;
bSpindleLock := bRequest;
IF bRequest AND ((rtConfirm.Q AND bSpindleStopped) OR bAbort) THEN
    bRequest := FALSE;
END_IF

(* Tuerfreigabe fuer den Werkzeugwechsel: erst bei Spindelstillstand. Die Abschaltung der Antriebe macht weiter die
   feste Verdrahtung (Pilz). Die SPS entscheidet nur zwischen Halt (Wechsel) und Abbruch. [offen] Risikobeurteilung:
   Zustimmtaster, Schluesselschalter, sichere Spindelstillstandsueberwachung. *)
bDoorRelease := bRequest AND bSpindleStopped;
END_FUNCTION_BLOCK
