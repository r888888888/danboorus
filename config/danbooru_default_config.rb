require 'socket'

module Danbooru
  class Configuration
    # The name of this Danbooru.
    def app_name
      "Danboorus"
    end

    def description
      "Build your own Booru"
    end

    # The canonical hostname of the site.
    def hostname
      Socket.gethostname
    end

    # The list of all domain names this site is accessible under.
    # Example: %w[danbooru.donmai.us sonohara.donmai.us hijiribe.donmai.us safebooru.donmai.us]
    def hostnames
      [hostname]
    end

    # Contact email address of the admin.
    def contact_email
      "webmaster@#{server_host}"
    end

    # System actions, such as sending automated dmails, will be performed with this account.
    def system_user
      User.find_by_name("DanbooruBot") || User.admins.first
    end

    def upload_feedback_topic
      ForumTopic.where(title: "Upload Feedback Thread").first
    end

    def upgrade_account_email
      contact_email
    end

    def source_code_url
      "https://github.com/r888888888/danbooru"
    end

    def commit_url(hash)
      "#{source_code_url}/commit/#{hash}"
    end

    def releases_url
      "#{source_code_url}/releases"
    end

    def issues_url
      "#{source_code_url}/issues"
    end

    # Stripped of any special characters.
    def safe_app_name
      app_name.gsub(/[^a-zA-Z0-9_-]/, "_")
    end

    # The default name to use for anyone who isn't logged in.
    def default_guest_name
      "Anonymous"
    end

    # This is a salt used to make dictionary attacks on account passwords harder.
    def password_salt(user)
      CityHash.hash64(user.id).to_s(36)
    end

    # Set the default level, permissions, and other settings for new users here.
    def customize_new_user(user)
      # user.level = User::Levels::MEMBER
      #
      # user.comment_threshold = -1
      # user.blacklisted_tags = ["spoilers", "guro", "scat", "furry -rating:s"].join("\n")
      # user.default_image_size = "large"
      # user.per_page = 20
      true
    end

    # What method to use to backup images.
    #
    # NullBackupService: Don't backup images at all.
    #
    # S3BackupService: Backup to Amazon S3. Must configure aws_access_key_id,
    # aws_secret_access_key, and aws_s3_bucket_name. Bucket must exist and be writable.
    def backup_service
      if Rails.env.production?
        S3BackupService.new
      else
        NullBackupService.new
      end
    end

    # Thumbnail size
    def small_image_width
      150
    end

    # Large resize image width. Set to nil to disable.
    def large_image_width
      850
    end

    # When calculating statistics based on the posts table, gather this many posts to sample from.
    def post_sample_size
      300
    end

    # List of memcached servers
    def memcached_servers
      %w(127.0.0.1:11211)
    end

    # Users cannot search for more than X regular tags at a time.
    def base_tag_query_limit
      6
    end

    def tag_query_limit
      if CurrentUser.user.present?
        CurrentUser.user.tag_query_limit
      else
        base_tag_query_limit * 2
      end
    end

    # After this many pages, the paginator will switch to sequential mode.
    def max_numbered_pages
      1_000
    end

    # The name of the server the app is hosted on.
    def server_host
      Socket.gethostname
    end

    # Names of all Danbooru servers which serve out of the same common database.
    # Used in conjunction with load balancing to distribute files from one server to
    # the others. This should match whatever gethostname returns on the other servers.
    def all_server_hosts
      [server_host]
    end

    # Names of other Danbooru servers.
    def other_server_hosts
      @other_server_hosts ||= all_server_hosts.reject {|x| x == server_host}
    end

    def remote_server_login
      "albert"
    end

    # If enabled, users must verify their email addresses.
    def enable_email_verification?
      false
    end

    # Any custom code you want to insert into the default layout without
    # having to modify the templates.
    def custom_html_header_content
      nil
    end

    def upload_notice_wiki_page
      "help:upload_notice"
    end

    # The number of posts displayed per page.
    def posts_per_page
      20
    end

    def is_post_restricted?(post)
      false
    end

    def is_user_restricted?(user)
      !user.is_gold?
    end

    def can_user_see_post?(user, post)
     if is_user_restricted?(user) && is_post_restricted?(post)
        false
      else
        true
      end
    end

    def select_posts_visible_to_user(user, posts)
      posts.select {|x| can_user_see_post?(user, x)}
    end

    # Counting every post is typically expensive because it involves a sequential scan on
    # potentially millions of rows. If this method returns a value, then blank searches
    # will return that number for the fast_count call instead.
    def blank_tag_search_fast_count
      nil
    end

    def pixiv_login
      nil
    end

    def pixiv_password
      nil
    end

    def tinami_login
      nil
    end

    def tinami_password
      nil
    end

    def nico_seiga_login
      nil
    end

    def nico_seiga_password
      nil
    end

    def pixa_login
      nil
    end

    def pixa_password
      nil
    end

    def nijie_login
      nil
    end

    def nijie_password
      nil
    end

    def deviantart_login
      nil
    end

    def deviantart_password
      nil
    end

    # http://tinysubversions.com/notes/mastodon-bot/
    def pawoo_client_id
      nil
    end

    def pawoo_client_secret
      nil
    end

    # 1. Register app at https://www.tumblr.com/oauth/register.
    # 2. Copy "OAuth Consumer Key" from https://www.tumblr.com/oauth/apps.
    def tumblr_consumer_key
      nil
    end

    def enable_dimension_autotagging
      true
    end

    def shared_dir_path
      "/var/www/danbooru2/shared"
    end

    def stripe_secret_key
    end
    
    def stripe_publishable_key
    end

    def twitter_api_key
    end

    def twitter_api_secret
    end

    def enable_post_search_counts
      false
    end

    # The default headers to be sent with outgoing http requests. Some external
    # services will fail if you don't set a valid User-Agent.
    def http_headers
      {
        "User-Agent" => "#{Danbooru.config.safe_app_name}",
      }
    end

    def httparty_options
      # proxy example:
      # {http_proxyaddr: "", http_proxyport: "", http_proxyuser: nil, http_proxypass: nil}
      {
        headers: Danbooru.config.http_headers,
      }
    end

    # you should override this
    def email_key
      "zDMSATq0W3hmA5p3rKTgD"
    end

    # For downloads, if the host matches any of these IPs, block it
    def banned_ip_for_download?(ip_addr)
      raise ArgumentError unless ip_addr.is_a?(IPAddr)

      if ip_addr.ipv4?
        if IPAddr.new("127.0.0.1") == ip_addr
          true
        elsif IPAddr.new("169.254.0.0/16").include?(ip_addr)
          true
        elsif IPAddr.new("10.0.0.0/8").include?(ip_addr)
          true
        elsif IPAddr.new("172.16.0.0/12").include?(ip_addr)
          true
        elsif IPAddr.new("192.168.0.0/16").include?(ip_addr)
          true
        else
          false
        end
      elsif ip_addr.ipv6?
        if IPAddr.new("::1") == ip_addr
          true
        elsif IPAddr.new("fe80::/10").include?(ip_addr)
          true
        elsif IPAddr.new("fd00::/8").include?(ip_addr)
          true
        else
          false
        end
      else
        false
      end
    end

    def twitter_site
    end

    def addthis_key
    end

    # include essential tags in image urls (requires nginx/apache rewrites)
    def enable_seo_post_urls
      false
    end

    # reportbooru options - see https://github.com/r888888888/reportbooru
    def reportbooru_server
    end

    def reportbooru_key
    end

    # listbooru options - see https://github.com/r888888888/listbooru
    def listbooru_server
    end

    def listbooru_auth_key
    end

    # google api options
    def google_api_project
    end

    def google_api_json_key_path
      "/var/www/danbooru2/shared/config/google-key.json"
    end

    # AWS config options
    def aws_access_key_id
    end

    def aws_secret_access_key
    end

    def aws_ses_enabled?
      false
    end

    def aws_ses_options
      # {:smtp_server_name => "smtp server", :user_name => "user name", :ses_smtp_user_name => "smtp user name", :ses_smtp_password => "smtp password"}
    end

    def aws_s3_enabled?
      false
    end

    # Used for backing up images to S3. Must be changed to your own S3 bucket.
    def aws_s3_bucket_name
      "danbooru"
    end

    def aws_sqs_enabled?
      false
    end

    def aws_sqs_saved_search_url
    end

    def aws_sqs_reltagcalc_url
    end

    def aws_sqs_post_versions_url
    end

    def aws_sqs_region
    end

    def aws_sqs_archives_url
    end
  end

  class EnvironmentConfiguration
    def custom_configuration
      @custom_configuration ||= CustomConfiguration.new
    end

    def method_missing(method, *args)
      var = ENV["DANBOORU_#{method.to_s.upcase}"]

      if var.present?
        var
      else
        custom_configuration.send(method, *args)
      end
    end
  end
end
