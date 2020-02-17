use_frameworks!

target 'CycleMonitor' do
  platform :macos, 10.15
  pod 'Cycle', git: 'https://github.com/BrianSemiglia/Cycle.swift', branch: 'lens2'
  pod 'RxSwift', '~> 5.0'
  pod 'RxCocoa', '~> 5.0'
  pod 'Argo', '~> 4.0'
  pod 'Curry', '~> 4.0'
  pod 'RxSwiftExt'
  pod 'Highlightr'
  target 'CycleMonitorTests' do
    inherit! :search_paths
  end
end

target 'Integer Mutation' do
  platform :ios, 9.0
  pod 'Cycle', git: 'https://github.com/BrianSemiglia/Cycle.swift', branch: 'lens2'
  pod 'RxSwift', '~> 5.0'
  pod 'RxCocoa', '~> 5.0'
  pod 'Curry', '~> 4.0'
  pod 'RxCallbacks'
  pod 'Argo', '~> 4.0'
  pod 'RxSwiftExt'
  target 'Integer Mutation Tests' do
    inherit! :search_paths
    pod 'RxTest'
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    if ['Argo-iOS', 'Argo-macOS'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
      end
    end
  end
end
