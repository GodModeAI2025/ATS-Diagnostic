# Required-reason API declaration

The new ProxyRulePersistence.load size gate calls FileManager.attributesOfItem for a file within this app's Application Support container. Apple classifies this API under NSPrivacyAccessedAPICategoryFileTimestamp and permits C617.1 for timestamps, size and other metadata of app-container files. PrivacyInfo.xcprivacy now declares that category/reason. No data collection/tracking declaration was changed.

Official references: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype and https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons . Their official DocC JSON was read for the exact reason association. Source scan found no direct UserDefaults, AppStorage, SceneStorage, file-system space or systemUptime calls in App; those categories were not added.

The first signed54 archive was retained locally as ATSDiagnosticPreview-54-PrePrivacy.xcarchive and was not uploaded. A new54 archive includes the manifest correction; source/runtimes unchanged apart from resource metadata.
