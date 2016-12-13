Gem::Specification.new do |s|
  s.name = 'gtk2html'
  s.version = '0.2.3'
  s.summary = 'Experimental gem to render HTML using Gtk2'
  s.authors = ['James Robertson']
  s.files = Dir['lib/gtk2html.rb']
  s.add_runtime_dependency('gtk2svg', '~> 0.3', '>=0.3.12')
  s.add_runtime_dependency('htmle', '~> 0.1', '>=0.1.3')  
  s.signing_key = '../privatekeys/gtk2html.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/gtk2html'
end
