require 'sipfsm'

# File 'ruby_sip_servlet.rb'
class MySipServlet < SipFSMModule::SipFSM

  fsm do
    state :idle

    transitions_for :idle do
      event :sipREGISTER, :guard_not => :sip_user,
            :new => :idle, :action => :send_response_404

      event :sipREGISTER, :guard => :is_UNREGISTER?,
            :new => :idle, :action => [:unregister_user, :send_response_200]

      event :sipREGISTER, 
            :new => :idle, :action => [:register_user, :send_response_200]

      event :sipINVITE, :guard_not => :callee_user, 
            :new => :idle, :action => :send_response_404

      event :sipINVITE, :guard_not => :callee_user_registration, 
            :new => :idle, :action => :send_response_480

      event :sipINVITE,  
        :new => :idle, :action => :proxy_request
    end
  end

  private
  def sip_user args
    request = args[0]
    username = request.from.uri.user
    SipUser.find_by_user_name(username)
  end

  def register_user args
    request = args[0]
    username, address, port = get_from_user_address_port(request)
    remote_uri = "sip:#{username}@#{address}:#{port}"
    user = sip_user(args)
    reg = Registration.find_or_create_by_sip_user_id_and_location(user.id, remote_uri)

    reg.location = remote_uri
    reg.save
    puts "Registered #{remote_uri}."
    request.create_response(200).send
  end

  def unregister_user args
    request = args[0]
    username, * = get_from_user_address_port(request)
    remote_uri = get_from_uri(request)

    user = SipUser.find_by_user_name(username)
    reg = Registration.find_by_sip_user_id_and_location(user.id, remote_uri)
    reg.destroy if reg

    puts "Unregistered #{remote_uri}."
    request.create_response(200).send
  end

  def callee_user(args)
    req = args[0]
    username = req.get_to.get_uri.get_user
    SipUser.find_by_user_name(username)
  end

  def callee_user_registration(args)
    req = args[0]
    user = callee_user(args)
    if user 
      user.registration
    else 
      nil
    end
  end

  def proxy_request(args)
    req = args[0]
    puts "### proxy_request ###"
    reg = callee_user_registration(args)

    uri = sip_factory.create_uri(reg.location)
    puts "Proxying to #{uri}..."
    req.get_proxy.proxy_to(uri)
  end

end 

