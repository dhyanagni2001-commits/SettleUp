//
//  AppFeatures.swift
//  SplitWiseClone
//
//  Sign in with Apple, iCloud sync, and group sharing need capabilities that
//  only a paid Apple Developer Program team can sign. The default build
//  leaves them out so it installs with a free Apple ID; Siri, Core ML, and
//  everything local still work.
//
//  To turn them on (paid team), in the SplitWiseClone target's build settings:
//    CODE_SIGN_ENTITLEMENTS = SplitWiseClone/SplitWiseClone.entitlements
//    SWIFT_ACTIVE_COMPILATION_CONDITIONS += CLOUD_FEATURES
//

enum AppFeatures {
    #if CLOUD_FEATURES
    static let cloud = true
    #else
    static let cloud = false
    #endif
}
