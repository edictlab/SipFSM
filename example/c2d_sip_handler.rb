require 'sipfsm'

class C2dSipHandler < SipFSM

  fsm do
    state :idle
    state :call_leg1
    state :call_leg2,   { :enter => :invite_leg2 }
    state :connected
    state :terminating, { :enter => :b2bua_BYE_other }

    transitions_for :idle do
      event :sendREQ, :new => :call_leg1, 
            :guard => :is_INVITE?, :do => :b2b_send_initial_req 
    end

    transitions_for :call_leg1 do
      event :sipRESPONSE_4xx, :new => :idle, :do => :invalidate_session
      event :sipRESPONSE_6xx, :new => :idle, :do => :invalidate_session
      event :sipRESPONSE_200, :new => :call_leg2
      event :hangUP, :new => :idle, :do => :cancel_req
    end
      
    transitions_for :call_leg2 do
      event :sipBYE, :new => :terminating, :do => :send_response_200
      event :sipRESPONSE_4xx, :new => :terminating
      event :sipRESPONSE_6xx, :new => :terminating, :do => :invalidate_session 
      event :sipRESPONSE_200, :new => :connected, :do => :send_ACKs
      event :hangUP, :new => :idle, :do => :bye_cancel
    end
      
    transitions_for :connected do
      event :sipRESPONSE_4xx, :new => :terminating, :do => :invalidate_session 
      event :sipBYE, :new => :terminating, :do => :send_response_200
      event :hangUP, :new => :idle, :do => :b2bua_BYE_both
    end

    transitions_for :terminating do
      event :sipRESPONSE_200, :new => :idle
      event :sipRESPONSE_4xx, :new => :idle, :do => :invalidate_session 
    end
  end

  private

  def bye_cancel msgs
    req, res = msgs
    req ||= res.request
    b2b = req.b2bua_helper
    session1 = req.session
    session2 = b2b.get_linked_session(session1)
    session1.create_request("BYE").send
    b2b.create_cancel(session2).send
    session1.invalidate
    session2.invalidate
  end

  def confirm1_and_terminate2 msgs
    req = msgs[0]
    req.create_response(200).send
    session2 = req.get_b2bua_helper.get_linked_session(req.get_session)
    session2.create_request("BYE").send
  end

  def send_ACKs msgs
    res = msgs[1]
    
    session2 = res.get_session

    ack1 = session2.get_attribute("originalOK").create_ack
    copy_msg_content(res, ack1)

    send_ACK [nil, res]
    ack1.send
  end

  # using B2BUA: Send (INVITE) request to the second leg
  def invite_leg2 msgs
    req, res = msgs
    req ||= res.get_request

    req.get_application_session.set_expires(0)

    b2b = req.get_b2bua_helper

    # we are calling leg 2 so we swap From and To from the first leg
    from_to = {"From" => [res.get_header("To")], "To" => [res.get_header("From")]}
    
    #create request in a new linked sip session
    leg2 = b2b.create_request(req, true, from_to)
    leg2.set_request_uri(res.get_from.get_uri)

    # copy SDP offer from leg 1
    copy_msg_content(res, leg2)

    leg2.send
    # save original OK response so we can ACK it later, when connect with leg2 party
    leg2.get_session.set_attribute("originalOK", res)

    @app_session.set_expires(0) if leg2
  end

  # checks if the request is INVITE  
  def is_INVITE? msgs
    req, res = msgs
    req.get_method == "INVITE"
  end

end # of class SipHandler

