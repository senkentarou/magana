// KeyboardCountryTests.swift
// Verifies the JIS reading of USB HID country codes (F-9).

import Testing

@testable import MaganaCore

@Suite("Keyboard country code")
struct KeyboardCountryTests {

  @Test("15 is Japan; the internal US keyboard reports 0")
  func countryCodes() {
    #expect(KeyboardCountry.isJIS(countryCode: 15))
    #expect(KeyboardCountry.isJIS(countryCode: 0) == false)
    #expect(KeyboardCountry.isJIS(countryCode: 33) == false)
  }
}
