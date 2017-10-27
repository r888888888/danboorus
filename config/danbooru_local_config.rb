module Danbooru
  class CustomConfiguration < Configuration
    # Define your custom overloads here
    def memcached_servers
      "localhost:11212"
    end

    def backup_service
      S3BackupService.new
    end
  end
end
