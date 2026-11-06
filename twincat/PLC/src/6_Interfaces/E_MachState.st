{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_MachState :
(
    Stopped     := 0,  (* Antriebe aus, kein Fehler *)
    Idle        := 1,  (* Antriebe bereit, kein Programm *)
    Execute     := 2,  (* Programm laeuft *)
    Held        := 3,  (* Vorschubhalt, Programm fortsetzbar *)
    Aborted     := 4,  (* Programm abgebrochen, Reset noetig *)
    EStop       := 5,  (* Sicherheitskreis offen *)
    Fault       := 6   (* Fehler R3/R4 aktiv, Quittierung noetig *)
) INT;
END_TYPE
