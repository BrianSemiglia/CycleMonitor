use_frameworks!

target 'CycleMonitor' do
  platform :macos, 10.15
  pod 'Cycle', git: 'https://github.com/BrianSemiglia/Cycle.swift', branch: 'lens2'
  pod 'RxSwift'
  pod 'RxCocoa'
  pod 'Argo',     '~> 4.0'
  pod 'Curry',    '~> 4.0'
  pod 'RxSwiftExt'
  pod 'Highlightr'
  target 'CycleMonitorTests' do
    inherit! :search_paths
  end
end

target 'Integer Mutation' do
  platform :ios, 9.0
  pod 'Cycle', git: 'https://github.com/BrianSemiglia/Cycle.swift', branch: 'lens2'
  pod 'RxSwift'
  pod 'RxCocoa'
  pod 'Curry',                   '~> 4.0'
  pod 'RxCoreMotion'
  pod 'Argo',                    '~> 4.0'
  pod 'RxSwiftExt'
  target 'Integer Mutation Tests' do
    inherit! :search_paths
    pod 'RxTest'
  end
end
