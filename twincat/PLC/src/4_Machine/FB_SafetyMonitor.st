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
    bLatched      : BOOL;      (* Wiederanlauf wartet auf Quittierung *)
END_VAR
VAR
    rtAck       : R_TRIG;
    bWasOk      : BOOL;
END_VAR

rtAck(CLK := bAck);
bSafetyOk := bRelayFeedbackOk AND bDoorClosed;

IF NOT bSafetyOk OR NOT bFieldbusOk THEN
    bLatched := TRUE;           (* Wiederanlauf nie automatisch *)
END_IF
IF bLatched AND bSafetyOk AND bFieldbusOk AND rtAck.Q THEN
    bLatched := FALSE;
END_IF

bDrivesAllowed := bSafetyOk AND bFieldbusOk AND NOT bLatched;
END_FUNCTION_BLOCK
