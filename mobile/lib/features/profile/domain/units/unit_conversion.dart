/// Conversions between the stored metric values and the imperial display.
/// Pure functions: the screen converts for display and when the user types,
/// and keeps the stored metric value untouched when a field is not edited.
library;

const _cmPerInch = 2.54;
const _inchesPerFoot = 12;
const _lbsPerKg = 2.2046226218;

/// Height in whole feet and inches (inches 0 to 11).
typedef FeetInches = ({int feet, int inches});

/// Rounds to one decimal, the precision the API stores.
double roundToTenth(double value) => (value * 10).roundToDouble() / 10;

/// [cm] as feet and inches, to the nearest inch.
FeetInches cmToFeetInches(double cm) {
  final total = (cm / _cmPerInch).round();
  return (feet: total ~/ _inchesPerFoot, inches: total % _inchesPerFoot);
}

/// Feet and inches (inches may have a fraction) as centimetres, one decimal.
double feetInchesToCm(int feet, double inches) =>
    roundToTenth((feet * _inchesPerFoot + inches) * _cmPerInch);

/// [kg] in pounds, one decimal.
double kgToLbs(double kg) => roundToTenth(kg * _lbsPerKg);

/// [lbs] in kilograms, one decimal.
double lbsToKg(double lbs) => roundToTenth(lbs / _lbsPerKg);

/// A number for a text field: no trailing `.0`.
String formatNumber(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
