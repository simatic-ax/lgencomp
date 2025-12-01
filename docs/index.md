# LGenComp Library for SIMATIC AX

## Overview

The LGenComp (Generic Compensation) library provides functionality to compensate the position of a SIMATIC Motion Control technology object based on a compensation table.
Different influences and the resulting deviations can be addressed, such as:

- Mechanical sag
- Leadscrew imperfections
- Angularity errors
- temperature-related deviations

The library operates by directly manipulating encoder increments using user-defined compensation tables (arrays) with linear interpolation between data points.

## Library Structure

The library is organized into the following main components:

### Compensation Function Block

- [`LGenComp_Compensation`](./function-blocks/LGenComp_Compensation.md): Function block for compensating an axis position by a compensation value via encoder increment adjustment.

### Compensation value retrieval

- [`LGenComp_GetCompensationValueLinear`](./functions/LGenComp_GetCompensationValueLinear.md): Function for retrieving a compensation value from a compensation array for a given x-value with a linear interpolation.

### Data Types

- [`LGenComp_typeCompensationElement`](./types/LGenComp_typeCompensationElement.md)
- [`LGenComp_typeSensorAddressIn`](./types/LGenComp_typeSensorAddressIn.md)

### Constants

- [`LGenComp_GetCompensationValueStatusCodes`](./constants/LGenComp_GetCompensationValueStatusCodes.md): Status codes for the compensation value retrieval function.
- [`LGenComp_CompensationStatusCodes`](./constants/LGenComp_CompensationStatusCodes.md): Status codes for the compensation function block.

## Migration from TIA Portal

This library has been migrated from TIA Portal to SIMATIC AX. The functionality remains the same, but the programming model has been adapted to SIMATIC AX. Key differences include:

- Namespace: The library now uses the `Simatic.Ax.LGenComp` namespace
- Data types: The data types have been adapted to SIMATIC AX conventions
- Application sizing: The SIMATIC AX library uses a variable lenght `ARRAY[*] of LGenComp_typeCompensationElement` to retrieve the compensation value from arrays of user-defined sizes
