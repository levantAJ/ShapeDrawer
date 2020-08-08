Pod::Spec.new do |s|
  s.name = 'ShapeDrawer'
  s.version = '1.0'
  s.summary = 'ShapeDrawer falicates drawing 2D shapes, curved line, rectangle, oval'
  s.description = <<-DESC
  ShapeDrawer written on Swift 5.0 by levantAJ
                       DESC
  s.homepage = 'https://github.com/levantAJ/ShapeDrawer'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'Tai Le' => 'sirlevantai@gmail.com' }
  s.source = { :git => 'https://github.com/levantAJ/ShapeDrawer.git', :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.swift_version = '5.0'
  s.source_files = 'ShapeDrawer/*.{swift}'
  
end