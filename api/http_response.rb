# http_response.rb
#
# Author::  Kyle Mullins

class HttpResponse
  def initialize(response)
    @response = response
  end

  def status_code
    @response[:http_code].to_i
  end

  def status_msg
    @response[:http_message]
  end

  def body
    @response[:response_body]
  end

  def success?
    status_code.to_s.start_with?('2')
  end

  def error?
    !success?
  end
end
