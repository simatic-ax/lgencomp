# LGenComp_GetCompensationValueLinear

## Description

The function `GetCompensationValueLinear` can be used to fetch a y-value (compensation value) from a compensation array of type [`LGenComp_typeCompensationElement`](../types/LGenComp_typeCompensationElement.md) for a given input value.

Given an input position (xValue) and a compensation array, the function performs a binary search to locate the two adjacent data points that bracket the input value, then applies linear interpolation to calculate the precise compensation value.

## Interface

### Input Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `xValue` | LREAL | Input position value for compensation lookup |
| `compensationArray` | ARRAY[*] of `LGenComp_typeCompensationElement` | Compensation table with x/y value pairs, must be sorted by `xValue` |

### Output Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | [LGenComp_GetCompensationValueStatus](../constants/LGenComp_GetCompensationValueStatusCodes.md) | Status information about the function execution |

### Return Value

| Type | Description |
|------|-------------|
| LREAL | Interpolated compensation value corresponding to the input `xValue` |

## Status Codes

| Constant | Value | Description |
|--------|---------|-------|
| STATE_VALID |  WORD#16#7000 | Valid execution, input was within array range |
| WAR_RANGE_CLAMPING_ACTIVE |  WORD#16#7F00 | Input value was outside table boundaries and was clamped |

## Usage Notes

- The compensation array must be sorted by xValue (either ascending or descending)
- For single-element arrays, the function returns that element's yValue
- If input xValue is outside the table range, it will be clamped and a warning status returned
- The function automatically detects array sort order (ascending/descending)
