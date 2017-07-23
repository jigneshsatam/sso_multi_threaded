module AuthenticationsHelper
  module ClassMethods

  end

  module InstanceMethods
    def log_in(user)
      session[:user_id] = user.id
    end

    # Remembers a user in a persistent session.
    def remember(user)
      user.remember
      cookies.permanent.signed[:user_id] = user.id
      cookies.permanent[:remember_token] = user.remember_token
    end

    def current_user
      return @current_user if !@current_user.nil?
      if (user_id = session[:user_id])
        begin
          # main_thread_conn = ActiveRecord::Base.connection_pool.checkout
          # main_thread_conn.raw_connection
          # puts "@@@@@@@@@@   Active connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.connections.size} @@@@@@@@@@@@@@@@"
          # puts "@@@@@@@@@@   Waiting connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.num_waiting_in_queue} @@@@@@@@@@@@@@@@"
          # sleep(20)
          # @current_user ||= User.find_by(id: user_id)
          # puts "@@@@@@@@@@ CURRENT_USER before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          # ActiveRecord::Base.connection_pool.with_connection do
          # #   puts "@@@@@@@@@@   Thread is sleeping CURRENT_USER @@@@@@@@@@@@@@@@"
          # #   puts "@@@@@@@@@@   Active connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.connections.size} @@@@@@@@@@@@@@@@"
          #   # puts "@@@@@@@@@@   Waiting connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.num_waiting_in_queue} @@@@@@@@@@@@@@@@"
          #   puts "@@@@@@@@@@ CURRENT_USER middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          #   sleep(20)
          #   @current_user ||= User.find_by(id: user_id)
          # end
          # puts "@@@@@@@@@@ CURRENT_USER after ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"

          logger.debug "@@@@@@@@@@ CURRENT_USER before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          @current_user ||= User.find_by(id: user_id)
          logger.debug "@@@@@@@@@@ CURRENT_USER middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          # sleep(20)
          # ts = Thread.new do
          #   puts "@@@@@@@@@@ CURRENT_USER before ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          #   @current_user ||= User.find_by(id: user_id)
          #   puts "@@@@@@@@@@ CURRENT_USER middle ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          #   sleep(20)
          #   # User.connection_pool.with_connection do
          #   # end
          #   User.connection.close
          #   puts "@@@@@@@@@@ CURRENT_USER after ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          # end
          # ts.join
        rescue Exception => e
          logger.debug "@@@@@@@@@@ Thread is sleeping RESCUE #{e} @@@@@@@@@@@@@@@@"
          # ActiveRecord::Base.connection_pool.disconnect!
          # ActiveRecord::Base.connection_pool.clear_reloadable_connections!
          # ActiveRecord::Base.clear_active_connections!
          ActiveRecord::Base.connection.close
          retry
        ensure
          logger.debug "@@@@@@@@@@ Thread in CURRENT_USER ENSURE @@@@@@@@@@@@@@@@"
          User.connection.close
          logger.debug "@@@@@@@@@@ CURRENT_USER ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
          # ActiveRecord::Base.connection_pool.release_connection
          # ActiveRecord::Base.connection_pool.checkin(main_thread_conn)
          # ActiveRecord::Base.connection_pool.disconnect!
          # puts "@@@@@@@@@@   Active connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.connections.size} @@@@@@@@@@@@@@@@"
          # puts "@@@@@@@@@@   Waiting connections CURRENT_USER ==> #{ActiveRecord::Base.connection_pool.num_waiting_in_queue} @@@@@@@@@@@@@@@@"
          # ActiveRecord::Base.connection_pool.clear_reloadable_connections!
          # ActiveRecord::Base.clear_active_connections!
          # ActiveRecord::Base.connection.close
        end
      elsif(user_id = cookies.signed[:user_id])
        begin
          user = User.find_by(id: user_id)
        rescue Exception => e
          logger.debug "@@@@@@@@@@ Thread is sleeping RESCUE #{e} @@@@@@@@@@@@@@@@"
        ensure
          logger.debug "@@@@@@@@@@ Thread in CURRENT_USER ENSURE @@@@@@@@@@@@@@@@"
          # User.connection_pool.release_connection
          User.connection.close
          logger.debug "@@@@@@@@@@ CURRENT_USER ENSURE ==> #{ActiveRecord::Base.connection_pool.stat} @@@@@@@@@@@@@@@@"
        end
        if user && user.authenticated?(cookies[:remember_token])
          log_in user
          @current_user = user
        end
      end
      return @current_user
    end

    def forget(user)
      user.forget
      cookies.delete(:user_id)
      cookies.delete(:remember_token)
    end

    def logged_in?
      !current_user.nil?
    end

    def log_out
      forget(current_user)
      session.delete(:user_id)
      @current_user = nil
    end

    def jwt_token(user)
      exp = Time.now.to_i + ENV.fetch("EXPIRE_AFTER_SECONDS") { 1.hour }.to_i
      payload = { :data => {email: user.email}, :exp => exp }
      hmac_secret = 'my$ecretK3y'
      JWT.encode payload, hmac_secret, 'HS256'
    end

    def generate_url(url, params = {})
      uri = URI(url)
      uri.query = params.to_query
      uri.to_s
    end

    def authenticate_or_redirect_to_login
      redirect_to root_url unless logged_in?
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end

class ApplicationController < ActionController::Base
  include AuthenticationsHelper
  before_action :authenticate_or_redirect_to_login, except: [:login, :logout]
end