(* Meldekatalog: Slot-Nummer = Index in aCond von FB_AlarmList.
   Klassen siehe E_FaultClass. Texte und Abhilfe stehen in docs/Meldeliste.md (HMI-Thread). *)
TYPE E_AlarmSlot :
(
    SafetyOpen := 0,
    DoorOpen := 1,
    AirPressureLow := 2,
    ExtractionFault := 3,
    SpindleFuFault := 4,
    SpindlePtcTrip := 5,
    SpindleNoFeedback := 6,
    SpindleLockedSetup := 7,
    AxisDriveFault := 8,
    AxisFollowingErr := 9,
    HwLimitHit := 10,
    FieldbusLost := 11,
    HomingLost := 12,
    HmiLinkLost := 13,
    ParamMismatch := 14
) INT;
END_TYPE
