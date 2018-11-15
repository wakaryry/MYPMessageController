@version = '0.4.0'
#
# Be sure to run `pod lib lint MYPMessageController.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MYPMessageController'
  s.version          = @version
  s.summary          = 'A message style controller with a growable textview input.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  MYPMessageController is a message style controller with a growable textview input.
  
  It could be used in many cases, especailly in conversation style or comment style or discussion style.
                       DESC

  s.homepage         = 'https://github.com/wakaryry/MYPMessageController'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wakary' => 'redoume@163.com' }
  s.source           = { :git => 'https://github.com/wakaryry/MYPMessageController.git', :tag => s.version.to_s }
  s.social_media_url = 'https://github.com/wakaryry/'

  s.ios.deployment_target = '10.0'
  s.swift_version = '4.2'
  s.requires_arc = true

  s.source_files = 'MYPMessageController/Classes/**/*.swift'
  
  s.resource_bundles = {
     'MYPMessageController' => ['MYPMessageController/Assets/*.png',
     'MYPMessageController/Assets/*.xib',
     'MYPMessageController/Assets/*.storyboard',
     'MYPMessageController/Assets/*.xcassets'
     ]
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'Foundation'
  # s.dependency 'AFNetworking', '~> 2.3'
end
