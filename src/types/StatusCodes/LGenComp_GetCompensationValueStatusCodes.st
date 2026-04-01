NAMESPACE Simatic.Ax.LGenComp
    TYPE
        GetCompensationValueStatus : WORD (
            /// Valid execution
            STATE_VALID := WORD#16#7000,
            /// lookup outside of array boundaries
            WAR_RANGE_CLAMPING_ACTIVE := WORD#16#7F00
            ) := STATE_VALID;
    END_TYPE
END_NAMESPACE