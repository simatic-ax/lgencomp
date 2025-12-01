# LGenComp_Compensation

## Principle of operation

The function block `LGenComp_Compensation` is the main part of the block library LGenComp and manages the compensation of the technology object position based on directly applying a corrective value to the encoder increments.

The compensation is applied to the `G1_XIST1` field in the PROFIdrive telegram.

For Telegram 105, the `G1_XIST1` value is transferred at an offset of 12 bytes, whereas for Telegram 5 the offset is 10 bytes.
<details>
    <summary> Telegram 5 structure </summary>

        Each process data (PZD) consists of two bytes.

        Control → Converter

        | Process data | Signal | Explanation |
        |--------------|--------|-------------|
        | PZD01 | STW1 | Control word 1 |
        | PZD02 | NSOLL_B | 32-bit speed setpoint |
        | PZD03 | NSOLL_B | 32-bit speed setpoint |
        | PZD04 | STW2 | Control word 2 |
        | PZD05 | G1_STW | Control word for encoder 1 |
        | PZD06 | XERR | Position controller deviation |
        | PZD07 | XERR | Position controller deviation |
        | PZD08 | KPC | Gain factor for the position controller |
        | PZD09 | KPC | Gain factor for the position controller |

        Converter → Control

        | Process data | Signal | Explanation |
        |--------------|--------|-------------|
        | PZD01 | ZSW1 | Status word 1 |
        | PZD02 | NIST_B | Speed actual value 32-bit |
        | PZD03 | NIST_B | Speed actual value 32-bit |
        | PZD04 | ZSW2 | Status word 2 |
        | PZD05 | G1_ZSW | Status word for encoder 1 |
        | PZD06 | G1_XIST1 | Position actual value 1 from encoder 1 |
        | PZD07 | G1_XIST1 | Position actual value 1 from encoder 1 |
        | PZD08 | G1_XIST2 | Position actual value 2 from encoder 1 |
        | PZD09 | G1_XIST2 | Position actual value 2 from encoder 1 |
</details>

<details>
    <summary> Telegram 105 structure </summary>

        Each process data (PZD) consists of two bytes.

        Control → Converter

        | Process data | Signal | Explanation |
        |--------------|--------|-------------|
        | PZD01 | STW1 | Control word 1 |
        | PZD02 | NSOLL_B | 32-bit speed setpoint |
        | PZD03 | NSOLL_B | 32-bit speed setpoint |
        | PZD04 | STW2 | Control word 2 |
        | PZD05 | MOMRED | Torque reduction |
        | PZD06 | G1_STW | Control word for encoder 1 |
        | PZD07 | XERR | Position controller deviation |
        | PZD08 | XERR | Position controller deviation |
        | PZD09 | KPC | Gain factor for the position controller |
        | PZD10 | KPC | Gain factor for the position controller |

        Converter → Control

        | Process data | Signal | Explanation |
        |--------------|--------|-------------|
        | PZD01 | ZSW1 | Status word 1 |
        | PZD02 | NIST_B | Speed actual value 32-bit |
        | PZD03 | NIST_B | Speed actual value 32-bit |
        | PZD04 | ZSW2 | Status word 2 |
        | PZD05 | MELDW | Message word |
        | PZD06 | G1_ZSW | Status word for encoder 1 |
        | PZD07 | G1_XIST1 | Position actual value 1 from encoder 1 |
        | PZD08 | G1_XIST1 | Position actual value 1 from encoder 1 |
        | PZD09 | G1_XIST2 | Position actual value 2 from encoder 1 |
        | PZD10 | G1_XIST2 | Position actual value 2 from encoder 1 |
</details><br>

The subsequent user program is then operated using the corrected encoder positions. Therefore, the function block must be called in an `MC_PreServo` task from the Siemens.Simatic.Tasks library.

## Interface

### Input Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | BOOL | TRUE: Enable functionality of FB |
| axis | REF_TO TO_PositioningAxis | Technology object, also supports TO_SynchronousAxis |
| compensationValue | LREAL | Compensation value |
| encoderNumber | UINT | Encoder number (1..4) for which the compensation is performed. Default: 1 |
| encoderOffsetG1_XIST1 | UINT | Byte offset of G1_XIST1 in PROFIdrive telegrams. Default: 12 for TEL105 |
| activationCycles | UINT | Number of cycles until the full compensation value is applied at the axis |

### Output Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| encoderIncrements | UDINT | Encoder value without compensation |
| encoderPosition | LREAL | Encoder position without compensation |
| compensationIncrements | DINT | Additional encoder increments based on compensation |
| valid | BOOL | TRUE: Valid set of output values available at the FB |
| busy | BOOL | TRUE: FB is not finished and new output values can be expected |
| error | BOOL | TRUE: An error occurred during the execution of the FB |
| status | [LGenComp_CompensationStatus](../constants/LGenComp_CompensationStatusCodes.md) | 16#0000 - 16#7FFF: Status of the FB, 16#8000 - 16#FFFF: Error identification |

### Status and error codes

| Constant | Value | Description |
|-----------|------|-------------|
| STATUS_NO_CALL | WORD#16#7000 | No job being currently processed |
| STATUS_FIRST_CALL | WORD#16#7001 | First call after incoming new job (rising edge 'enable') |
| STATUS_SUBSEQUENT_CALL | WORD#16#7002 | Subsequent call during active processing without further details |
| ERR_NO_ENC | WORD#16#8200 | Initialization error: Encoder not present |
| ERR_INVALID_ENC | WORD#16#8201 | Initialization error: Encoder number invalid |
| ERR_MOUNTING_MODE | WORD#16#8202 | Initialization error: Encoder mounting mode invalid |
| ERR_NULL_REFERENCE | WORD#16#8400 | Axis reference is NULL |
| ERR_UNDEFINED_STATE | WORD#16#8600 | Error due to an undefined state in state machine |
