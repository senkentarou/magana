// KeyboardCountry.swift
// Reads a USB HID country code as "is this a JIS keyboard?".

/// USB HID country codes, as reported by an IOHIDDevice's `CountryCode`
/// property.
///
/// The HID spec's own field for this. `CGEvent`'s `keyboardEventKeyboardType`
/// is not usable for the same question: it is a per-model number, and two
/// different layouts can report the same value.
public enum KeyboardCountry {
  public static let japan = 15

  public static func isJIS(countryCode: Int) -> Bool {
    countryCode == japan
  }
}
