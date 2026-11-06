{attribute 'qualified_only'}
{attribute 'strict'}
(* Fehlerreaktionsklassen, siehe docs/Architektur_Sicherheit.md *)
TYPE E_FaultClass :
(
    R0_Info     := 0,  (* nur anzeigen *)
    R1_Warning  := 1,  (* anzeigen, Betrieb laeuft weiter *)
    R2_FeedHold := 2,  (* gefuehrter Vorschubhalt, fortsetzbar *)
    R3_Abort    := 3,  (* gefuehrter Halt, Spindel aus, Programm beendet *)
    R4_DrivesOff := 4  (* Reglerfreigabe weg, Referenz verloren *)
) INT;
END_TYPE
