(* Eine Meldung aus der Meldeliste, Index = E_AlarmSlot *)
TYPE ST_Alarm :
STRUCT
    nId     : INT;
    eClass  : E_FaultClass;
    bActive : BOOL;          (* Ursache besteht *)
    bLatched: BOOL;          (* R3/R4 gespeichert, wartet auf Quittierung *)
END_STRUCT
END_TYPE
