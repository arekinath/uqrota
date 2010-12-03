require 'net/https'
require 'rexml/document'

module Utils
  
  # sends sms messages via https://www.readytosms.com.au/
  class SMSSender
    def initialize(user, pass)
      @user = user
      @pass = pass
    end
    
    # sends an SMS message. takes a hash, returns true on success
    def send(msg)
      xms_doc = REXML::Document.new <<END
<?xml version="1.0" encoding="utf-8"?>
<xmsData client="Microsoft Office Outlook 12.0" xmlns="http://schemas.microsoft.com/office/Outlook/2006/OMS">
   <user>
   </user>
   <xmsHead>
      <scheduled></scheduled>
      <requiredService>SMS_SENDER</requiredService>
      <to>
        <recipient></recipient>
      </to>
   </xmsHead>
   <xmsBody format="SMS">
     <content contentType="text/plain"></content>
   </xmsBody>
</xmsData>
END
      recip = xms_doc.elements['xmsData/xmsHead/to/recipient']
      recip.text = msg[:recipient]
      
      content = xms_doc.elements['xmsData/xmsBody/content']
      content.text = msg[:text]
      
      sched = xms_doc.elements['xmsData/xmsHead/scheduled']
      sched.text = (Time.now + 10).utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      
      user = xms_doc.elements['xmsData/user']
      userId = REXML::Element.new('userId')
      userId.text = @user
      user.elements << userId
      pw = REXML::Element.new('password')
      pw.text = @pass
      user.elements << pw
      replyPhone = REXML::Element.new('replyPhone')
      replyPhone.text = msg[:sender]
      user.elements << replyPhone
      customData = REXML::Element.new('customData')
      user.elements << customData
      
      soap_doc = REXML::Document.new <<END
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <DeliverXms xmlns="http://schemas.microsoft.com/office/Outlook/2006/OMS">
      <xmsData></xmsData>
    </DeliverXms>
  </soap12:Body>
</soap12:Envelope>
END
      
      soap_doc.elements['soap12:Envelope/soap12:Body/DeliverXms/xmsData'].text = xms_doc.to_s
      pdata = soap_doc.to_s
      
      ht = Net::HTTP.new('smsmessenger.informatel.com', 443)
      ht.use_ssl = true
      resp = ht.post('/Oms/OmsService.asmx', pdata, { 'Content-Type' => 'application/soap+xml' })
      
      soap_resp = REXML::Document.new(resp.body)
      result = soap_resp.elements['soap:Envelope/soap:Body/DeliverXmsResponse/DeliverXmsResult']
      result_doc = REXML::Document.new(result.text)
      result_code = result_doc.elements['xmsResponse'].elements[1].attributes['code']
      return true if result_code == 'ok'
      return false
    end
  end
end