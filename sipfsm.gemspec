# Gemsec file for sipfsm gem
  
Gem::Specification.new do |s|
  s.name        = 'sipfsm'
  s.version     = '0.2.3'
  s.date        = '2017-04-17'
  s.summary     = "SipFSM - SIP application development in Ruby"
  s.description = "SIP application development in Ruby using SimpleFSM, a simple and lightweight domain specific language (DSL)."
  s.authors     = ["Edin Pjanic", "Amer Hasanovic"]
  s.email       = ['edin@ictlab.com.ba',  'amer@ictlab.com.ba']
  s.add_runtime_dependency "simplefsm", ["~> 0.2.3"]
  s.add_runtime_dependency "jrubycipango", ["~> 0.2.11"]
  s.files       =  ["lib/sipfsm.rb"]
  s.require_paths      = ["lib"] 
  s.homepage    = 'http://github.com/edictlab/SipFSM'
end

