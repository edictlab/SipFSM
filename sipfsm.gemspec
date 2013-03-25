# Gemsec file for sipfsm gem
  
Gem::Specification.new do |s|
  s.name        = 'sipfsm'
  s.version     = '0.1.4'
  s.date        = '2013-03-25'
  s.summary     = "SipFSM - SIP application development in Ruby"
  s.description = "SIP application development in Ruby using SimpleFSM, a simple and lightweight domain specific language (DSL)."
  s.authors     = ["Edin Pjanic", "Amer Hasanovic"]
  s.email       = ['edin@ictlab.com.ba',  'amer@ictlab.com.ba']
  s.add_runtime_dependency "simplefsm", ["~> 0.1"]
  s.files       =  ["lib/sipfsm.rb"]
  s.require_paths      = ["lib"] 
  s.homepage    = 'http://github.com/edictlab/SipFSM'
end

