# LGenComp_typeCompensationElement

## Description

Data structure representing a single compensation point in a 2D lookup table. Used to define the relationship between position (x-value) and the corresponding compensation value (y-value) for interpolation-based compensation calculations.

## Structure

| Field | Type | Description |
|--------|------|-------------|
| xValue | LREAL | Position or independent variable (e.g., axis position in degrees or mm) |
| yValue | LREAL | Compensation value at the given x-position (e.g., correction value in position units) |

## Usage

This type is used in arrays to define compensation relation for functions the function [`LGenComp_GetCompensationValueLinear`](../functions/LGenComp_GetCompensationValueLinear.md), where linear interpolation is performed between data points to calculate the appropriate compensation value for any given position.
