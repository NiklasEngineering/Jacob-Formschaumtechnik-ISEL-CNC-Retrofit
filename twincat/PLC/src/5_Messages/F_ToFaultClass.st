FUNCTION F_ToFaultClass : E_FaultClass
VAR_INPUT
    nClass : INT;
END_VAR

CASE nClass OF
    0: F_ToFaultClass := E_FaultClass.R0_Info;
    1: F_ToFaultClass := E_FaultClass.R1_Warning;
    2: F_ToFaultClass := E_FaultClass.R2_FeedHold;
    3: F_ToFaultClass := E_FaultClass.R3_Abort;
ELSE
    F_ToFaultClass := E_FaultClass.R4_DrivesOff;   (* unbekannt: sicherste Reaktion *)
END_CASE
END_FUNCTION
