use_frameworks!

target 'CycleMonitor' do
  platform :macos, 10.11
  pod 'Cycle',    '~> 0.0.17'
  pod 'RxSwift',  '~> 4.3.0'
  pod 'RxCocoa', git: 'https://github.com/ReactiveX/RxSwift', branch: 'master'
  pod 'Argo',     '~> 4.0'
  pod 'Curry',    '~> 4.0'
  pod 'RxSwiftExt'
  target 'CycleMonitorTests' do
    inherit! :search_paths
  end
end

target 'Integer Mutation' do
  platform :ios, 9.0
  pod 'Cycle',                   '~> 0.0.17'
  pod 'RxSwift',                 '~> 4.3.0'
  pod 'RxCocoa', git: 'https://github.com/ReactiveX/RxSwift', branch: 'master'
  pod 'Curry',                   '~> 4.0'
  pod 'RxCoreMotion'
  pod 'Argo',                    '~> 4.0'
  pod 'Wrap',                    '~> 3.0'
  pod 'RxSwiftExt'
  pod 'RxUIApplicationDelegate', '~> 0.1.3'
  target 'Integer Mutation Tests' do
    inherit! :search_paths
    pod 'RxTest'
  end
end
