(* TcUnit-Tests. Noch nicht ausgefuehrt, siehe test/README.md. *)
{attribute 'no_check'}
FUNCTION_BLOCK FB_Test_SafetyMonitor EXTENDS TcUnit.FB_TestSuite
VAR
    fb : FB_SafetyMonitor;
END_VAR

Wiederanlauf_nie_automatisch();
Reset_Fb();
Tuer_offen_sperrt();

METHOD Reset_Fb
fb.bRelayFeedbackOk := TRUE; fb.bDoorClosed := TRUE; fb.bFieldbusOk := TRUE; fb.bAirOk := TRUE; fb.bAck := FALSE;
fb(); fb.bAck := TRUE; fb(); fb.bAck := FALSE; fb();
END_METHOD

METHOD Wiederanlauf_nie_automatisch
TEST('Wiederanlauf_nie_automatisch');
Reset_Fb();
AssertTrue(fb.bDrivesAllowed, 'Nach Quittierung frei');
fb.bRelayFeedbackOk := FALSE; fb();
AssertFalse(fb.bDrivesAllowed, 'Relais offen sperrt');
fb.bRelayFeedbackOk := TRUE; fb();
AssertFalse(fb.bDrivesAllowed, 'Relais wieder zu, ohne Quittung bleibt gesperrt');
fb.bAck := TRUE; fb(); fb.bAck := FALSE; fb();
AssertTrue(fb.bDrivesAllowed, 'Mit Quittung frei');
TEST_FINISHED();
END_METHOD

METHOD Tuer_offen_sperrt
TEST('Tuer_offen_sperrt');
Reset_Fb();
fb.bDoorClosed := FALSE; fb();
AssertFalse(fb.bSafetyOk, 'Tuer offen');
AssertFalse(fb.bDrivesAllowed, 'Tuer offen sperrt Freigabe');
TEST_FINISHED();
END_METHOD
