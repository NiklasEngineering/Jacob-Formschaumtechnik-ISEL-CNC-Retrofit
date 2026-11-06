(* Prueft beim Start Maschinen-ID und Softwareversion. Passt etwas nicht, bleibt die Maschine gesperrt
   (Meldung 900, R4). Anforderungen 2.11.4 und 2.11.5. *)
FUNCTION_BLOCK FB_ParamCheck
VAR_INPUT
    nIdExpected   : UINT;
    nIdLoaded     : UINT;
    sVerExpected  : STRING(15);
    sVerRunning   : STRING(15);
    bParamsLoaded : BOOL;
END_VAR
VAR_OUTPUT
    bMismatch : BOOL;
END_VAR

bMismatch := NOT bParamsLoaded OR (nIdLoaded <> nIdExpected) OR (sVerExpected <> sVerRunning);
END_FUNCTION_BLOCK
