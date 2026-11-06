{attribute 'qualified_only'}
{attribute 'strict'}
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
    HmiLinkLost       := 330,
    ParamMismatch     := 900   (* Maschinen-ID oder Version passt nicht *)
) INT;
END_TYPE
