import Foundation

/// When this build's signature dies.
///
/// A free Personal Team profile lives 7 days, after which the app refuses to
/// launch. Reading the expiry out of the embedded profile turns that from a
/// nasty surprise into a number you can see — and tells you whether the
/// re-install automation is actually keeping up.
struct BuildExpiry: Equatable, Sendable {
    let expirationDate: Date

    func daysRemaining(from now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: expirationDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Nil in the simulator and for App Store builds, neither of which embeds a
    /// development profile.
    static func current(bundle: Bundle = .main) -> BuildExpiry? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let plist = extractPlist(from: data),
              let expiration = plist["ExpirationDate"] as? Date
        else { return nil }
        return BuildExpiry(expirationDate: expiration)
    }

    /// The profile is a CMS-signed blob with an XML plist in the middle. Slicing
    /// out the plist avoids pulling in the Security framework's CMS decoder for
    /// what is ultimately one date lookup.
    private static func extractPlist(from data: Data) -> [String: Any]? {
        guard let start = data.firstRange(of: Data("<?xml".utf8)),
              let end = data.firstRange(of: Data("</plist>".utf8))
        else { return nil }

        let xml = data[start.lowerBound..<end.upperBound]
        return try? PropertyListSerialization.propertyList(
            from: xml, options: [], format: nil
        ) as? [String: Any]
    }
}
