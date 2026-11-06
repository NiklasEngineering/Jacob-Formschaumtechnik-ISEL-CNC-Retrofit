(* Liest den Status der festen Sicherheitsverdrahtung (Pilz-Relais, Tuerkontakt) und bildet
   die SPS-Seite der Antriebsfreigabe. Die SPS kann nur zusaetzlich sperren, nie freigeben,
   was das Relais sperrt. Das ist KEINE Sicherheitsfunktion im Sinne ISO 13849.
   Ruhestromprinzip: FALSE = Sicherheitskreis offen. *)
FUNCTION_BLOCK FB_SafetyMonitor
VAR_INPUT
    bRelayFeedbackOk : BOOL;   (* Rueckmeldekontakt Sicherheitsrelais *)
    bDoorClosed      : BOOL;   (* Statussignal Tuer *)
    bFieldbusOk      : BOOL;
    bAck             : BOOL;   (* Quittierung, Impuls *)
    bAirOk           : BOOL;
END_VAR
VAR_OUTPUT
    bSafetyOk     : BOOL;      (* Sicherheitskreis geschlossen *)
    bDrivesAllowed: BOOL;      (* SPS-Freigabe der Antriebe, nur mit Quittierung nach Ausloesung *)
    bLatched      : BOOL := TRUE;   (* Wiederanlauf wartet auf Quittierung; nach dem Anlauf immer TRUE (Befund 7) *)
END_VAR
VAR
    rtAck       : R_TRIG;
    bWasOk      : BOOL;
END_VAR

rtAck(CLK := bAck);
(* Befund 19: Feldbusausfall zaehlt als offener Sicherheitskreis (Eingaenge koennten auf dem letzten Wert stehen) *)
bSafetyOk := bRelayFeedbackOk AND bDoorClosed AND bFieldbusOk;

IF NOT bSafetyOk OR NOT bFieldbusOk THEN
    bLatched := TRUE;           (* Wiederanlauf nie automatisch *)
END_IF
IF bLatched AND bSafetyOk AND bFieldbusOk AND rtAck.Q THEN
    bLatched := FALSE;
END_IF

bDrivesAllowed := bSafetyOk AND bFieldbusOk AND NOT bLatched;
END_FUNCTION_BLOCK
