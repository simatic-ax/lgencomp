NAMESPACE Simatic.Ax.LGenComp
    TYPE
        LGenComp_GetCompensationValueStatus : WORD (
            STATE_VALID := WORD#16#7000,        // Valid execution
            WAR_RANGE_CLAMPING_ACTIVE := WORD#16#7F00 // lookup outside of array boundaries
            ) := STATE_VALID;
    END_TYPE
END_NAMESPACE