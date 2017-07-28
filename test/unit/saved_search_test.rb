require 'test_helper'
require 'helpers/saved_search_test_helper'

class SavedSearchTest < ActiveSupport::TestCase
  include SavedSearchTestHelper

  def setup
    super
    mock_saved_search_service!
  end

  context ".queries_for" do
    setup do
      @user = FactoryGirl.create(:user)
      FactoryGirl.create(:saved_search, user: @user, query: "aaa")
    end

    should "fetch the queries used by a user" do
      assert_equal(%w(aaa), SavedSearch.queries_for(@user.id))
    end
  end

  context "Fetching the post ids for a search" do
    setup do
      SavedSearch.expects(:queries_for).with(1).returns(%w(a b c))
      stub_request(:post, "http://localhost:3001/v2/search").to_return(:body => "1 2 3 4")
    end

    should "return a list of ids" do
      post_ids = SavedSearch.post_ids(1)
      assert_equal([1,2,3,4], post_ids)
    end
  end

  context "Creating a saved search" do
    setup do
      @user = FactoryGirl.create(:gold_user)
      @saved_search = @user.saved_searches.create(:query => " ZZZ xxx ")
    end

    should "update the bitpref on the user" do
      @user.reload
      assert(@user.has_saved_searches?, "should have saved_searches bitpref set")
    end
  end

  context "Destroying a saved search" do
    setup do
      @user = FactoryGirl.create(:gold_user)
      @saved_search = @user.saved_searches.create(:tag_query => "xxx")
      @saved_search.destroy
    end

    should "update the bitpref on the user" do
      @user.reload
      assert(!@user.has_saved_searches?, "should not have the saved_searches bitpref set")
    end
  end

  context "A user with max saved searches" do
    setup do
      @user = FactoryGirl.create(:gold_user)
      User.any_instance.stubs(:max_saved_searches).returns(0)
      @saved_search = @user.saved_searches.create(:query => "xxx")
    end

    should "not be able to create another saved search" do
      assert_equal(["You can only have up to 0 saved searches"], @saved_search.errors.full_messages)
    end
  end
end
