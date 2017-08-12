module AuthenticationsHelper
  module ClassMethods

  end

  module InstanceMethods
    def encode_jwt_token(data_hash, expire_after = nil)
      payload = { :data => data_hash }
      if expire_after.present?
        exp = Time.now.to_i + expire_after.to_i.minutes.to_i
        payload.merge!({exp: exp})
        # exp = Time.now.to_i + ENV.fetch("EXPIRE_AFTER_SECONDS") { 1.hour }.to_i
        # payload = { :data => data_hash, :exp => exp }
      end
      hmac_secret = sso_secret_key
      JWT.encode payload, hmac_secret, 'HS256'
    end

    def decode_jwt_token(token)
      hmac_secret = sso_secret_key
      begin
        decoded_token = JWT.decode token, hmac_secret, true, { :algorithm => 'HS256' }
        payload = decoded_token.select{|decoded_part| decoded_part.key?("data") }.last
        return payload
      rescue JWT::ExpiredSignature
        # Handle expired token, e.g. logout user or deny access
        puts "Token expired thus redirecting to root_url"
        if response.location.blank?
          redirect_to root_url and return
        else
          response.location = root_url
          response.status = 301
          return
        end
      end
    end

    def generate_url(url, params = {})
      uri = URI(url)
      uri.query = params.to_query
      uri.to_s
    end

    def authenticate_or_redirect_to_login
      # return nil if (params[:action] == "login" && params[:controller] == "authentications")
      if logged_in?
        if (service_url = get_service_url).present?
          redirect_to_service_provider(service_url, current_user) and return
        else
          return nil
        end
      else
        # redirect_to after_logout_path and return
        after_logout_path
        return
      end
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
    receiver.send :include, IdentityProvider::Login
    receiver.send :include, IdentityProvider::Logout
  end

end

class ApplicationController < ActionController::Base
  include AuthenticationsHelper
  after_action :set_session_service_token
  before_action :authenticate_or_redirect_to_login
end
