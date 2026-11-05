(* P-016 Gemeinsame Typen. Alle Maschinen M1 bis M4 nutzen diesen Stand. *)

TYPE E_OpMode :
(
    Hand  := 0,   (* Tippen, Handrad, Referenzieren *)
    Auto  := 1,   (* Programmbetrieb *)
    Setup := 2    (* Einrichten/Test: Spindel gesperrt, Einzelsatz moeglich *)
) INT;
END_TYPE

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

TYPE E_AlarmId :
(
    None              := 0,
    SafetyOpen        := 100,  (* Sicherheitskreis offen / NOT-HALT *)
    DoorOpen          := 101,
    AirPressureLow    := 110,
    ExtractionFault   := 120,
    SpindleFuFault    := 200,
    SpindlePtcTrip    := 201,
    SpindleNoFeedback := 202,
    SpindleLockedSetup:= 203,
    AxisDriveFault    := 300,
    AxisFollowingErr  := 301,
    HwLimitHit        := 302,
    FieldbusLost      := 310,
    HomingLost        := 320,
    ParamMismatch     := 900   (* Maschinen-ID oder Version passt nicht *)
) INT;
END_TYPE

(* Eine Meldung aus der Meldeliste, Index = E_AlarmSlot *)
TYPE ST_Alarm :
STRUCT
    nId     : INT;
    eClass  : E_FaultClass;
    bActive : BOOL;          (* Ursache besteht *)
    bLatched: BOOL;          (* R3/R4 gespeichert, wartet auf Quittierung *)
END_STRUCT
END_TYPE

TYPE E_HomeState :
(
    Open := 0,
    Running := 1,
    Done := 2,
    Error := 3
) INT;
END_TYPE
