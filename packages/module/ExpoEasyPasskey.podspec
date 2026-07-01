require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name = "ExpoEasyPasskey"
  s.version = package["version"]
  s.summary = package["description"]
  s.description = package["description"]
  s.license = package["license"]
  s.author = "Expo Easy Passkey Maintainers"
  s.homepage = "https://github.com/simonbetton/expo-easy-passkey"
  s.platforms = {
    :ios => "16.0"
  }
  s.source = {
    :git => "https://github.com/simonbetton/expo-easy-passkey.git"
  }
  s.static_framework = true
  s.swift_version = "5.9"
  s.source_files = [
    "ios/*.{h,m,mm,swift}",
    "ios/generated/*.{h,swift}"
  ]
  s.public_header_files = "ios/generated/*.h"
  s.vendored_frameworks = "ios/rust/ExpoEasyPasskeyFfi.xcframework"
  s.frameworks = "AuthenticationServices"
  s.dependency "ExpoModulesCore"

  s.preserve_paths = [
    "ios/generated/**/*",
    "ios/rust/**/*"
  ]
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES"
  }
end
