require 'test_helper'

class UserTest < ActiveSupport::TestCase
  include DefaultHelper

  context "A user" do
    setup do
      @user = FactoryGirl.create(:user)
      CurrentUser.test!(@user)
    end

    teardown do
      CurrentUser.clear!
    end

    context "promoting a user" do
      setup do
        CurrentUser.test!(FactoryGirl.create(:moderator_user))
      end

      should "create a feedback" do
        assert_difference("UserFeedback.count") do
          @user.promote_to!(User::Levels::GOLD)
        end

        assert_equal("You have been promoted to a Gold level account from Basic.", @user.feedback.last.body)
      end

      should "send an automated dmail to the user" do
        bot = FactoryGirl.create(:user)
        Danbooru.config.stubs(:system_user).returns(bot)

        assert_difference("Dmail.count", 1) do
          @user.promote_to!(User::Levels::GOLD)
        end

        assert(@user.dmails.exists?(from: bot, to: @user, title: "You have been promoted"))
      end
    end

    context "favoriting a post" do
      setup do
        @user.update_column(:favorite_count, 999)
        @user.stubs(:clean_favorite_count?).returns(true)
        @post = FactoryGirl.create(:post)
      end

      should "periodically clean the favorite_count" do
        @user.add_favorite!(@post)
        assert_equal(1, @user.favorite_count)
      end
    end

    should "not validate if the originating ip address is banned" do
      FactoryGirl.create(:ip_ban)
      user = FactoryGirl.build(:user)
      user.save
      assert(user.errors.any?)
      assert_equal("IP address is banned", user.errors.full_messages.join)
    end

    should "authenticate" do
      assert(User.authenticate(@user.name, "password"), "Authentication should have succeeded")
      assert(!User.authenticate(@user.name, "password2"), "Authentication should not have succeeded")
    end

    should "normalize its level" do
      user = FactoryGirl.create(:user, :level => User::Levels::ADMIN)
      CurrentUser.scoped(user) do
        assert(user.is_moderator?)
        assert(user.is_gold?)
      end

      user = FactoryGirl.create(:user)
      CurrentUser.scoped(user) do
        FactoryGirl.create(:membership, is_moderator: true)
        assert(!user.is_admin?)
        assert(user.is_moderator?)
        assert(!user.is_gold?)
      end

      user = FactoryGirl.create(:user, :level => User::Levels::GOLD)
      CurrentUser.scoped(user) do
        assert(!user.is_admin?)
        assert(!user.is_moderator?)
        assert(user.is_gold?)
      end

      user = FactoryGirl.create(:user)
      CurrentUser.scoped(user) do
        assert(!user.is_admin?)
        assert(!user.is_moderator?)
        assert(!user.is_gold?)
      end
    end

    context "name" do
      should "be #{Danbooru.config.default_guest_name} given an invalid user id" do
        assert_equal(Danbooru.config.default_guest_name, User.id_to_name(-1))
      end

      should "not contain whitespace" do
        # U+2007: https://en.wikipedia.org/wiki/Figure_space
        user = FactoryGirl.build(:user, :name => "foo\u2007bar")
        user.save
        assert_equal(["Name cannot have whitespace or colons"], user.errors.full_messages)
      end

      should "not contain a colon" do
        user = FactoryGirl.build(:user, :name => "a:b")
        user.save
        assert_equal(["Name cannot have whitespace or colons"], user.errors.full_messages)
      end

      should "not begin with an underscore" do
        user = FactoryGirl.build(:user, :name => "_x")
        user.save
        assert_equal(["Name cannot begin or end with an underscore"], user.errors.full_messages)
      end

      should "not end with an underscore" do
        user = FactoryGirl.build(:user, :name => "x_")
        user.save
        assert_equal(["Name cannot begin or end with an underscore"], user.errors.full_messages)
      end

      should "be fetched given a user id" do
        @user = FactoryGirl.create(:user)
        assert_equal(@user.name, User.id_to_name(@user.id))
      end

      should "be updated" do
        @user = FactoryGirl.create(:user)
        @user.update_attribute(:name, "danzig")
        assert_equal(@user.name, User.id_to_name(@user.id))
      end
    end

    context "ip address" do
      setup do
        @user = FactoryGirl.create(:user)
      end

      context "in the json representation" do
        should "not appear" do
          assert(@user.to_json !~ /addr/)
        end
      end

      context "in the xml representation" do
        should "not appear" do
          assert(@user.to_xml !~ /addr/)
        end
      end
    end

    context "password" do
      should "match the confirmation" do
        @user = FactoryGirl.create(:user)
        @user.old_password = "password"
        @user.password = "zugzug5"
        @user.password_confirmation = "zugzug5"
        @user.save
        @user.reload
        assert(User.authenticate(@user.name, "zugzug5"), "Authentication should have succeeded")
      end

      should "fail if the confirmation does not match" do
        @user = FactoryGirl.create(:user)
        @user.password = "zugzug6"
        @user.password_confirmation = "zugzug5"
        @user.save
        assert_equal(["Password confirmation doesn't match Password"], @user.errors.full_messages)
      end

      should "not be too short" do
        @user = FactoryGirl.create(:user)
        @user.password = "x5"
        @user.password_confirmation = "x5"
        @user.save
        assert_equal(["Password is too short (minimum is 5 characters)"], @user.errors.full_messages)
      end

      should "should be reset" do
        @user = FactoryGirl.create(:user)
        new_pass = @user.reset_password
        assert(User.authenticate(@user.name, new_pass), "Authentication should have succeeded")
      end

      should "not change the password if the password and old password are blank" do
        @user = FactoryGirl.create(:user, :password => "67890")
        @user.update_attributes(:password => "", :old_password => "")
        assert(@user.bcrypt_password == User.salt_password("67890"))
      end

      should "not change the password if the old password is incorrect" do
        @user = FactoryGirl.create(:user, :password => "67890")
        @user.update_attributes(:password => "12345", :old_password => "abcdefg")
        assert(@user.bcrypt_password == User.salt_password("67890"))
      end

      should "not change the password if the old password is blank" do
        @user = FactoryGirl.create(:user, :password => "67890")
        @user.update_attributes(:password => "12345", :old_password => "")
        assert(@user.bcrypt_password == User.salt_password("67890"))
      end

      should "change the password if the old password is correct" do
        @user = FactoryGirl.create(:user, :password => "67890")
        @user.update_attributes(:password => "12345", :old_password => "67890")
        assert(@user.bcrypt_password == User.salt_password("12345"))
      end

      context "in the json representation" do
        setup do
          @user = FactoryGirl.create(:user)
        end

        should "not appear" do
          assert(@user.to_json !~ /password/)
        end
      end

      context "in the xml representation" do
        setup do
          @user = FactoryGirl.create(:user)
        end

        should "not appear" do
          assert(@user.to_xml !~ /password/)
        end
      end
    end

    context "when searched by name" do
      should "match wildcards" do
        user1 = FactoryGirl.create(:user, :name => "foo")
        user2 = FactoryGirl.create(:user, :name => "foo*bar")
        user3 = FactoryGirl.create(:user, :name => "bar\*baz")

        assert_equal([user2.id, user1.id], User.search(name: "foo*").map(&:id))
        assert_equal([user2.id], User.search(name: "foo\*bar").map(&:id))
        assert_equal([user3.id], User.search(name: "bar\\\*baz").map(&:id))
      end
    end
  end
end
