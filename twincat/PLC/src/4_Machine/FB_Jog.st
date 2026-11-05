(* Tippbetrieb aus der HMI (Anforderungen 2.3.1 und 2.3.2). Nur mit Lebenszeichen der HMI, nur
   in Betriebsart Hand. Bleibt das Lebenszeichen aus oder wird die Taste losgelassen, endet die Anforderung.
   Die Bewegung selbst fordert die CNC an. *)
FUNCTION_BLOCK FB_Jog
VAR_INPUT
    bJogOk       : BOOL;      (* aus FB_Interlocks *)
    bPlus        : BOOL;
    bMinus       : BOOL;
    nAxis        : USINT;     (* 1=X, 2=Y, 3=Z *)
    bRapid       : BOOL;
    nHeartbeat   : UINT;
    tHmiTimeout  : TIME;
END_VAR
VAR_OUTPUT
    bJogPlusReq  : BOOL;
    bJogMinusReq : BOOL;
    nAxisReq     : USINT;
    bRapidReq    : BOOL;
    bHmiLinkOk   : BOOL;
END_VAR
VAR
    nLastHb  : UINT;
    tonLink  : TON;
END_VAR

(* Lebenszeichen: Aenderung innerhalb tHmiTimeout *)
IF nHeartbeat <> nLastHb THEN
    nLastHb := nHeartbeat;
    tonLink(IN := FALSE);
END_IF
tonLink(IN := TRUE, PT := tHmiTimeout);
bHmiLinkOk := NOT tonLink.Q;

bJogPlusReq  := bJogOk AND bHmiLinkOk AND bPlus AND NOT bMinus AND nAxis >= 1 AND nAxis <= 3;
bJogMinusReq := bJogOk AND bHmiLinkOk AND bMinus AND NOT bPlus AND nAxis >= 1 AND nAxis <= 3;
nAxisReq  := nAxis;
bRapidReq := bRapid AND (bJogPlusReq OR bJogMinusReq);
END_FUNCTION_BLOCK
