Pod::Spec.new do |s|
  s.name     = 'SwiftSyslog'
  s.version  = '1.0.0'
  s.license  = { :type => "MIT", :file => "LICENSE" }
  s.summary  = 'Swift framework to send buffered logs to Splunk Cloud from any Swift logger framework to [syslog server](https://github.com/pykaso/SyslogSplunkServer).'
  s.homepage = 'https://github.com/pykaso/SwiftSyslog'
  s.authors  = { 'Lukas Gergel' => 'admin@pykaso.net' }
  s.source   = { :git => 'https://github.com/pykaso/SwiftSyslog',
                 :tag => "#{s.version}" }
  s.description = ''

  s.source_files = 'Sources/*.swift'
  s.requires_arc = true

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.8'
  #s.tvos.deployment_target = '9.0'
  
  #s.ios.frameworks = 'CFNetwork', 'Security'
  #s.osx.frameworks = 'CoreServices', 'Security'
  #s.tvos.frameworks = 'CFNetwork', 'Security'
end