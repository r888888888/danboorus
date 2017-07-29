ENV["RAILS_ENV"] = "test"

if ENV["SIMPLECOV"]
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_group "Libraries", ["app/logical", "lib"]
    add_group "Presenters", "app/presenters"
  end
end

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'cache'
require 'webmock/minitest'

Dir[File.expand_path(File.dirname(__FILE__) + "/factories/*.rb")].each {|file| require file}
Dir[File.expand_path(File.dirname(__FILE__) + "/helpers/*.rb")].each {|file| require file}

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.library :rails
  end
end

class ActiveSupport::TestCase
  include PostArchiveTestHelper
  include DownloadTestHelper

  setup do
    WebMock.allow_net_connect!
  end

  teardown do
    Cache.clear
  end
end

class ActionController::TestCase
  include PostArchiveTestHelper

  def assert_authentication_passes(action, http_method, role, params, session)
    __send__(http_method, action, params, session.merge(:user_id => @users[role].id))
    assert_response :success
  end

  def assert_authentication_fails(action, http_method, role)
    __send__(http_method, action, params, session.merge(:user_id => @users[role].id))
    assert_redirected_to(new_sessions_path)
  end

  teardown do
    Cache.clear
  end
end

Delayed::Worker.delay_jobs = false
TestAfterCommit.enabled = false
