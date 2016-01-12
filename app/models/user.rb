class User < ActiveRecord::Base

  def get_auth_token(phone)
    User.where(phone: phone).last.auth_token rescue nil
  end

  @account_sid = 'AC1a61a323b5eeff094ce746f3bfdf2d52'
  @auth_token = 'bf096484012c84c791bdb2483e67e494'
  @twilio_number = '+14134183825'

  def self.sendsms(phone_number, message)     
    # set up a client to talk to the Twilio REST API 
    @client = Twilio::REST::Client.new @account_sid, @auth_token
     
    @client.account.messages.create({
      :from => @twilio_number, 
      :to => phone_number,
      :body => message
    })
    # twiml = Twilio::TwiML::Response.new do |r|
    #   r.Message "Sample text.Thanks for the message!"
    # end
    # render xml: twiml.text
  end

  def book_uber(params)
    url = "https://sandbox-api.uber.com/v1/requests"
    params = User.get_book_params(params)
    token = self.auth_token
    begin
      response = RestClient::Request.execute(:url => url, :headers => {:Authorization => token, 'Content-Type' => 'application/json'},:ssl_version => 'TLSv1_2', :method => 'post', :payload => params)
      self.update_booking(JSON.parse(response)) if response
    rescue Exception => e
      response = nil
    end
    JSON.parse(response) if response
  end

  def self.get_book_params(params)
    body = params[:Body].split(",") if params[:Body].present?
    if body.present? and body.first.include?("book")
      start_latitude  = body[1].include?("lat") && body[1].split(":")[1]
      start_longitude = body[2].include?("lng") && body[2].split(":")[1]
      product_name    = body[3].include?("product") && body[3].split(":")[1]
      product         = product_name.include?("any") ? Product.where("name = #{product}").last : nil
      product_id      = product.present? ? product.uber_id : nil
      book_params = {
          :start_latitude => start_latitude,
          :start_longitude => start_longitude,
      }
      book_params.merge!({:product_id => product_id}) if product_id.present?
      return book_params
  end

  def update_booking(details)
    if details.present? && details["request_id"].present?
      final_response = nil
      url = "https://sandbox-api.uber.com/v1/sandbox/requests/#{details["request_id"]}"
      data = {"status" => "accepted"}
      response = RestClient::Request.execute(:url => url, :headers => {:Authorization => self.auth_token, 'Content-Type' => 'application/json' }, :ssl_version => 'TLSv1_2', :method => 'put', :payload => data.to_json)
      if response.present?
        url = "https://sandbox-api.uber.com/v1/requests/#{details["request_id"]}"
        final_response = RestClient::Request.execute(:url => url, :headers => {:Authorization => self.auth_token, 'Content-Type' => 'application/json' }, :ssl_version => 'TLSv1_2', :method => 'get')
      end
      if final_response.present?
        final_response = JSON.parse(final_response)
        sms_text = "Driver name: #{final_response["driver"]["name"]}, Number: #{final_response["driver"]["phone_number"]}, Vehicle name: #{final_response["vehicle"]["make"]} #{final_response["vehicle"]["model"]}, license_plate, Licence number: #{final_response["vehicle"]["license_plate"]}" 
        self.self.sendsms(self.phone, sms_text)
      end
  end

end
