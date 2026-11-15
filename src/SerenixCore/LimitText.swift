import Foundation

/// A limit as refusal messages write it: whole, with a thousands comma ("5,000").
func limitText(_ value: Double) -> String {
    Int(value).formatted(.number.locale(Locale(identifier: "en_GB")))
}
