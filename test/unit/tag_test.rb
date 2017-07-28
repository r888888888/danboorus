require 'test_helper'

class TagTest < ActiveSupport::TestCase
  setup do
    user = FactoryGirl.create(:moderator_user)
    CurrentUser.user = user
    CurrentUser.ip_addr = "127.0.0.1"
  end

  teardown do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  context ".trending" do
    setup do
      Tag.stubs(:trending_count_limit).returns(0)

      Timecop.travel(1.week.ago) do
        FactoryGirl.create(:post, :tag_string => "aaa")
        FactoryGirl.create(:post, :tag_string => "bbb")
      end

      FactoryGirl.create(:post, :tag_string => "bbb")
      FactoryGirl.create(:post, :tag_string => "ccc")
    end

    should "order the results by the total post count" do
      assert_equal(["ccc", "bbb"], Tag.trending)
    end
  end

  context "A tag parser" do
    should "scan a query" do
      assert_equal(%w(aaa bbb), Tag.scan_query("aaa bbb"))
      assert_equal(%w(~AAa -BBB* -bbb*), Tag.scan_query("~AAa -BBB* -bbb*"))
    end

    should "not strip out valid characters when scanning" do
      assert_equal(%w(aaa bbb), Tag.scan_tags("aaa bbb"))
      assert_equal(%w(pool:ichigo_100%), Tag.scan_tags("pool:ichigo_100%"))
    end

    should "cast values" do
      assert_equal(2048, Tag.parse_cast("2kb", :filesize))
      assert_equal(2097152, Tag.parse_cast("2m", :filesize))
      assert_nothing_raised {Tag.parse_cast("2009-01-01", :date)}
      assert_nothing_raised {Tag.parse_cast("1234", :integer)}
      assert_nothing_raised {Tag.parse_cast("1234.56", :float)}
    end

    should "parse a query" do
      tag1 = FactoryGirl.create(:tag, :name => "abc")
      tag2 = FactoryGirl.create(:tag, :name => "acb")

      assert_equal(["abc"], Tag.parse_query("md5:abc")[:md5])
      assert_equal([:between, 1, 2], Tag.parse_query("id:1..2")[:post_id])
      assert_equal([:gte, 1], Tag.parse_query("id:1..")[:post_id])
      assert_equal([:lte, 2], Tag.parse_query("id:..2")[:post_id])
      assert_equal([:gt, 2], Tag.parse_query("id:>2")[:post_id])
      assert_equal([:lt, 3], Tag.parse_query("id:<3")[:post_id])

      Tag.expects(:normalize_tags_in_query).returns(nil)
      assert_equal(["acb"], Tag.parse_query("a*b")[:tags][:include])
    end
  end

  context "A tag" do
    should "be found when one exists" do
      tag = FactoryGirl.create(:tag)
      assert_difference("Tag.count", 0) do
        Tag.find_or_create_by_name(tag.name)
      end
    end

    should "be created when one doesn't exist" do
      assert_difference("Tag.count", 1) do
        tag = Tag.find_or_create_by_name("hoge")
        assert_equal("hoge", tag.name)
      end
    end

    context "during name validation" do
      # tags with spaces or uppercase are allowed because they are normalized
      # to lowercase with underscores.
      should allow_value(" foo ").for(:name).on(:create)
      should allow_value("foo bar").for(:name).on(:create)
      should allow_value("FOO").for(:name).on(:create)

      should_not allow_value("").for(:name).on(:create)
      should_not allow_value("___").for(:name).on(:create)
      should_not allow_value("~foo").for(:name).on(:create)
      should_not allow_value("-foo").for(:name).on(:create)
      should_not allow_value("_foo").for(:name).on(:create)
      should_not allow_value("foo_").for(:name).on(:create)
      should_not allow_value("foo__bar").for(:name).on(:create)
      should_not allow_value("foo*bar").for(:name).on(:create)
      should_not allow_value("foo,bar").for(:name).on(:create)
      should_not allow_value("foo\abar").for(:name).on(:create)
      should_not allow_value("café").for(:name).on(:create)
      should_not allow_value("東方").for(:name).on(:create)

      metatags = Tag::METATAGS.split("|") + Tag::SUBQUERY_METATAGS.split("|")
      metatags.split("|").each do |metatag|
        should_not allow_value("#{metatag}:foo").for(:name).on(:create)
      end
    end
  end

  context "A tag with a negative post count" do
    should "be fixed" do
      tag = FactoryGirl.create(:tag, name: "touhou", post_count: -10)
      post = FactoryGirl.create(:post, tag_string: "touhou")

      Tag.clean_up_negative_post_counts!
      assert_equal(1, tag.reload.post_count)
    end
  end
end
