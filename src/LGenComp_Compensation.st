USING Siemens.Simatic.MemoryAccess;
USING Siemens.Simatic.MotionControl.Native;
USING System.Math;
NAMESPACE Simatic.Ax.LGenComp
    ///===============================================================================
    /// SIEMENS AG / (c)Copyright 2025
    ///-------------------------------------------------------------------------------
    /// Title:            LGenComp_Compensation
    /// Comment/Function: Function block for compensating an axis position by a
    ///                   compensation value via encoder increment adjustment.
    /// Library/Family:   LGenComp
    /// Author:           APC Erlangen
    /// Engineering:      SIMATIC AX
    /// Requirements:     Needs to be called in the OB MC-PreServo
    ///-------------------------------------------------------------------------------
    ///===============================================================================
    FUNCTION_BLOCK LGenComp_Compensation
        VAR_INPUT
            enable : BOOL;   // TRUE: Enable functionality of FB
            axis  : REF_TO TO_PositioningAxis;   // Technology object, also supports TO_SynchronousAxis
            compensationValue : LREAL;   // Compensation value
            encoderNumber : UINT := UINT#1;   // Encoder number (1..4)  for which the compensation is performed. Default: 1
            encoderOffsetG1_XIST1 : UINT := UINT#12;   // Byte offset of G1_XIST1 in PROFIdrive telegrams. Default: 12 for TEL105
            activationCycles : UINT := UINT#1000;
        END_VAR

        VAR_OUTPUT
            encoderIncrements : UDINT;   // Encoder value without compensation
            encoderPosition : LREAL;   // Encoder position without compensatoin
            compensationIncrements : DINT;   // Additional encoder increments based on compensation
            valid  : BOOL;   // TRUE: Valid set of output values available at the FB
            busy  : BOOL;   // TRUE: FB is not finished and new output values can be expected
            error  : BOOL;   // TRUE: An error occurred during the execution of the FB
            status  : LGenComp_CompensationStatus := LGenComp_CompensationStatus#STATUS_NO_CALL;   // 16#0000 - 16#7FFF: Status of the FB, 16#8000 - 16#FFFF: Error identification
        END_VAR

        VAR
            statEncoderIncrements : UDINT;           // Raw encoder value without compensation applied
            statEncoderPosition : LREAL;             // Encoder position without compensation
            statCompensationIncrements : DINT;       // Calculated compensation in encoder increments
            statEncNo : UINT;                        // Currently configured encoder number
            statCompValue : LREAL;                   // Current compensation value (ramped during activation/deactivation)
            statCompIncrementValue : LREAL;          // Compensation value converted to encoder increments
            statFactorIncrements : LREAL;            // Conversion factor from position units to encoder increments
            statG1_XIST1 : DWORD;                    // PROFIdrive G1_XIST1 encoder value from telegram
            statActivationCycles : UINT;             // Configured number of cycles for gradual activation
            statRampCycles : UINT;                   // Target cycle count for ramping calculations
            statEnableOld  : BOOL;                   // Old value of 'enable' input for edge detection
            statValid  : BOOL;                       // Static value for output 'valid'
            statBusy  : BOOL;                        // Static value for output 'busy'
            statError  : BOOL;                       // Static value for output 'error'
            statErrorUserCleared  : BOOL;            // Error occurred that can only be solved by user; rising edge at enable input necessary
            statStatus  : LGenComp_CompensationStatus := LGenComp_CompensationStatus#STATUS_NO_CALL;   // Static value for output 'status'
            statFBState  : DINT := NO_PROCESSING;    // State in the state machine of the FB
            statDisablingCompleted  : BOOL;          // TRUE: Disabling has been completed
            statCycleCounter  : UINT;                // Current cycle count for ramping compensation (0 to statRampCycles)
            statSensorAddressIn : LGenComp_typeSensorAddressIn;  // Memory address for encoder telegram data
            statAxis : REF_TO TO_PositioningAxis;    // Stored axis reference
            statReadResult : BOOL;                   // Result of ReadMemory operation
        END_VAR

        VAR_TEMP
            tempEnable : BOOL;                       // Temporary value for input 'enable'
            tempStepsPerRevolutionG1_XIST1 : LREAL;  // Encoder steps per revolution including fine resolution
            tempUnitsPerRevolution : LREAL;          // Units per revolution (degrees for rotary, mm for linear)
        END_VAR

        VAR CONSTANT
            ROTARY_AXIS : INT := 1;                  // Constant identifying rotary axis type
            MOUNTING_MOTOR_SHAFT : DINT := DINT#0;   // Encoder mounted on motor shaft
            MOUNTING_LOAD_SIDE : DINT := DINT#1;     // Encoder mounted on load side
            MOUNTING_EXT_MEAS_SYS: DINT := DINT#2;   // External measuring system
            NO_PROCESSING : DINT := DINT#0;          // State: No processing active
            ENABLING : DINT := DINT#10;              // State: Enabling and initializing
            PROCESSING : DINT := DINT#50;            // State: Active compensation
            DISABLING : DINT := DINT#90;             // State: Gradual deactivation
            ERR : DINT := DINT#200;                  // State: Error occurred
        END_VAR

        // Create process image of enable input
        tempEnable := enable;

        // ============================================================================
        // ENABLING/DISABLING LOGIC
        // ============================================================================

        // Rising edge on enable input: Start function block
        IF (tempEnable = TRUE) AND NOT statEnableOld AND (statStatus = LGenComp_CompensationStatus#STATUS_NO_CALL) THEN
            // Validate axis reference FIRST before any initialization
            IF axis = NULL THEN
                // Error: Invalid axis reference
                statErrorUserCleared := TRUE;
                statValid := FALSE;
                statBusy := FALSE;
                statStatus := LGenComp_CompensationStatus#ERR_NULL_REFERENCE;
                statFBState := ERR;
                RETURN;
            ELSE
                // Store valid axis reference
                statAxis := axis;
            END_IF;

            // Initialize function block for first execution
            statValid := TRUE;
            statBusy := TRUE;
            statError := FALSE;
            statErrorUserCleared := FALSE;
            statStatus := LGenComp_CompensationStatus#STATUS_FIRST_CALL;

            // Store activation ramp configuration
            statActivationCycles := activationCycles;

            // Transition to ENABLING state
            statFBState := ENABLING;
            statDisablingCompleted := FALSE;

        // Falling edge on enable input: Stop function block
        ELSIF (tempEnable = FALSE) AND (statEnableOld = TRUE) THEN
            IF statFBState = PROCESSING THEN
                // Start gradual deactivation ramp
                statFBState := DISABLING;
            ELSE
                // Not in PROCESSING state, skip DISABLING and immediately complete
                statDisablingCompleted := TRUE;
            END_IF;

        // Update status to SUBSEQUENT_CALL after initial cycle
        ELSIF (statStatus = LGenComp_CompensationStatus#STATUS_FIRST_CALL) THEN
            statStatus := LGenComp_CompensationStatus#STATUS_SUBSEQUENT_CALL;
        END_IF;

        // Store enable input for edge detection
        statEnableOld := tempEnable;

        // Early exit if function block is not active
        IF (statStatus = LGenComp_CompensationStatus#STATUS_NO_CALL) THEN
            RETURN;
        END_IF;

        // ============================================================================
        // STATE MACHINE
        // ============================================================================

        CASE statFBState OF
            NO_PROCESSING:
                // No processing active - idle state
                ;

            ENABLING:
                // Validate and configure encoder, calculate conversion factors
                // Check if encoder number has changed from previous initialization
                IF encoderNumber <> statEncNo THEN
                    statEncNo := encoderNumber;

                    // Validate encoder number range (1-4)
                    IF statEncNo < UINT#1 OR statEncNo > UINT#4 THEN
                        statErrorUserCleared := TRUE;
                        statValid := FALSE;
                        statEncoderIncrements := UINT#0;
                        statStatus := LGenComp_CompensationStatus#ERR_INVALID_ENC;
                        statFBState := ERR;
                    // Check if encoder exists in axis configuration
                    ELSIF NOT statAxis^.Sensor[statEncNo].Existent THEN
                        statErrorUserCleared := TRUE;
                        statValid := FALSE;
                        statEncoderIncrements := UINT#0;
                        statStatus := LGenComp_CompensationStatus#ERR_NO_ENC;
                        statFBState := ERR;
                    END_IF;

                    // Get PROFIdrive telegram memory address for G1_XIST1 encoder value
                    statSensorAddressIn.area := statAxis^.Sensor[statEncNo]._Interface.AddressIn.AREA;
                    statSensorAddressIn.dbNumber := statAxis^.Sensor[statEncNo]._Interface.AddressIn.DB_NUMBER;
                    statSensorAddressIn.offset := TO_DINT(statAxis^.Sensor[statEncNo]._Interface.AddressIn.OFFSET / UDINT#8 + encoderOffsetG1_XIST1);

                    // Calculate conversion factor from position units to encoder increments
                    // Apply fine resolution scaling to base steps per revolution
                    tempStepsPerRevolutionG1_XIST1 := statAxis^.Sensor[statEncNo].Parameter.StepsPerRevolution * (2.0 ** statAxis^.Sensor[statEncNo].Parameter.FineResolutionXist1);

                    // Invert if encoder or actor direction is inverted (XOR: only one inverted)
                    IF statAxis^.Sensor[statEncNo].InverseDirection XOR statAxis^.Actor.InverseDirection THEN
                        tempStepsPerRevolutionG1_XIST1 := -1.0 * tempStepsPerRevolutionG1_XIST1;
                    END_IF;

                    // Determine units per revolution based on axis type
                    IF statAxis^.Properties.MotionType = ROTARY_AXIS THEN
                        tempUnitsPerRevolution := 360.0;  // Degrees per revolution for rotary axis
                    ELSE
                        tempUnitsPerRevolution := statAxis^.Mechanics.LeadScrew;  // mm per revolution for linear axis
                    END_IF;

                    // Calculate increment conversion factor based on encoder mounting configuration
                    CASE statAxis^.Sensor[statEncNo].MountingMode OF
                        MOUNTING_MOTOR_SHAFT:
                            // Motor shaft: Account for gear ratio between motor and load
                            statFactorIncrements := tempStepsPerRevolutionG1_XIST1 / statAxis^.LoadGear.Denominator * statAxis^.LoadGear.Numerator / tempUnitsPerRevolution;
                        MOUNTING_LOAD_SIDE:
                            // Load side: Direct conversion without gear ratio
                            statFactorIncrements := tempStepsPerRevolutionG1_XIST1 / tempUnitsPerRevolution;
                        MOUNTING_EXT_MEAS_SYS:
                            // External measuring system: Use configured distance per revolution
                            statFactorIncrements := tempStepsPerRevolutionG1_XIST1 / statAxis^.Sensor[statEncNo].Parameter.DistancePerRevolution;
                        ELSE
                            // Unsupported mounting mode
                            statErrorUserCleared := TRUE;
                            statValid := FALSE;
                            statStatus := LGenComp_CompensationStatus#ERR_MOUNTING_MODE;
                            statFBState := ERR;
                    END_CASE;
                END_IF;

                // Initialize activation ramp cycle counter
                IF statActivationCycles <> statRampCycles THEN
                    statRampCycles := Max(statActivationCycles, UINT#1);
                END_IF;

                // Ramp up cycle counter for gradual compensation activation
                statCycleCounter := MIN(statCycleCounter + UINT#1, statRampCycles);

                // Transition to PROCESSING when ramp-up is complete
                IF (statCycleCounter = statRampCycles) THEN
                    statFBState := PROCESSING;
                END_IF;

            PROCESSING:
                // Active compensation state - compensation is fully applied
                ;

            DISABLING:
                // Gradual deactivation: Ramp down compensation over configured cycles
                statCycleCounter := Max(statCycleCounter - UINT#1, UINT#0);

                // Mark disabling as complete when ramp-down reaches zero
                IF statCycleCounter = UINT#0 THEN
                    statDisablingCompleted := TRUE;
                END_IF;

            ERR:
                // Error state - no processing
                ;

            ELSE
                // Undefined state reached - set error
                statStatus := LGenComp_CompensationStatus#ERR_UNDEFINED_STATE;
                statErrorUserCleared := TRUE;
        END_CASE;

        // ============================================================================
        // COMPENSATION PROCESSING
        // ============================================================================

        IF ((statFBState = ENABLING) OR (statFBState = PROCESSING) OR (statFBState = DISABLING)) THEN
            // Read actual encoder value from PROFIdrive telegram memory
            statReadResult := ReadMemory(statSensorAddressIn.area, statSensorAddressIn.offset, statG1_XIST1);

            // Calculate uncompensated encoder position
            statEncoderPosition := statAxis^.StatusSensor[statEncNo].Position - statCompValue;
            statEncoderIncrements := TO_UDINT(statG1_XIST1);

            // Calculate ramped compensation value (0% to 100% during ENABLING, 100% to 0% during DISABLING)
            statCompValue := compensationValue * statCycleCounter / statRampCycles;

            IF statCompValue <> 0.0 THEN
                // Convert compensation from position units to encoder increments
                statCompIncrementValue := statCompValue * statFactorIncrements;
                statCompensationIncrements := TO_DINT(statCompIncrementValue);

                // Apply compensation by modifying encoder value
                statG1_XIST1 := TO_DWORD(TO_DINT(statG1_XIST1) + statCompensationIncrements);

                // Write compensated value back to PROFIdrive telegram memory
                // Note: WriteMemory in SIMATIC AX doesn't return status via ENO
                WriteMemory(statSensorAddressIn.area, statSensorAddressIn.offset, statG1_XIST1);
            ELSE
                statCompensationIncrements := 0;
            END_IF;
        END_IF;

        // ============================================================================
        // OUTPUT HANDLING
        // ============================================================================

        IF (statDisablingCompleted = TRUE) THEN
            // Reset all outputs and state after successful disabling
            statValid := FALSE;
            statBusy := FALSE;
            statError := FALSE;
            statErrorUserCleared := FALSE;
            statStatus := LGenComp_CompensationStatus#STATUS_NO_CALL;
            statFBState := NO_PROCESSING;
            statAxis := NULL;

        ELSIF (statErrorUserCleared = TRUE) AND (statError = FALSE) THEN
            // Error state that requires user intervention (rising edge on enable to clear)
            statValid := FALSE;
            statBusy := FALSE;
            statError := TRUE;
            statFBState := NO_PROCESSING;
        END_IF;

        // Copy internal states to output variables
        status := statStatus;
        error := statError;
        busy := statBusy;
        valid := statValid;

        encoderIncrements := statEncoderIncrements;
        encoderPosition := statEncoderPosition;
        compensationIncrements := statCompensationIncrements;
    END_FUNCTION_BLOCK
END_NAMESPACE