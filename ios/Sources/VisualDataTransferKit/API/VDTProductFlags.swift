import Foundation

/// Runtime feature switches for integrated product UI (UserDefaults-backed).
public enum VDTProductFlags {
    public static let integratedExperienceUserDefaultsKey = "vdt.product.integratedExperience"
    private static let onboardingKey = "vdt.product.onboardingDismissed"

    /// When `true`, the demo app can show `ProductTransferExperience` instead of bare developer tabs.
    public static var integratedExperienceEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: integratedExperienceUserDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: integratedExperienceUserDefaultsKey) }
    }

    /// Set after the user dismisses first-run tips in the product shell.
    public static var onboardingTipsDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }
}
