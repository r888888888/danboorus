class ApplicationController < ActionController::Base
  protect_from_forgery
  helper :pagination
  before_filter :load_booru
  after_filter :reset_booru
  before_filter :load_user
  after_filter :reset_user
  before_filter :set_title
  before_filter :normalize_search
  before_filter :set_started_at_session
  before_filter :api_check
  before_filter :secure_cookies_check
  layout "default"
  # force_ssl :if => lambda {Rails.env.production?}

  rescue_from Exception, :with => :rescue_exception
  rescue_from User::PrivilegeError, :with => :access_denied
  rescue_from ActiveModel::ForbiddenAttributesError, :with => :access_denied
  rescue_from SessionLoader::AuthenticationFailure, :with => :authentication_failed
  rescue_from Danbooru::Paginator::PaginationError, :with => :render_pagination_limit
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found

  protected

  def load_booru
    if params[:boru_id]
      Booru.current = Booru.find_by_slug(params[:booru_id])
    else
      Booru.current = nil
    end
  end

  def reset_booru
    Booru.current = nil
  end

  def default_url_options
    if Booru.current
      {booru_id: Booru.current.slug}
    else
      nil
    end
  end

  def enable_cors
    response.headers["Access-Control-Allow-Origin"] = "*"
  end

  def api_check
    if !CurrentUser.is_anonymous? && !request.get? && !request.head?
      if CurrentUser.user.token_bucket.nil?
        TokenBucket.create_default(CurrentUser.user)
        CurrentUser.user.reload
      end

      throttled = CurrentUser.user.token_bucket.throttled?
      headers["X-Api-Limit"] = CurrentUser.user.token_bucket.token_count.to_s

      if throttled
        respond_to do |format|
          format.json do
            render json: {success: false, reason: "too many requests"}.to_json, status: 429
          end

          format.xml do
            render xml: {success: false, reason: "too many requests"}.to_xml(:root => "response"), status: 429
          end

          format.html do
            render :template => "static/too_many_requests", :status => 429
          end
        end

        return false
      end
    end

    return true
  end

  def rescue_exception(exception)
    @exception = exception

    if Rails.env.test?
      colorize = lambda do |text, color_code|
        "\e[#{color_code}m#{text}\e[0m"
      end
      print "\r" << (' ' * 50) << "\n"
      stacktrace = exception.backtrace.map do |call|
        if parts = call.match(/^(?<file>.+):(?<line>\d+):in `(?<code>.*)'$/)
          file = parts[:file].sub /^#{Regexp.escape(File.join(Dir.getwd, ''))}/, ''
          line = "#{colorize.call(file, 36)} #{colorize.call('(', 37)}#{colorize.call(parts[:line], 32)}#{colorize.call('): ', 37)} #{colorize.call(parts[:code], 31)}"
        else
          line = colorize.call(call, 31)
        end
        line
      end
      puts "#{exception.class}: #{exception.message}\n"
      stacktrace.each { |line| puts line }
    end

    if exception.is_a?(::ActiveRecord::StatementInvalid) && exception.to_s =~ /statement timeout/
      if Rails.env.production?
        NewRelic::Agent.notice_error(exception, :uri => request.original_url, :referer => request.referer, :request_params => params, :custom_params => {:user_id => CurrentUser.user.id, :user_ip_addr => CurrentUser.ip_addr})
      end

      @error_message = "The database timed out running your query."
      render :template => "static/error", :status => 500
    elsif exception.is_a?(::ActiveRecord::RecordNotFound)
      @error_message = "That record was not found"
      render :template => "static/error", :status => 404
    elsif exception.is_a?(NotImplementedError)
      flash[:notice] = "This feature isn't available: #{@exception.message}"
      respond_to do |fmt|
        fmt.html { redirect_to :back }
        fmt.json { render template: "static/error", status: 501 }
        fmt.xml  { render template: "static/error", status: 501 }
      end
    else
      render :template => "static/error", :status => 500
    end
  end

  def render_pagination_limit
    @error_message = "You can only view up to #{Danbooru.config.max_numbered_pages} pages. Please narrow your search terms."
    render :template => "static/error", :status => 410
  end

  def authentication_failed
    respond_to do |fmt|
      fmt.html do
        render :text => "authentication failed", :status => 401
      end

      fmt.xml do
        render :xml => {:sucess => false, :reason => "authentication failed"}.to_xml(:root => "response"), :status => 401
      end

      fmt.json do
        render :json => {:success => false, :reason => "authentication failed"}.to_json, :status => 401
      end
    end
  end

  def not_found(exception = nil)
    respond_to do |fmt|
      fmt.html do
        render template: "static/404", status: 404
      end
      fmt.xml do
        render :xml => {:success => false, :reason => "not found"}.to_xml(:root => "response"), :status => 404
      end
      fmt.json do
        render :json => {:success => false, :reason => "not found"}.to_json, :status => 404
      end
      fmt.js do
        render :nothing => true, :status => 404
      end
    end
  end

  def access_denied(exception = nil)
    previous_url = params[:url] || request.fullpath

    respond_to do |fmt|
      fmt.html do
        if CurrentUser.is_anonymous?
          if request.get?
            redirect_to new_session_path(:url => previous_url), :notice => "Access denied"
          else
            redirect_to new_session_path, :notice => "Access denied"
          end
        else
          render :template => "static/access_denied", :status => 403
        end
      end
      fmt.xml do
        render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 403
      end
      fmt.json do
        render :json => {:success => false, :reason => "access denied"}.to_json, :status => 403
      end
      fmt.js do
        render :nothing => true, :status => 403
      end
    end
  end

  def load_user
    session_loader = SessionLoader.new(session, cookies, request, params)
    session_loader.load
  end

  def reset_user
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def set_started_at_session
    if session[:started_at].blank?
      session[:started_at] = Time.now
    end
  end

  User::Roles.each do |role|
    define_method("#{role}_only") do
      if !CurrentUser.user.is_banned_or_ip_banned? && CurrentUser.user.__send__("is_#{role}?")
        true
      else
        access_denied()
        false
      end
    end
  end

  def set_title
    if Booru.current
      @page_title = Booru.current.name
    else
      @page_title = Danbooru.config.app_name
    end
  end

  def normalize_search
    if request.get?
      if params[:search].blank?
        params[:search] = {}
      end

      if params[:search].is_a?(Hash)
        changed = params[:search].reject! {|k,v| v.blank?}
        unless changed.nil?
          redirect_to url_for(params)
        end
      end
    end
  end

  def secure_cookies_check
    Rails.application.config.session_store :cookie_store, :key => '_danboorus_session', :secure => true
  end
end
