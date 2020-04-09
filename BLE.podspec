#
# Be sure to run `pod lib lint BLE.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "BLE"
  s.version          = "0.1.2"
  s.summary          = "Simple BLE (Bluetooth Low Energy) wrapper library in Swift"
  s.description      = "Swift wrapper around CoreBluetooth. Library allows you to connect to BLE devices, read and write data to them"

  s.homepage         = "https://github.com/manGoweb/BLE"
  s.screenshots     = "https://raw.githubusercontent.com/manGoweb/BLE/master/_orig/home.png"
  s.license          = 'MIT'
  s.author           = { "Ondrej Rafaj" => "rafaj@mangoweb.cz" }
  s.source           = { :git => "https://github.com/manGoweb/BLE.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/rafiki270'

  s.platform     = :ios, '9.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
end
