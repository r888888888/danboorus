require 'test_helper'
require 'helpers/pool_archive_test_helper'
require 'helpers/saved_search_test_helper'

class PostTest < ActiveSupport::TestCase
  include PoolArchiveTestHelper
  include SavedSearchTestHelper

  def assert_tag_match(posts, query)
    assert_equal(posts.map(&:id), Post.tag_match(query).pluck(:id))
  end

  def setup
    super

    Timecop.travel(2.weeks.ago) do
      @user = FactoryGirl.create(:member_user)
    end
    CurrentUser.user = @user
    CurrentUser.ip_addr = "127.0.0.1"
    mock_saved_search_service!
  end

  def teardown
    super

    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  context "Deletion:" do
    context "Expunging a post" do
      setup do
        @upload = FactoryGirl.create(:jpg_upload)
        @upload.process!
        @post = @upload.post
        Favorite.add(post: @post, user: @user)
      end

      should "delete the files" do
        assert_equal(true, File.exists?(@post.preview_file_path))
        assert_equal(true, File.exists?(@post.large_file_path))
        assert_equal(true, File.exists?(@post.file_path))

        TestAfterCommit.with_commits(true) do
          @post.expunge!
        end

        assert_equal(false, File.exists?(@post.preview_file_path))
        assert_equal(false, File.exists?(@post.large_file_path))
        assert_equal(false, File.exists?(@post.file_path))
      end

      should "remove all favorites" do
        TestAfterCommit.with_commits(true) do
          @post.expunge!
        end

        assert_equal(0, Favorite.for_user(@user.id).where("post_id = ?", @post.id).count)
      end

      context "that is status locked" do
        setup do
          @post.update_attributes({:is_status_locked => true}, :as => :admin)
        end

        should "not destroy the record" do
          @post.expunge!
          assert_equal(1, Post.where("id = ?", @post.id).count)
        end
      end

      context "that belongs to a pool" do
        setup do
          SqsService.any_instance.stubs(:send_message)
          @pool = FactoryGirl.create(:pool)
          @pool.add!(@post)

          @deleted_pool = FactoryGirl.create(:pool)
          @deleted_pool.add!(@post)
          @deleted_pool.update_columns(is_deleted: true)

          @post.expunge!
          @pool.reload
          @deleted_pool.reload
        end

        should "remove the post from all pools" do
          assert_equal("", @pool.post_ids)
        end

        should "remove the post from deleted pools" do
          assert_equal("", @deleted_pool.post_ids)
        end

        should "destroy the record" do
          assert_equal([], @post.errors.full_messages)
          assert_equal(0, Post.where("id = ?", @post.id).count)
        end
      end
    end

    context "Deleting a post" do
      setup do
        Danbooru.config.stubs(:blank_tag_search_fast_count).returns(nil)
      end

      context "that is status locked" do
        setup do
          @post = FactoryGirl.create(:post)
          @post.update_attributes({:is_status_locked => true}, :as => :admin)
        end

        should "fail" do
          @post.delete!("test")
          assert_equal(["Is status locked ; cannot delete post"], @post.errors.full_messages)
          assert_equal(1, Post.where("id = ?", @post.id).count)
        end
      end

      should "update the fast count" do
        Danbooru.config.stubs(:estimate_post_counts).returns(false)
        post = FactoryGirl.create(:post, :tag_string => "aaa")
        assert_equal(1, Post.fast_count)
        assert_equal(1, Post.fast_count("aaa"))
        post.delete!("test")
        assert_equal(1, Post.fast_count)
        assert_equal(1, Post.fast_count("aaa"))
      end

      should "toggle the is_deleted flag" do
        post = FactoryGirl.create(:post)
        assert_equal(false, post.is_deleted?)
        post.delete!("test")
        assert_equal(true, post.is_deleted?)
      end

      should "not decrement the tag counts" do
        post = FactoryGirl.create(:post, :tag_string => "aaa")
        assert_equal(1, Tag.find_by_name("aaa").post_count)
        post.delete!("test")
        assert_equal(1, Tag.find_by_name("aaa").post_count)
      end
    end
  end

  context "Parenting:" do
    context "Assigning a parent to a post" do
      should "update the has_children flag on the parent" do
        p1 = FactoryGirl.create(:post)
        assert(!p1.has_children?, "Parent should not have any children")
        c1 = FactoryGirl.create(:post, :parent_id => p1.id)
        p1.reload
        assert(p1.has_children?, "Parent not updated after child was added")
      end

      should "update the has_children flag on the old parent" do
        p1 = FactoryGirl.create(:post)
        p2 = FactoryGirl.create(:post)
        c1 = FactoryGirl.create(:post, :parent_id => p1.id)
        c1.parent_id = p2.id
        c1.save
        p1.reload
        p2.reload
        assert(!p1.has_children?, "Old parent should not have a child")
        assert(p2.has_children?, "New parent should have a child")
      end
    end

    context "Expunging a post with" do
      context "a parent" do
        should "reset the has_children flag of the parent" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          c1.expunge!
          p1.reload
          assert_equal(false, p1.has_children?)
        end

        should "reassign favorites to the parent" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          user = FactoryGirl.create(:user)
          c1.add_favorite!(user)
          c1.expunge!
          p1.reload
          assert(!Favorite.exists?(:post_id => c1.id, :user_id => user.id))
          assert(Favorite.exists?(:post_id => p1.id, :user_id => user.id))
          assert_equal(0, c1.score)
        end

        should "update the parent's has_children flag" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          c1.expunge!
          p1.reload
          assert(!p1.has_children?, "Parent should not have children")
        end
      end

      context "one child" do
        should "remove the parent of that child" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          p1.expunge!
          c1.reload
          assert_nil(c1.parent)
        end
      end

      context "two or more children" do
        setup do
          # ensure initial post versions won't be merged.
          travel_to(1.day.ago) do
            @p1 = FactoryGirl.create(:post)
            @c1 = FactoryGirl.create(:post, :parent_id => @p1.id)
            @c2 = FactoryGirl.create(:post, :parent_id => @p1.id)
            @c3 = FactoryGirl.create(:post, :parent_id => @p1.id)
          end
        end

        should "reparent all children to the first child" do
          @p1.expunge!
          @c1.reload
          @c2.reload
          @c3.reload

          assert_nil(@c1.parent_id)
          assert_equal(@c1.id, @c2.parent_id)
          assert_equal(@c1.id, @c3.parent_id)
        end

        should "save a post version record for each child" do
          assert_difference(["@c1.versions.count", "@c2.versions.count", "@c3.versions.count"]) do
            @p1.expunge!
            @c1.reload
            @c2.reload
            @c3.reload
          end
        end

        should "set the has_children flag on the new parent" do
          @p1.expunge!
          assert_equal(true, @c1.reload.has_children?)
        end
      end
    end
    
    context "Deleting a post with" do
      context "a parent" do
        should "not reassign favorites to the parent by default" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          user = FactoryGirl.create(:gold_user)
          c1.add_favorite!(user)
          c1.delete!("test")
          p1.reload
          assert(Favorite.exists?(:post_id => c1.id, :user_id => user.id))
          assert(!Favorite.exists?(:post_id => p1.id, :user_id => user.id))
        end

        should "reassign favorites to the parent if specified" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          user = FactoryGirl.create(:gold_user)
          c1.add_favorite!(user)
          c1.delete!("test", :move_favorites => true)
          p1.reload
          assert(!Favorite.exists?(:post_id => c1.id, :user_id => user.id), "Child should not still have favorites")
          assert(Favorite.exists?(:post_id => p1.id, :user_id => user.id), "Parent should have favorites")
        end

        should "not update the parent's has_children flag" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          c1.delete!("test")
          p1.reload
          assert(p1.has_children?, "Parent should have children")
        end
      end

      context "one child" do
        should "not remove the has_children flag" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          p1.delete!("test")
          p1.reload
          assert_equal(true, p1.has_children?)
        end

        should "not remove the parent of that child" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          p1.delete!("test")
          c1.reload
          assert_not_nil(c1.parent)
        end
      end

      context "two or more children" do
        should "not reparent all children to the first child" do
          p1 = FactoryGirl.create(:post)
          c1 = FactoryGirl.create(:post, :parent_id => p1.id)
          c2 = FactoryGirl.create(:post, :parent_id => p1.id)
          c3 = FactoryGirl.create(:post, :parent_id => p1.id)
          p1.delete!("test")
          c1.reload
          c2.reload
          c3.reload
          assert_equal(p1.id, c1.parent_id)
          assert_equal(p1.id, c2.parent_id)
          assert_equal(p1.id, c3.parent_id)
        end
      end
    end

    context "Undeleting a post with a parent" do
      should "preserve the parent's has_children flag" do
        p1 = FactoryGirl.create(:post)
        c1 = FactoryGirl.create(:post, :parent_id => p1.id)
        c1.delete!("test")
        c1.undelete!
        p1.reload
        assert_not_nil(c1.parent_id)
        assert(p1.has_children?, "Parent should have children")
      end
    end
  end

  context "Moderation:" do
    context "A deleted post" do
      setup do
        @post = FactoryGirl.create(:post, :is_deleted => true)
      end

      context "that is status locked" do
        setup do
          @post.update_attributes({:is_status_locked => true}, :as => :admin)
        end

        should "not allow undeletion" do
          @post.undelete!
          assert_equal(["Is status locked ; cannot undelete post"], @post.errors.full_messages)
          assert_equal(true, @post.is_deleted?)
        end
      end

      context "when undeleted" do
        should "be undeleted" do
          @post.undelete!
          assert_equal(false, @post.reload.is_deleted?)
        end

        should "create a mod action" do
          @post.undelete!
          assert_equal("undeleted post ##{@post.id}", ModAction.last.description)
        end
      end
    end

    context "A status locked post" do
      setup do
        @post = FactoryGirl.create(:post)
        @post.update_attributes({:is_status_locked => true}, :as => :admin)
      end
    end
  end

  context "Tagging:" do
    context "A post" do
      setup do
        @post = FactoryGirl.create(:post)
      end

      context "as a new user" do
        setup do
          @post.update(:tag_string => "aaa bbb ccc ddd tagme")
          CurrentUser.user = FactoryGirl.create(:user)
        end

        should "allow you to remove request tags" do
          @post.update_attributes(:tag_string => "aaa bbb ccc ddd")
          @post.reload
          assert_equal("aaa bbb ccc ddd", @post.tag_string)
        end
      end

      context "tagged with a valid tag" do
        subject { @post }

        should allow_value("touhou 100%").for(:tag_string)
        should allow_value("touhou FOO").for(:tag_string)
        should allow_value("touhou -foo").for(:tag_string)
        should allow_value("touhou pool:foo").for(:tag_string)
        should allow_value("touhou -pool:foo").for(:tag_string)
        should allow_value("touhou newpool:foo").for(:tag_string)
        should allow_value("touhou fav:self").for(:tag_string)
        should allow_value("touhou -fav:self").for(:tag_string)
        should allow_value("touhou upvote:self").for(:tag_string)
        should allow_value("touhou downvote:self").for(:tag_string)
        should allow_value("touhou parent:1").for(:tag_string)
        should allow_value("touhou child:1").for(:tag_string)
        should allow_value("touhou source:foo").for(:tag_string)
        should allow_value("touhou rating:z").for(:tag_string)
        should allow_value("touhou locked:rating").for(:tag_string)
        should allow_value("touhou -locked:rating").for(:tag_string)

        # \u3000 = ideographic space, \u00A0 = no-break space
        should allow_value("touhou\u3000foo").for(:tag_string)
        should allow_value("touhou\u00A0foo").for(:tag_string)
      end

      context "tagged with an invalid tag" do
        subject { @post }

        context "that doesn't already exist" do
          should_not allow_value("touhou user:evazion").for(:tag_string)
          should_not allow_value("touhou *~foo").for(:tag_string)
          should_not allow_value("touhou *-foo").for(:tag_string)
          should_not allow_value("touhou ,-foo").for(:tag_string)

          should_not allow_value("touhou ___").for(:tag_string)
          should_not allow_value("touhou ~foo").for(:tag_string)
          should_not allow_value("touhou _foo").for(:tag_string)
          should_not allow_value("touhou foo_").for(:tag_string)
          should_not allow_value("touhou foo__bar").for(:tag_string)
          should_not allow_value("touhou foo*bar").for(:tag_string)
          should_not allow_value("touhou foo,bar").for(:tag_string)
          should_not allow_value("touhou foo\abar").for(:tag_string)
          should_not allow_value("touhou café").for(:tag_string)
          should_not allow_value("touhou 東方").for(:tag_string)
        end

        context "that already exists" do
          setup do
            %W(___ ~foo _foo foo_ foo__bar foo*bar foo,bar foo\abar café 東方).each do |tag|
              FactoryGirl.build(:tag, name: tag).save(validate: false)
            end
          end

          should allow_value("touhou ___").for(:tag_string)
          should allow_value("touhou ~foo").for(:tag_string)
          should allow_value("touhou _foo").for(:tag_string)
          should allow_value("touhou foo_").for(:tag_string)
          should allow_value("touhou foo__bar").for(:tag_string)
          should allow_value("touhou foo*bar").for(:tag_string)
          should allow_value("touhou foo,bar").for(:tag_string)
          should allow_value("touhou foo\abar").for(:tag_string)
          should allow_value("touhou café").for(:tag_string)
          should allow_value("touhou 東方").for(:tag_string)
        end
      end

      context "tagged with a metatag" do
        context "for a parent" do
          setup do
            @parent = FactoryGirl.create(:post)
          end

          should "update the parent relationships for both posts" do
            @post.update_attributes(:tag_string => "aaa parent:#{@parent.id}")
            @post.reload
            @parent.reload
            assert_equal(@parent.id, @post.parent_id)
            assert(@parent.has_children?)
          end

          should "not allow self-parenting" do
            @post.update(:tag_string => "parent:#{@post.id}")
            assert_nil(@post.parent_id)
          end

          should "clear the parent with parent:none" do
            @post.update(:parent_id => @parent.id)
            assert_equal(@parent.id, @post.parent_id)

            @post.update(:tag_string => "parent:none")
            assert_nil(@post.parent_id)
          end

          should "clear the parent with -parent:1234" do
            @post.update(:parent_id => @parent.id)
            assert_equal(@parent.id, @post.parent_id)

            @post.update(:tag_string => "-parent:#{@parent.id}")
            assert_nil(@post.parent_id)
          end
        end

        context "for a pool" do
          setup do
            mock_pool_archive_service!
            start_pool_archive_transaction
          end

          teardown do
            rollback_pool_archive_transaction
          end

          context "on creation" do
            setup do
              @pool = FactoryGirl.create(:pool)
              @post = FactoryGirl.create(:post, :tag_string => "aaa pool:#{@pool.id}")
            end

            should "add the post to the pool" do
              @post.reload
              @pool.reload
              assert_equal("#{@post.id}", @pool.post_ids)
              assert_equal("pool:#{@pool.id} pool:series", @post.pool_string)
            end
          end

          context "negated" do
            setup do
              @pool = FactoryGirl.create(:pool)
              @post = FactoryGirl.create(:post, :tag_string => "aaa")
              @post.add_pool!(@pool)
              @post.tag_string = "aaa -pool:#{@pool.id}"
              @post.save
            end

            should "remove the post from the pool" do
              @post.reload
              @pool.reload
              assert_equal("", @pool.post_ids)
              assert_equal("", @post.pool_string)
            end
          end

          context "id" do
            setup do
              @pool = FactoryGirl.create(:pool)
              @post.update_attributes(:tag_string => "aaa pool:#{@pool.id}")
            end

            should "add the post to the pool" do
              @post.reload
              @pool.reload
              assert_equal("#{@post.id}", @pool.post_ids)
              assert_equal("pool:#{@pool.id} pool:series", @post.pool_string)
            end
          end

          context "name" do
            context "that exists" do
              setup do
                @pool = FactoryGirl.create(:pool, :name => "abc")
                @post.update_attributes(:tag_string => "aaa pool:abc")
              end

              should "add the post to the pool" do
                @post.reload
                @pool.reload
                assert_equal("#{@post.id}", @pool.post_ids)
                assert_equal("pool:#{@pool.id} pool:series", @post.pool_string)
              end
            end

            context "that doesn't exist" do
              should "create a new pool and add the post to that pool" do
                @post.update_attributes(:tag_string => "aaa newpool:abc")
                @pool = Pool.find_by_name("abc")
                @post.reload
                assert_not_nil(@pool)
                assert_equal("#{@post.id}", @pool.post_ids)
                assert_equal("pool:#{@pool.id} pool:series", @post.pool_string)
              end
            end

            context "with special characters" do
              should "not strip '%' from the name" do
                @post.update(tag_string: "aaa newpool:ichigo_100%")
                assert(Pool.exists?(name: "ichigo_100%"))
              end
            end
          end
        end

        context "for a rating" do
          context "that is valid" do
            should "update the rating if the post is unlocked" do
              @post.update_attributes(:tag_string => "aaa rating:e")
              @post.reload
              assert_equal("e", @post.rating)
            end
          end

          context "that is invalid" do
            should "not update the rating" do
              @post.update_attributes(:tag_string => "aaa rating:z")
              @post.reload
              assert_equal("s", @post.rating)
            end
          end

          context "that is locked" do
            should "change the rating if locked in the same update" do
              @post.update({ :tag_string => "rating:e", :is_rating_locked => true }, :as => :moderator)

              assert(@post.valid?)
              assert_equal("e", @post.reload.rating)
            end

            should "not change the rating if locked previously" do
              @post.is_rating_locked = true
              @post.save

              @post.update(:tag_string => "rating:e")

              assert(@post.invalid?)
              assert_not_equal("e", @post.reload.rating)
            end
          end
        end

        context "for a fav" do
          should "add/remove the current user to the post's favorite listing" do
            @post.update_attributes(:tag_string => "aaa fav:self")
            assert_equal("fav:#{@user.id}", @post.fav_string)

            @post.update_attributes(:tag_string => "aaa -fav:self")
            assert_equal("", @post.fav_string)
          end
        end

        context "for a child" do
          setup do
            @child = FactoryGirl.create(:post)
          end

          should "update the parent relationships for both posts" do
            @post.update_attributes(:tag_string => "aaa child:#{@child.id}")
            @post.reload
            @child.reload
            assert_equal(@post.id, @child.parent_id)
            assert(@post.has_children?)
          end
        end

        context "for a source" do
          should "set the source with source:foo_bar_baz" do
            @post.update(:tag_string => "source:foo_bar_baz")
            assert_equal("foo_bar_baz", @post.source)
          end

          should 'set the source with source:"foo bar baz"' do
            @post.update(:tag_string => 'source:"foo bar baz"')
            assert_equal("foo bar baz", @post.source)
          end

          should 'strip the source with source:"  foo bar baz  "' do
            @post.update(:tag_string => 'source:"  foo bar baz  "')
            assert_equal("foo bar baz", @post.source)
          end

          should "clear the source with source:none" do
            @post.update(:source => "foobar")
            @post.update(:tag_string => "source:none")
            assert_equal("", @post.source)
          end

          should "set the pixiv id with source:https://img18.pixiv.net/img/evazion/14901720.png" do
            @post.update(:tag_string => "source:https://img18.pixiv.net/img/evazion/14901720.png")
            assert_equal(14901720, @post.pixiv_id)
          end
        end

        context "of" do
          setup do
            @moderator = FactoryGirl.create(:moderator_user)
          end

          context "locked:notes" do
            context "by a member" do
              should "not lock the notes" do
                @post.update(:tag_string => "locked:notes")
                assert_equal(false, @post.is_note_locked)
              end
            end

            context "by a moderator" do
              should "lock/unlock the notes" do
                CurrentUser.scoped(@moderator) do
                  @post.update(:tag_string => "locked:notes")
                  assert_equal(true, @post.is_note_locked)

                  @post.update(:tag_string => "-locked:notes")
                  assert_equal(false, @post.is_note_locked)
                end
              end
            end
          end

          context "locked:rating" do
            context "by a member" do
              should "not lock the rating" do
                @post.update(:tag_string => "locked:rating")
                assert_equal(false, @post.is_rating_locked)
              end
            end

            context "by a moderator" do
              should "lock/unlock the rating" do
                CurrentUser.scoped(@moderator) do
                  @post.update(:tag_string => "locked:rating")
                  assert_equal(true, @post.is_rating_locked)

                  @post.update(:tag_string => "-locked:rating")
                  assert_equal(false, @post.is_rating_locked)
                end
              end
            end
          end

          context "locked:status" do
            context "by a member" do
              should "not lock the status" do
                @post.update(:tag_string => "locked:status")
                assert_equal(false, @post.is_status_locked)
              end
            end

            context "by an admin" do
              should "lock/unlock the status" do
                CurrentUser.scoped(FactoryGirl.create(:admin_user)) do
                  @post.update(:tag_string => "locked:status")
                  assert_equal(true, @post.is_status_locked)

                  @post.update(:tag_string => "-locked:status")
                  assert_equal(false, @post.is_status_locked)
                end
              end
            end
          end
        end

        context "of" do
          setup do
            @gold = FactoryGirl.create(:gold_user)
          end

          context "upvote:self or downvote:self" do
            context "by a member" do
              should "upvote the post" do
                @post.update(:tag_string => "upvote:self")
                assert_equal(1, @post.score)
              end

              should "downvote the post" do
                @post.update(:tag_string => "downvote:self")
                assert_equal(-1, @post.score)
              end
            end

            context "by a gold user" do
              should "upvote the post" do
                CurrentUser.scoped(FactoryGirl.create(:gold_user)) do
                  @post.update(:tag_string => "tag1 tag2 upvote:self")
                  assert_equal(false, @post.errors.any?)
                  assert_equal(1, @post.score)
                end
              end

              should "downvote the post" do
                CurrentUser.scoped(FactoryGirl.create(:gold_user)) do
                  @post.update(:tag_string => "tag1 tag2 downvote:self")
                  assert_equal(false, @post.errors.any?)
                  assert_equal(-1, @post.score)
                end
              end
            end
          end
        end
      end

      context "tagged with a negated tag" do
        should "remove the tag if present" do
          @post.update_attributes(:tag_string => "aaa bbb ccc")
          @post.update_attributes(:tag_string => "aaa bbb ccc -bbb")
          @post.reload
          assert_equal("aaa ccc", @post.tag_string)
        end
      end

      should "have an array representation of its tags" do
        post = FactoryGirl.create(:post)
        post.set_tag_string("aaa bbb")
        assert_equal(%w(aaa bbb), post.tag_array)
        assert_equal(%w(tag1 tag2), post.tag_array_was)
      end

      context "with large dimensions" do
        setup do
          @post.image_width = 10_000
          @post.image_height = 10
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate dimension tags added automatically" do
          assert_match(/incredibly_absurdres/, @post.tag_string)
          assert_match(/absurdres/, @post.tag_string)
          assert_match(/highres/, @post.tag_string)
        end
      end

      context "with a large file size" do
        setup do
          @post.file_size = 11.megabytes
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate file size tags added automatically" do
          assert_match(/huge_filesize/, @post.tag_string)
        end
      end

      context "with a .zip file extension" do
        setup do
          @post.file_ext = "zip"
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate file type tag added automatically" do
          assert_match(/ugoira/, @post.tag_string)
        end
      end

      context "with a .webm file extension" do
        setup do
          @post.file_ext = "webm"
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate file type tag added automatically" do
          assert_match(/webm/, @post.tag_string)
        end
      end

      context "with a .swf file extension" do
        setup do
          @post.file_ext = "swf"
          @post.tag_string = ""
          @post.save
        end

        should "have the appropriate file type tag added automatically" do
          assert_match(/flash/, @post.tag_string)
        end
      end

      context "that has been updated" do
        should "create a new version if it's the first version" do
          assert_difference("PostArchive.count", 1) do
            post = FactoryGirl.create(:post)
          end
        end

        should "create a new version if it's been over an hour since the last update" do
          post = FactoryGirl.create(:post)
          Timecop.travel(6.hours.from_now) do
            assert_difference("PostArchive.count", 1) do
              post.update_attributes(:tag_string => "zzz")
            end
          end
        end

        should "merge with the previous version if the updater is the same user and it's been less than an hour" do
          post = FactoryGirl.create(:post)
          assert_difference("PostArchive.count", 0) do
            post.update_attributes(:tag_string => "zzz")
          end
          assert_equal("zzz", post.versions.last.tags)
        end

        should "increment the updater's post_update_count" do
          PostArchive.sqs_service.stubs(:merge?).returns(false)
          post = FactoryGirl.create(:post, :tag_string => "aaa bbb ccc")
          CurrentUser.reload

          assert_difference("CurrentUser.post_update_count", 1) do
            post.update_attributes(:tag_string => "zzz")
            CurrentUser.reload
          end
        end

        should "reset its tag array cache" do
          post = FactoryGirl.create(:post, :tag_string => "aaa bbb ccc")
          user = FactoryGirl.create(:user)
          assert_equal(%w(aaa bbb ccc), post.tag_array)
          post.tag_string = "ddd eee fff"
          post.tag_string = "ddd eee fff"
          post.save
          assert_equal("ddd eee fff", post.tag_string)
          assert_equal(%w(ddd eee fff), post.tag_array)
        end

        should "create the actual tag records" do
          assert_difference("Tag.count", 3) do
            post = FactoryGirl.create(:post, :tag_string => "aaa bbb ccc")
          end
        end

        should "update the post counts of relevant tag records" do
          post1 = FactoryGirl.create(:post, :tag_string => "aaa bbb ccc")
          post2 = FactoryGirl.create(:post, :tag_string => "bbb ccc ddd")
          post3 = FactoryGirl.create(:post, :tag_string => "ccc ddd eee")
          assert_equal(1, Tag.find_by_name("aaa").post_count)
          assert_equal(2, Tag.find_by_name("bbb").post_count)
          assert_equal(3, Tag.find_by_name("ccc").post_count)
          post3.tag_string = "xxx"
          post3.save
          assert_equal(1, Tag.find_by_name("aaa").post_count)
          assert_equal(2, Tag.find_by_name("bbb").post_count)
          assert_equal(2, Tag.find_by_name("ccc").post_count)
          assert_equal(1, Tag.find_by_name("ddd").post_count)
          assert_equal(0, Tag.find_by_name("eee").post_count)
          assert_equal(1, Tag.find_by_name("xxx").post_count)
        end

        should "update its tag counts" do
          new_post = FactoryGirl.create(:post, :tag_string => "blah1 blah2 blah3")
          assert_equal(3, new_post.tag_count)

          new_post.tag_string = "babs"
          new_post.save
          assert_equal(1, new_post.tag_count)
        end

        should "merge any tag changes that were made after loading the initial set of tags part 1" do
          post = FactoryGirl.create(:post, :tag_string => "aaa bbb ccc")

          # user a adds <ddd>
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_a.tag_string = "aaa bbb ccc ddd"
          post_edited_by_user_a.save

          # user b removes <ccc> adds <eee>
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_b.tag_string = "aaa bbb eee"
          post_edited_by_user_b.save

          # final should be <aaa>, <bbb>, <ddd>, <eee>
          final_post = Post.find(post.id)
          assert_equal(%w(aaa bbb ddd eee), Tag.scan_tags(final_post.tag_string).sort)
        end

        should "merge any tag changes that were made after loading the initial set of tags part 2" do
          # This is the same as part 1, only the order of operations is reversed.
          # The results should be the same.

          post = FactoryGirl.create(:post, :tag_string => "aaa bbb ccc")

          # user a removes <ccc> adds <eee>
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_a.tag_string = "aaa bbb eee"
          post_edited_by_user_a.save

          # user b adds <ddd>
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_b.tag_string = "aaa bbb ccc ddd"
          post_edited_by_user_b.save

          # final should be <aaa>, <bbb>, <ddd>, <eee>
          final_post = Post.find(post.id)
          assert_equal(%w(aaa bbb ddd eee), Tag.scan_tags(final_post.tag_string).sort)
        end

        should "merge any parent, source, and rating changes that were made after loading the initial set" do
          post = FactoryGirl.create(:post, :parent => nil, :source => "", :rating => "e")
          parent_post = FactoryGirl.create(:post)

          # user a changes rating to safe, adds parent
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_parent_id = ""
          post_edited_by_user_a.old_source = ""
          post_edited_by_user_a.old_rating = "e"
          post_edited_by_user_a.parent_id = parent_post.id
          post_edited_by_user_a.source = nil
          post_edited_by_user_a.rating = "s"
          post_edited_by_user_a.save

          # user b adds source
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_parent_id = ""
          post_edited_by_user_b.old_source = ""
          post_edited_by_user_b.old_rating = "e"
          post_edited_by_user_b.parent_id = nil
          post_edited_by_user_b.source = "http://example.com"
          post_edited_by_user_b.rating = "s"
          post_edited_by_user_b.save

          # final post should be rated safe and have the set parent and source
          final_post = Post.find(post.id)
          assert_equal(parent_post.id, final_post.parent_id)
          assert_equal("http://example.com", final_post.source)
          assert_equal("s", final_post.rating)
        end
      end

      context "that has been tagged with a metatag" do
        should "not include the metatag in its tag string" do
          post = FactoryGirl.create(:post)
          post.tag_string = "aaa pool:1234 pool:test rating:s fav:bob"
          post.save
          assert_equal("aaa", post.tag_string)
        end
      end

      context "with a source" do
        context "that is not from pixiv" do
          should "clear the pixiv id" do
            @post.pixiv_id = 1234
            @post.update(source: "http://fc06.deviantart.net/fs71/f/2013/295/d/7/you_are_already_dead__by_mar11co-d6rgm0e.jpg")
            assert_nil(@post.pixiv_id)

            @post.pixiv_id = 1234
            @post.update(source: "http://pictures.hentai-foundry.com//a/AnimeFlux/219123.jpg")
            assert_nil(@post.pixiv_id)
          end
        end

        context "that is from pixiv" do
          should "save the pixiv id" do
            @post.update(source: "https://img18.pixiv.net/img/evazion/14901720.png")
            assert_equal(14901720, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://img18.pixiv.net/img/evazion/14901720.png")
            assert_equal(14901720, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i2.pixiv.net/img18/img/evazion/14901720.png")
            assert_equal(14901720, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i2.pixiv.net/img18/img/evazion/14901720_m.png")
            assert_equal(14901720, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i2.pixiv.net/img18/img/evazion/14901720_s.png")
            assert_equal(14901720, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i1.pixiv.net/img07/img/pasirism/18557054_p1.png")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i1.pixiv.net/img07/img/pasirism/18557054_big_p1.png")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i1.pixiv.net/img-inf/img/2011/05/01/23/28/04/18557054_64x64.jpg")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i1.pixiv.net/img-inf/img/2011/05/01/23/28/04/18557054_s.png")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i1.pixiv.net/c/600x600/img-master/img/2014/10/02/13/51/23/46304396_p0_master1200.jpg")
            assert_equal(46304396, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p0.png")
            assert_equal(46304396, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://i1.pixiv.net/img-zip-ugoira/img/2014/10/03/17/29/16/46323924_ugoira1920x1080.zip")
            assert_equal(46323924, @post.pixiv_id)
            @post.pixiv_id = nil



            @post.update(source: "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=18557054")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=18557054")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://www.pixiv.net/member_illust.php?mode=big&illust_id=18557054")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://www.pixiv.net/member_illust.php?mode=manga&illust_id=18557054")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=18557054")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil

            @post.update(source: "http://www.pixiv.net/i/18557054")
            assert_equal(18557054, @post.pixiv_id)
            @post.pixiv_id = nil
          end

          context "but doesn't have a pixiv id" do
            should "not save the pixiv id" do
              @post.pixiv_id = 1234
              @post.update(source: "http://i1.pixiv.net/novel-cover-original/img/2016/11/03/20/10/58/7436075_f75af69f3eacd1656d3733c72aa959cf.jpg")
              assert_nil(@post.pixiv_id)

              @post.pixiv_id = 1234
              @post.update(source: "http://i2.pixiv.net/background/img/2016/10/30/12/27/30/7059005_da9946b806c10d391a81ed1117cd33d6.jpg")
              assert_nil(@post.pixiv_id)

              @post.pixiv_id = 1234
              @post.update(source: "http://i1.pixiv.net/img15/img/omega777/novel/2612734.jpg")
              assert_nil(@post.pixiv_id)

              @post.pixiv_id = 1234
              @post.update(source: "http://img08.pixiv.net/profile/nice/1408837.jpg")
              assert_nil(@post.pixiv_id)
            end
          end
        end

        should "normalize pixiv links" do
          @post.source = "http://i2.pixiv.net/img12/img/zenze/39749565.png"
          assert_equal("http://www.pixiv.net/member_illust.php?mode=medium&illust_id=39749565", @post.normalized_source)

          @post.source = "http://i1.pixiv.net/img53/img/themare/39735353_big_p1.jpg"
          assert_equal("http://www.pixiv.net/member_illust.php?mode=medium&illust_id=39735353", @post.normalized_source)

          @post.source = "http://i1.pixiv.net/c/150x150/img-master/img/2010/11/30/08/39/58/14901720_p0_master1200.jpg"
          assert_equal("http://www.pixiv.net/member_illust.php?mode=medium&illust_id=14901720", @post.normalized_source)

          @post.source = "http://i1.pixiv.net/img-original/img/2010/11/30/08/39/58/14901720_p0.png"
          assert_equal("http://www.pixiv.net/member_illust.php?mode=medium&illust_id=14901720", @post.normalized_source)

          @post.source = "http://i2.pixiv.net/img-zip-ugoira/img/2014/08/05/06/01/10/44524589_ugoira1920x1080.zip"
          assert_equal("http://www.pixiv.net/member_illust.php?mode=medium&illust_id=44524589", @post.normalized_source)
        end

        should "normalize nicoseiga links" do
          @post.source = "http://lohas.nicoseiga.jp/priv/3521156?e=1382558156&h=f2e089256abd1d453a455ec8f317a6c703e2cedf"
          assert_equal("http://seiga.nicovideo.jp/seiga/im3521156", @post.normalized_source)
          @post.source = "http://lohas.nicoseiga.jp/priv/b80f86c0d8591b217e7513a9e175e94e00f3c7a1/1384936074/3583893"
          assert_equal("http://seiga.nicovideo.jp/seiga/im3583893", @post.normalized_source)
        end

        should "normalize twitpic links" do
          @post.source = "http://d3j5vwomefv46c.cloudfront.net/photos/large/820960031.jpg?1384107199"
          assert_equal("http://twitpic.com/dks0tb", @post.normalized_source)
        end

        should "normalize deviantart links" do
          @post.source = "http://fc06.deviantart.net/fs71/f/2013/295/d/7/you_are_already_dead__by_mar11co-d6rgm0e.jpg"
          assert_equal("http://mar11co.deviantart.com/art/You-Are-Already-Dead-408921710", @post.normalized_source)
          @post.source = "http://fc00.deviantart.net/fs71/f/2013/337/3/5/35081351f62b432f84eaeddeb4693caf-d6wlrqs.jpg"
          assert_equal("http://deviantart.com/deviation/417560500", @post.normalized_source)
        end

        should "normalize karabako links" do
          @post.source = "http://www.karabako.net/images/karabako_38835.jpg"
          assert_equal("http://www.karabako.net/post/view/38835", @post.normalized_source)
        end

        should "normalize twipple links" do
          @post.source = "http://p.twpl.jp/show/orig/mI2c3"
          assert_equal("http://p.twipple.jp/mI2c3", @post.normalized_source)
        end

        should "normalize hentai foundry links" do
          @post.source = "http://pictures.hentai-foundry.com//a/AnimeFlux/219123.jpg"
          assert_equal("http://www.hentai-foundry.com/pictures/user/AnimeFlux/219123", @post.normalized_source)

          @post.source = "http://pictures.hentai-foundry.com/a/AnimeFlux/219123/Mobile-Suit-Equestria-rainbow-run.jpg"
          assert_equal("http://www.hentai-foundry.com/pictures/user/AnimeFlux/219123", @post.normalized_source)
        end
      end
    end
  end

  context "Updating:" do
    context "A rating unlocked post" do
      setup { @post = FactoryGirl.create(:post) }
      subject { @post }

      should_not allow_value("S", "safe", "derp").for(:rating)
      should allow_value("s", "e").for(:rating)
    end

    context "A rating locked post" do
      setup { @post = FactoryGirl.create(:post, :is_rating_locked => true) }
      subject { @post }

      should_not allow_value("S", "safe", "derp").for(:rating)
      should_not allow_value("e").for(:rating)
    end
  end

  context "Favorites:" do
    context "Removing a post from a user's favorites" do
      setup do
        @user = FactoryGirl.create(:member_user)
        @post = FactoryGirl.create(:post)
        @post.add_favorite!(@user)
        @user.reload
      end

      should "decrement the user's favorite_count" do
        assert_difference("@user.favorite_count", -1) do
          @post.remove_favorite!(@user)
        end
      end

      should "decrement the post's score for users" do
        assert_difference("@post.score", -1) do
          @post.remove_favorite!(@user)
        end
      end
    end

    context "Adding a post to a user's favorites" do
      setup do
        @user = FactoryGirl.create(:member_user)
        @post = FactoryGirl.create(:post)
      end

      should "periodically clean the fav_string" do
        @post.update_column(:fav_string, "fav:1 fav:1 fav:1")
        @post.update_column(:fav_count, 3)
        @post.stubs(:clean_fav_string?).returns(true)
        @post.append_user_to_fav_string(2)
        assert_equal("fav:1 fav:2", @post.fav_string)
        assert_equal(2, @post.fav_count)
      end

      should "increment the user's favorite_count" do
        assert_difference("@user.favorite_count", 1) do
          @post.add_favorite!(@user)
        end
      end

      should "increment the post's score for gold users" do
        @post.add_favorite!(@user)
        assert_equal(1, @post.score)
      end

      should "update the fav strings ont he post" do
        @post.add_favorite!(@user)
        @post.reload
        assert_equal("fav:#{@user.id}", @post.fav_string)
        assert(Favorite.exists?(:user_id => @user.id, :post_id => @post.id))

        @post.add_favorite!(@user)
        @post.reload
        assert_equal("fav:#{@user.id}", @post.fav_string)
        assert(Favorite.exists?(:user_id => @user.id, :post_id => @post.id))

        @post.remove_favorite!(@user)
        @post.reload
        assert_equal("", @post.fav_string)
        assert(!Favorite.exists?(:user_id => @user.id, :post_id => @post.id))

        @post.remove_favorite!(@user)
        @post.reload
        assert_equal("", @post.fav_string)
        assert(!Favorite.exists?(:user_id => @user.id, :post_id => @post.id))
      end
    end

    context "Moving favorites to a parent post" do
      setup do
        @parent = FactoryGirl.create(:post)
        @child = FactoryGirl.create(:post, parent: @parent)

        @gold1 = FactoryGirl.create(:gold_user)
        @voter = FactoryGirl.create(:user)

        @child.add_favorite!(@user)
        @child.add_favorite!(@gold1)
        @child.add_favorite!(@voter)
        @parent.add_favorite!(@voter)

        @child.give_favorites_to_parent
        @child.reload
        @parent.reload
      end

      should "move the favorites" do
        assert_equal(0, @child.fav_count)
        assert_equal(0, @child.favorites.count)
        assert_equal("", @child.fav_string)
        assert_equal([], @child.favorites.pluck(:user_id))

        assert_equal(3, @parent.fav_count)
        assert_equal(3, @parent.favorites.count)
      end

      should "create a vote for each user who can vote" do
        assert(@parent.votes.where(user: @gold1).exists?)
        assert(@parent.votes.where(user: @voter).exists?)
        assert_equal(3, @parent.score)
      end
    end
  end

  context "Pools:" do
    setup do
      SqsService.any_instance.stubs(:send_message)
    end

    context "Removing a post from a pool" do
      should "update the post's pool string" do
        post = FactoryGirl.create(:post)
        pool = FactoryGirl.create(:pool)
        post.add_pool!(pool)
        post.remove_pool!(pool)
        post.reload
        assert_equal("", post.pool_string)
        post.remove_pool!(pool)
        post.reload
        assert_equal("", post.pool_string)
      end
    end

    context "Adding a post to a pool" do
      should "update the post's pool string" do
        post = FactoryGirl.create(:post)
        pool = FactoryGirl.create(:pool)
        post.add_pool!(pool)
        post.reload
        assert_equal("pool:#{pool.id} pool:series", post.pool_string)
        post.add_pool!(pool)
        post.reload
        assert_equal("pool:#{pool.id} pool:series", post.pool_string)
        post.remove_pool!(pool)
        post.reload
        assert_equal("", post.pool_string)
      end
    end
  end

  context "Uploading:" do
    context "Uploading a post" do
      should "capture who uploaded the post" do
        post = FactoryGirl.create(:post)
        user1 = FactoryGirl.create(:user)
        user2 = FactoryGirl.create(:user)
        user3 = FactoryGirl.create(:user)

        post.uploader = user1
        assert_equal(user1.id, post.uploader_id)

        post.uploader_id = user2.id
        assert_equal(user2.id, post.uploader_id)
        assert_equal(user2.id, post.uploader_id)
        assert_equal(user2.name, post.uploader_name)
      end
    end
  end

  context "Searching:" do
    setup do
      mock_pool_archive_service!
    end
    
    should "return posts for the age:<1minute tag" do
      post = FactoryGirl.create(:post)
      assert_tag_match([post], "age:<1minute")
    end

    should "return posts for the age:<1minute tag when the user is in Pacific time zone" do
      post = FactoryGirl.create(:post)
      Time.zone = "Pacific Time (US & Canada)"
      assert_tag_match([post], "age:<1minute")
      Time.zone = "Eastern Time (US & Canada)"
    end

    should "return posts for the age:<1minute tag when the user is in Tokyo time zone" do
      post = FactoryGirl.create(:post)
      Time.zone = "Asia/Tokyo"
      assert_tag_match([post], "age:<1minute")
      Time.zone = "Eastern Time (US & Canada)"
    end

    should "return posts for the ' tag" do
      post1 = FactoryGirl.create(:post, :tag_string => "'")
      post2 = FactoryGirl.create(:post, :tag_string => "aaa bbb")

      assert_tag_match([post1], "'")
    end

    should "return posts for the \\ tag" do
      post1 = FactoryGirl.create(:post, :tag_string => "\\")
      post2 = FactoryGirl.create(:post, :tag_string => "aaa bbb")

      assert_tag_match([post1], "\\")
    end

    should "return posts for the ( tag" do
      post1 = FactoryGirl.create(:post, :tag_string => "(")
      post2 = FactoryGirl.create(:post, :tag_string => "aaa bbb")

      assert_tag_match([post1], "(")
    end

    should "return posts for the ? tag" do
      post1 = FactoryGirl.create(:post, :tag_string => "?")
      post2 = FactoryGirl.create(:post, :tag_string => "aaa bbb")

      assert_tag_match([post1], "?")
    end

    should "return posts for 1 tag" do
      post1 = FactoryGirl.create(:post, :tag_string => "aaa")
      post2 = FactoryGirl.create(:post, :tag_string => "aaa bbb")
      post3 = FactoryGirl.create(:post, :tag_string => "bbb ccc")

      assert_tag_match([post2, post1], "aaa")
    end

    should "return posts for a 2 tag join" do
      post1 = FactoryGirl.create(:post, :tag_string => "aaa")
      post2 = FactoryGirl.create(:post, :tag_string => "aaa bbb")
      post3 = FactoryGirl.create(:post, :tag_string => "bbb ccc")

      assert_tag_match([post2], "aaa bbb")
    end

    should "return posts for a 2 tag union" do
      post1 = FactoryGirl.create(:post, :tag_string => "aaa")
      post2 = FactoryGirl.create(:post, :tag_string => "aaab bbb")
      post3 = FactoryGirl.create(:post, :tag_string => "bbb ccc")

      assert_tag_match([post3, post1], "~aaa ~ccc")
    end

    should "return posts for 1 tag with exclusion" do
      post1 = FactoryGirl.create(:post, :tag_string => "aaa")
      post2 = FactoryGirl.create(:post, :tag_string => "aaa bbb")
      post3 = FactoryGirl.create(:post, :tag_string => "bbb ccc")

      assert_tag_match([post1], "aaa -bbb")
    end

    should "return posts for 1 tag with a pattern" do
      post1 = FactoryGirl.create(:post, :tag_string => "aaa")
      post2 = FactoryGirl.create(:post, :tag_string => "aaab bbb")
      post3 = FactoryGirl.create(:post, :tag_string => "bbb ccc")

      assert_tag_match([post2, post1], "a*")
    end

    should "return posts for 2 tags, one with a pattern" do
      post1 = FactoryGirl.create(:post, :tag_string => "aaa")
      post2 = FactoryGirl.create(:post, :tag_string => "aaab bbb")
      post3 = FactoryGirl.create(:post, :tag_string => "bbb ccc")

      assert_tag_match([post2], "a* bbb")
    end

    should "return posts for the id:<N> metatag" do
      posts = FactoryGirl.create_list(:post, 3)

      assert_tag_match([posts[1]], "id:#{posts[1].id}")
      assert_tag_match([posts[2]], "id:>#{posts[1].id}")
      assert_tag_match([posts[0]], "id:<#{posts[1].id}")

      assert_tag_match([posts[2], posts[0]], "-id:#{posts[1].id}")
      assert_tag_match([posts[2], posts[1]], "id:>=#{posts[1].id}")
      assert_tag_match([posts[1], posts[0]], "id:<=#{posts[1].id}")
      assert_tag_match([posts[2], posts[0]], "id:#{posts[0].id},#{posts[2].id}")
      assert_tag_match(posts.reverse, "id:#{posts[0].id}..#{posts[2].id}")
    end

    should "return posts for the fav:<name> metatag" do
      users = FactoryGirl.create_list(:user, 2)
      posts = users.map do |u|
        CurrentUser.scoped(u) { FactoryGirl.create(:post, tag_string: "fav:#{u.name}") }
      end

      assert_tag_match([posts[0]], "fav:#{users[0].name}")
      assert_tag_match([posts[1]], "-fav:#{users[0].name}")
    end

    should "return posts for the ordfav:<name> metatag" do
      post1 = FactoryGirl.create(:post, tag_string: "fav:#{CurrentUser.name}")
      post2 = FactoryGirl.create(:post, tag_string: "fav:#{CurrentUser.name}")

      assert_tag_match([post2, post1], "ordfav:#{CurrentUser.name}")
    end

    should "return posts for the pool:<name> metatag" do
      SqsService.any_instance.stubs(:send_message)

      FactoryGirl.create(:pool, name: "test_a", category: "series")
      FactoryGirl.create(:pool, name: "test_b", category: "collection")
      post1 = FactoryGirl.create(:post, tag_string: "pool:test_a")
      post2 = FactoryGirl.create(:post, tag_string: "pool:test_b")

      assert_tag_match([post1], "pool:test_a")
      assert_tag_match([post2], "-pool:test_a")
      assert_tag_match([], "-pool:test_a -pool:test_b")
      assert_tag_match([post2, post1], "pool:test*")

      assert_tag_match([post2, post1], "pool:any")
      assert_tag_match([], "pool:none")

      assert_tag_match([post1], "pool:series")
      assert_tag_match([post2], "-pool:series")
      assert_tag_match([post2], "pool:collection")
      assert_tag_match([post1], "-pool:collection")
    end

    should "return posts for the ordpool:<name> metatag" do
      posts = FactoryGirl.create_list(:post, 2, tag_string: "newpool:test")

      assert_tag_match(posts, "ordpool:test")
    end

    should "return posts for the parent:<N> metatag" do
      parent = FactoryGirl.create(:post)
      child = FactoryGirl.create(:post, tag_string: "parent:#{parent.id}")

      assert_tag_match([parent], "parent:none")
      assert_tag_match([child], "-parent:none")
      assert_tag_match([child, parent], "parent:#{parent.id}")
      assert_tag_match([child], "parent:#{child.id}")

      assert_tag_match([child], "child:none")
      assert_tag_match([parent], "child:any")
    end

    should "return posts for the user:<name> metatag" do
      users = FactoryGirl.create_list(:user, 2)
      posts = users.map { |u| FactoryGirl.create(:post, uploader: u) }

      assert_tag_match([posts[0]], "user:#{users[0].name}")
      assert_tag_match([posts[1]], "-user:#{users[0].name}")
    end

    should "return posts for the commenter:<name> metatag" do
      users = FactoryGirl.create_list(:user, 2, created_at: 2.weeks.ago)
      posts = FactoryGirl.create_list(:post, 2)
      comms = users.zip(posts).map { |u, p| FactoryGirl.create(:comment, creator: u, post: p) }

      assert_tag_match([posts[0]], "commenter:#{users[0].name}")
      assert_tag_match([posts[1]], "commenter:#{users[1].name}")
    end

    should "return posts for the commenter:<any|none> metatag" do
      posts = FactoryGirl.create_list(:post, 2)
      FactoryGirl.create(:comment, post: posts[0], is_deleted: false)
      FactoryGirl.create(:comment, post: posts[1], is_deleted: true)

      assert_tag_match([posts[0]], "commenter:any")
      assert_tag_match([posts[1]], "commenter:none")
    end

    should "return posts for the noter:<name> metatag" do
      users = FactoryGirl.create_list(:user, 2)
      posts = FactoryGirl.create_list(:post, 2)
      notes = users.zip(posts).map { |u, p| FactoryGirl.create(:note, creator: u, post: p) }

      assert_tag_match([posts[0]], "noter:#{users[0].name}")
      assert_tag_match([posts[1]], "noter:#{users[1].name}")
    end

    should "return posts for the noter:<any|none> metatag" do
      posts = FactoryGirl.create_list(:post, 2)
      FactoryGirl.create(:note, post: posts[0], is_active: true)
      FactoryGirl.create(:note, post: posts[1], is_active: false)

      assert_tag_match([posts[0]], "noter:any")
      assert_tag_match([posts[1]], "noter:none")
    end

    should "return posts for the date:<d> metatag" do
      post = FactoryGirl.create(:post, created_at: Time.parse("2017-01-01"))

      assert_tag_match([post], "date:2017-01-01")
    end

    should "return posts for the age:<n> metatag" do
      post = FactoryGirl.create(:post)

      assert_tag_match([post], "age:<60")
      assert_tag_match([post], "age:<60s")
      assert_tag_match([post], "age:<1mi")
      assert_tag_match([post], "age:<1h")
      assert_tag_match([post], "age:<1d")
      assert_tag_match([post], "age:<1w")
      assert_tag_match([post], "age:<1mo")
      assert_tag_match([post], "age:<1y")
    end

    should "return posts for the ratio:<x:y> metatag" do
      post = FactoryGirl.create(:post, image_width: 1000, image_height: 500)

      assert_tag_match([post], "ratio:2:1")
      assert_tag_match([post], "ratio:2.0")
    end

    should "return posts for the status:<type> metatag" do
      active = FactoryGirl.create(:post)
      deleted = FactoryGirl.create(:post, is_deleted: true)

      assert_tag_match([deleted], "status:deleted")
      assert_tag_match([active], "status:active")
      assert_tag_match([deleted, active], "status:any")
      assert_tag_match([deleted, active], "status:all")

      assert_tag_match([active], "-status:deleted")
      assert_tag_match([deleted], "-status:active")
    end

    should "return posts for the filetype:<ext> metatag" do
      png = FactoryGirl.create(:post, file_ext: "png")
      jpg = FactoryGirl.create(:post, file_ext: "jpg")

      assert_tag_match([png], "filetype:png")
      assert_tag_match([jpg], "-filetype:png")
    end

    should "return posts for the md5:<md5> metatag" do
      post1 = FactoryGirl.create(:post, :md5 => "abcd")
      post2 = FactoryGirl.create(:post)

      assert_tag_match([post1], "md5:abcd")
    end

    should "return posts for a source search" do
      post1 = FactoryGirl.create(:post, :source => "abcd")
      post2 = FactoryGirl.create(:post, :source => "abcdefg")
      post3 = FactoryGirl.create(:post, :source => "")

      assert_tag_match([post2], "source:abcde")
      assert_tag_match([post3, post1], "-source:abcde")

      assert_tag_match([post3], "source:none")
      assert_tag_match([post2, post1], "-source:none")
    end

    should "return posts for a case insensitive source search" do
      post1 = FactoryGirl.create(:post, :source => "ABCD")
      post2 = FactoryGirl.create(:post, :source => "1234")

      assert_tag_match([post1], "source:abcd")
    end

    should "return posts for a pixiv source search" do
      url = "http://i1.pixiv.net/img123/img/artist-name/789.png"
      post = FactoryGirl.create(:post, :source => url)

      assert_tag_match([post], "source:*.pixiv.net/img*/artist-name/*")
      assert_tag_match([],     "source:*.pixiv.net/img*/artist-fake/*")
      assert_tag_match([post], "source:http://*.pixiv.net/img*/img/artist-name/*")
      assert_tag_match([],     "source:http://*.pixiv.net/img*/img/artist-fake/*")
      assert_tag_match([post], "source:pixiv/artist-name/*")
      assert_tag_match([],     "source:pixiv/artist-fake/*")
    end

    should "return posts for a pixiv id search (type 1)" do
      url = "http://i1.pixiv.net/img-inf/img/2013/03/14/03/02/36/34228050_s.jpg"
      post = FactoryGirl.create(:post, :source => url)
      assert_tag_match([post], "pixiv_id:34228050")
    end

    should "return posts for a pixiv id search (type 2)" do
      url = "http://i1.pixiv.net/img123/img/artist-name/789.png"
      post = FactoryGirl.create(:post, :source => url)
      assert_tag_match([post], "pixiv_id:789")
    end
    
    should "return posts for a pixiv id search (type 3)" do
      url = "http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=19113635&page=0"
      post = FactoryGirl.create(:post, :source => url)
      assert_tag_match([post], "pixiv_id:19113635")
    end
    
    should "return posts for a pixiv id search (type 4)" do
      url = "http://i2.pixiv.net/img70/img/disappearedstump/34551381_p3.jpg?1364424318"
      post = FactoryGirl.create(:post, :source => url)
      assert_tag_match([post], "pixiv_id:34551381")
    end
    
    # should "return posts for a pixiv novel id search" do
    #   url = "http://www.pixiv.net/novel/show.php?id=2156088"
    #   post = FactoryGirl.create(:post, :source => url)
    #   assert_equal(1, Post.tag_match("pixiv_novel_id:2156088").count)
    # end

    should "return posts for a search:<category> metatag" do
      post1 = FactoryGirl.create(:post, tag_string: "aaa")
      post2 = FactoryGirl.create(:post, tag_string: "bbb")
      FactoryGirl.create(:saved_search, query: "aaa", user: CurrentUser.user)
      FactoryGirl.create(:saved_search, query: "bbb", user: CurrentUser.user)

      SavedSearch.expects(:post_ids).with(CurrentUser.id).returns([post1.id, post2.id])

      assert_tag_match([post2, post1], "search:all")
    end

    should "return posts for a rating:<s|e> metatag" do
      s = FactoryGirl.create(:post, :rating => "s")
      e = FactoryGirl.create(:post, :rating => "e")
      all = [e,  s]

      assert_tag_match([s], "rating:s")
      assert_tag_match([e], "rating:e")

      assert_tag_match(all - [s], "-rating:s")
      assert_tag_match(all - [e], "-rating:e")
    end

    should "return posts for a locked:<rating|note|status> metatag" do
      rating_locked = FactoryGirl.create(:post, is_rating_locked: true)
      note_locked   = FactoryGirl.create(:post, is_note_locked: true)
      status_locked = FactoryGirl.create(:post, is_status_locked: true)
      all = [status_locked, note_locked, rating_locked]

      assert_tag_match([rating_locked], "locked:rating")
      assert_tag_match([note_locked], "locked:note")
      assert_tag_match([status_locked], "locked:status")

      assert_tag_match(all - [rating_locked], "-locked:rating")
      assert_tag_match(all - [note_locked], "-locked:note")
      assert_tag_match(all - [status_locked], "-locked:status")
    end

    should "return posts for a upvote:<user>, downvote:<user> metatag" do
      CurrentUser.scoped(FactoryGirl.create(:mod_user)) do
        upvoted   = FactoryGirl.create(:post, tag_string: "upvote:self")
        downvoted = FactoryGirl.create(:post, tag_string: "downvote:self")

        assert_tag_match([upvoted],   "upvote:#{CurrentUser.name}")
        assert_tag_match([downvoted], "downvote:#{CurrentUser.name}")
      end
    end

    should "return posts ordered by a particular attribute" do
      posts = (1..2).map do |n|
        p = FactoryGirl.create(
          :post,
          score: n,
          fav_count: n,
          file_size: 1.megabyte * n,
          image_height: 100*n*n,
          image_width: 100*(3-n)*n,
        )

        FactoryGirl.create(:comment, post: p)
        FactoryGirl.create(:note, post: p)
        p
      end

      assert_tag_match(posts.reverse, "order:id_desc")
      assert_tag_match(posts.reverse, "order:score")
      assert_tag_match(posts.reverse, "order:favcount")
      assert_tag_match(posts.reverse, "order:change")
      assert_tag_match(posts.reverse, "order:comment")
      assert_tag_match(posts.reverse, "order:note")
      assert_tag_match(posts.reverse, "order:filesize")
      assert_tag_match(posts.reverse, "order:rank")

      assert_tag_match(posts, "order:id_asc")
      assert_tag_match(posts, "order:score_asc")
      assert_tag_match(posts, "order:favcount_asc")
      assert_tag_match(posts, "order:change_asc")
      assert_tag_match(posts, "order:comment_asc")
      assert_tag_match(posts, "order:note_asc")
      assert_tag_match(posts, "order:filesize_asc")
    end

    should "return posts for a filesize search" do
      post = FactoryGirl.create(:post, :file_size => 1.megabyte)

      assert_tag_match([post], "filesize:1mb")
      assert_tag_match([post], "filesize:1000kb")
      assert_tag_match([post], "filesize:1048576b")
    end

    should "not perform fuzzy matching for an exact filesize search" do
      post = FactoryGirl.create(:post, :file_size => 1.megabyte)

      assert_tag_match([], "filesize:1048000b")
      assert_tag_match([], "filesize:1048000")
    end

    should "fail for more than 6 tags" do
      post1 = FactoryGirl.create(:post, :rating => "s")

      assert_raise(::Post::SearchError) do
        Post.tag_match("a b c rating:s width:10 height:10 user:bob")
      end
    end

    should "succeed for exclusive tag searches with no other tag" do
      post1 = FactoryGirl.create(:post, :rating => "s", :tag_string => "aaa")
      assert_nothing_raised do
        relation = Post.tag_match("-aaa")
      end
    end

    should "succeed for exclusive tag searches combined with a metatag" do
      post1 = FactoryGirl.create(:post, :rating => "s", :tag_string => "aaa")
      assert_nothing_raised do
        relation = Post.tag_match("-aaa id:>0")
      end
    end
  end

  context "Voting:" do
    should "not allow duplicate votes" do
      user = FactoryGirl.create(:gold_user)
      post = FactoryGirl.create(:post)
      CurrentUser.scoped(user, "127.0.0.1") do
        assert_nothing_raised {post.vote!("up")}
        assert_raises(PostVote::Error) {post.vote!("up")}
        post.reload
        assert_equal(1, PostVote.count)
        assert_equal(1, post.score)
      end
    end

    should "allow undoing of votes" do
      user = FactoryGirl.create(:gold_user)
      post = FactoryGirl.create(:post)

      # We deliberately don't call post.reload until the end to verify that
      # post.unvote! returns the correct score even when not forcibly reloaded.
      CurrentUser.scoped(user, "127.0.0.1") do
        post.vote!("up")
        assert_equal(1, post.score)

        post.unvote!
        assert_equal(0, post.score)

        assert_nothing_raised {post.vote!("down")}
        assert_equal(-1, post.score)

        post.unvote!
        assert_equal(0, post.score)

        assert_nothing_raised {post.vote!("up")}
        assert_equal(1, post.score)

        post.reload
        assert_equal(1, post.score)
      end
    end
  end

  context "Counting:" do
    context "Creating a post" do
      setup do
        Danbooru.config.stubs(:blank_tag_search_fast_count).returns(nil)
        Danbooru.config.stubs(:estimate_post_counts).returns(false)
      end

      context "with a primed cache" do
        setup do
          Cache.put("pfc:aaa", 0)
          Cache.put("pfc:width:50", 0)
          Danbooru.config.stubs(:blank_tag_search_fast_count).returns(1_000_000)
          FactoryGirl.create(:post, :tag_string => "aaa")
        end

        should "be counted correctly in fast_count" do
          assert_equal(1, Post.count)
          assert_equal(1, Post.fast_count(""))
          assert_equal(1, Post.fast_count("aaa"))
        end
      end

      should "increment the post count" do
        assert_equal(0, Post.fast_count(""))
        post = FactoryGirl.create(:post, :tag_string => "aaa bbb")
        assert_equal(1, Post.fast_count(""))
        assert_equal(1, Post.fast_count("aaa"))
        assert_equal(1, Post.fast_count("bbb"))
        assert_equal(0, Post.fast_count("ccc"))

        post.tag_string = "ccc"
        post.save

        assert_equal(1, Post.fast_count(""))
        assert_equal(0, Post.fast_count("aaa"))
        assert_equal(0, Post.fast_count("bbb"))
        assert_equal(1, Post.fast_count("ccc"))
      end
    end

    context "The cache" do
      context "when shared between users with the deleted post filter on/off" do
        setup do
          FactoryGirl.create(:post, :tag_string => "aaa bbb", :is_deleted => true)
          FactoryGirl.create(:post, :tag_string => "aaa bbb", :is_deleted => false)
          FactoryGirl.create(:post, :tag_string => "aaa bbb", :is_deleted => false)
          CurrentUser.user.stubs(:hide_deleted_posts?).returns(true)
          Post.fast_count("aaa")
          CurrentUser.user.stubs(:hide_deleted_posts?).returns(false)
          Post.fast_count("bbb")
        end

        should "be accurate with the deleted post filter on" do
          CurrentUser.user.stubs(:hide_deleted_posts?).returns(true)
          assert_equal(2, Post.fast_count("aaa"))
          assert_equal(2, Post.fast_count("bbb"))
        end

        should "be accurate with the deleted post filter off" do
          CurrentUser.user.stubs(:hide_deleted_posts?).returns(false)
          assert_equal(3, Post.fast_count("aaa"))
          assert_equal(3, Post.fast_count("bbb"))
        end
      end
    end
  end

  context "Reverting: " do
    context "a post that is rating locked" do
      setup do
        @post = FactoryGirl.create(:post, :rating => "s")
        Timecop.travel(2.hours.from_now) do
          @post.update({ :rating => "e", :is_rating_locked => true }, :as => :moderator)
        end
      end

      should "not revert the rating" do
        assert_raises ActiveRecord::RecordInvalid do
          @post.revert_to!(@post.versions.first)
        end

        assert_equal(["Rating is locked and cannot be changed. Unlock the post first."], @post.errors.full_messages)
        assert_equal(@post.versions.last.rating, @post.reload.rating)
      end

      should "revert the rating after unlocking" do
        @post.update({ :rating => "e", :is_rating_locked => false }, :as => :moderator)
        assert_nothing_raised do
          @post.revert_to!(@post.versions.first)
        end

        assert(@post.valid?)
        assert_equal(@post.versions.first.rating, @post.rating)
      end
    end

    context "a post that has been updated" do
      setup do
        PostArchive.sqs_service.stubs(:merge?).returns(false)
        @post = FactoryGirl.create(:post, :rating => "e", :tag_string => "aaa", :source => "")
        @post.update_attributes(:tag_string => "aaa bbb ccc ddd")
        @post.update_attributes(:tag_string => "bbb xxx yyy", :source => "xyz")
        @post.update_attributes(:tag_string => "bbb mmm yyy", :source => "abc")
      end

      context "and then reverted to an early version" do
        setup do
          @post.revert_to(@post.versions[1])
        end

        should "correctly revert all fields" do
          assert_equal("aaa bbb ccc ddd", @post.tag_string)
          assert_equal("", @post.source)
          assert_equal("e", @post.rating)
        end
      end

      context "and then reverted to a later version" do
        setup do
          @post.revert_to(@post.versions[-2])
        end

        should "correctly revert all fields" do
          assert_equal("bbb xxx yyy", @post.tag_string)
          assert_equal("xyz", @post.source)
          assert_equal("e", @post.rating)
        end
      end
    end
  end

  context "Mass assignment: " do
    should_not allow_mass_assignment_of(:last_noted_at).as(:member)
  end
end

