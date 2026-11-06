{attribute 'qualified_only'}
{attribute 'strict'}
TYPE E_OpMode :
(
    Hand  := 0,   (* Tippen, Handrad, Referenzieren *)
    Auto  := 1,   (* Programmbetrieb *)
    Setup := 2    (* Einrichten/Test: Spindel gesperrt, Einzelsatz moeglich *)
) INT;
END_TYPE
