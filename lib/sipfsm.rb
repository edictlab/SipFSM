require 'java'
require 'simplefsm'

# SipFSM 
# SIP application development using SimpleFSM DSL

module SipFSMModule
  class SipFSM <  Java::javax.servlet.sip.SipServlet
    include javax.servlet.sip.TimerListener
    include javax.servlet.sip.SipSessionListener

    include SimpleFSM
    FSM_STATE_ATTR = 'sipFSM_STATE'

    # Method service is overriden in order to get servlet context.
    # Then the service method of the Java base class is called.
    def service(req, res)
      msg = req || res
      $servlet_context = msg.session.servlet_context if !$servlet_context
      super
    end

    # Standard SIP servlet request dispatching
    # is overriden and modified to call the DSL event methods.
    # However, if fsm not defined or fsm does not respond to the given SIP request, standard dispatching still works.
    def doRequest(request)
      m = request.get_method
      fsmm = "sip#{m}".to_sym
      st = run(request)

      if fsm_state_responds_to? st, fsmm 
        send(fsmm, request, nil)
      elsif fsm_state_responds_to? st, :sipREQUEST_ANY
        send(:sipREQUEST_ANY, request, nil)
      else
        super 
      end
    end

    # Standard SIP servlet response dispatching
    # is overriden and modified to call the DSL event methods.
    def doResponse(response)
      m = response.get_status.to_s
      st = run(response)

      resp_exact = "sipRESPONSE_#{m}".to_sym
      resp_group = "sipRESPONSE_#{m[/./].to_s}xx".to_sym

      if fsm_state_responds_to? st, resp_exact 
        send(resp_exact, nil, response)

      elsif fsm_state_responds_to? st, resp_group 
        send(resp_group, nil, response)

      elsif fsm_state_responds_to? st, :sipRESPONSE_ANY
        send(:sipRESPONSE_ANY, nil, response)

      else
        super 
      end
    end

    # CLASS methods ------------------------------------------------------
    # creates and returns INVITE request
    def self.create_request(app_session, method, from, to)
      sip_factory = $servlet_context.get_attribute('javax.servlet.sip.SipFactory')
      addr_from = sip_factory.create_address(sip_factory.create_uri(from[:uri]), from[:display_name])
      addr_to = sip_factory.create_address(sip_factory.create_uri(to[:uri]), to[:display_name])

      req = sip_factory.create_request(app_session, method, addr_from, addr_to);
      req
    end

    # returns application session 
    def self.get_application_session_by_id(app_session_id)
      return  nil if !app_session_id
      util = $servlet_context.get_attribute('javax.servlet.sip.SipSessionsUtil')
      util.get_application_session_by_id(app_session_id)
    end

    # returns sip application session or creates one if flag is true
    def self.http_get_application_session(http_request, create_flag, key_sufix="")
      # HttpSession <=> ConvergedHttpSession
      sid = http_request.env['java.servlet_request'].get_session().get_id  

      util = $servlet_context.get_attribute('javax.servlet.sip.SipSessionsUtil')
      app_key = "sipfsmApp_#{key_sufix}#{sid}"
      app = util.get_application_session_by_key(app_key, create_flag)
      app
    end

    # returns sip-fsm state saved in application session attribute
    def self.get_fsm_state_by_app_id(app_session_id)
      return nil if !app_session_id
      app_session = get_application_session_by_id(app_session_id)
      if app_session
        app_session.get_attribute(FSM_STATE_ATTR)
      else 
        nil
      end
    end

    # returns all SIP sessions bound to the given application session
    def self.get_sip_sessions_by_app_id(app_session_id)
      return nil if !app_session_id
      app_session = get_application_session_by_id(app_session_id)
      app_session.get_sessions("SIP")
    end

    def self.get_attr_const
      FSM_STATE_ATTR
    end

    private
    ##### Overriden methods (for FSM) ###########################

    # Loading and saving application FSM state from application attribute

    def current_state *sip_msg
      sip_msg.flatten!
      m = sip_msg[0] || sip_msg[1]
      application_session(m).get_attribute(FSM_STATE_ATTR)
    end

    def set_current_state st, *sip_msg
      application_session(sip_msg).set_attribute(FSM_STATE_ATTR, st)
    end

    def application_session *sip_msg
      sip_msg.flatten!
      m = sip_msg[0] || sip_msg[1]
      m.get_application_session
    end

    ####### Helper methods ###############

    # Dynamic methods:
    #  send_response_YYY - for sending response with 
    #  the code specified in the method name (send_response_200 etc.)
    # is_XXX? - check if the SIP request is of type (method) specified 
    # in the method name (is_INVITE? etc.)
    #
    def method_missing(name, args)
      if name.to_s =~ /send_response_(.*)/
        args[0].create_response($1.to_i).send
      elsif name.to_s =~ /is_(.*)\?/
        args[0].get_method == $1
      else
        super
      end
    end

    def sip_factory
      $servlet_context.get_attribute('javax.servlet.sip.SipFactory')
    end

    # proxy request to given URI
    def proxy_to_helper(request, touri, recroute=false)
      l_proxy = request.get_proxy
      l_proxy.set_record_route(recroute)

      to_URI = create_uri touri
      l_proxy.proxy_to(to_URI)

    end

    # creates URI java object using SipFactory
    def create_uri(str_uri)
        sip_factory.create_uri('sip:' + str_uri)
    end

    def get_from_user_address_port(msg)
      [ msg.from.uri.user,
        msg.remote_addr,
        msg.remote_port ]
    end

    def get_from_uri(msg)
      u, a, p = get_from_user_address_port(msg)
      "sip:#{u}@#{a}:#{p}" 
    end

    # copies content (SDP) from message m1 to message m2
    def copy_msg_content(m1, m2)
      if m1.get_content_length > 0
        m2.set_content(m1.get_raw_content, m1.get_content_type)

        enc = m1.get_character_encoding
        m2.set_character_encoding(enc) if enc and enc.length > 0
      end
    end

    # Sends SIP request and sets custom session attributes 
    # given in a hash as a second element in attributes
    def send_req args
      req = args[0]
      if args.size > 2
        attrib = args[2]
      end
      s = req.get_session
      s.set_handler(self.class.to_s)
      if attrib and attrib.size > 0 and attrib.class = Hash
        attrib.each do |k, v|
          s.set_attribute(k.to_s, v)
        end
      end
      req.send
    end
    
    ###########################################################
    # Methods that can be called directly from FSM definition. 
    # All methods have atributes according to the SipFSM standard
    # meaning the first in the argument array is request and 
    # the second is response. 

    def is_UNREGISTER?(args)
      request = args[0]
      return false unless is_REGISTER?(args)

      exp = request.get_header('Expires')
      if !exp
        c = request.get_header('Contact')
        c.grep(/expires=(\d+)/)
        exp = $1
      end

      0 == exp.to_i
    end

    def invalidate_session msgs
      msg = msgs[0] || msgs[1]
      msg.get_session.invalidate
      # ACK is sent by the SIP servlets container 
    end

    def send_OK msgs
      req = msgs[0]
      req.create_response(200).send
    end

    def send_ACK msgs
      res = msgs[1]
      res.create_ack.send
    end

    def send_BYE msgs
      req, res = msgs
      m = req || res
      m.get_session.create_request("BYE").send
    end

    def cancel_req args
      req = args[0]
      req.create_cancel.send
      req.session.invalidate
    end

    # B2B Helper methods ##################################

    # forwards request to the linked session (B2BUA Helper)
    def b2b_forward_message msgs
      req, res = msgs
      r = req || res.get_request
      begin
        b2b = r.get_b2bua_helper
        linked = b2b.get_linked_session(r.get_session)
        if linked
          other_leg = nil
          resp_session = res.get_session
          resp_request = res.get_request
          if resp_request.is_initial
            other_leg = b2b.create_response_to_original_request(linked, res.get_status, res.get_reason_phrase)
          else
            other_req = b2b.get_linked_sip_servlet_request(resp_request)
            other_leg = other_req.create_response(res.get_status, res.get_reason_phrase)
          end
          copy_msg_content(res, other_leg)
          other_leg.send
        else
          raise "No linked session."
        end
      rescue Exception => e
        puts "Error: #{e.message}"
      end
    end

    # send BYE to the linked session
    def b2bua_BYE_other msgs
      req, res = msgs
      req ||= res.get_request
      current_sess = req.get_session
      b2b = req.get_b2bua_helper
      session2 =
        b2b.get_linked_session(current_sess)
      session2.create_request("BYE").send
    end

    # send BYE to both linked session
    def b2bua_BYE_both msgs
      req, res = msgs
      req ||= res.request
      session1 = req.session
      session2 = req.b2bua_helper.get_linked_session(session1)
      session1.create_request("BYE").send
      session2.create_request("BYE").send
      session1.invalidate
      session2.invalidate
    end

    # Send initial request using B2BUA helper.
    # The third and other argument array elements
    # can be attributes to save into the SIP session.
    def b2b_send_initial_req args
      req = args[0]
      if args.size > 2
        attrib = args[2]
      end
      new_req = req.b2bua_helper.create_request(req)
      s = new_req.session
      s.set_attribute('initialINVITE', new_req)
      if attrib and attrib.size > 0 and attrib.is_a?(Hash)
        attrib.each do |k, v|
          s.set_attribute(k.to_s, v)
        end
      end
      new_req.send
    end

  end
end
