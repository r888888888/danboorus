module Danbooru
  class CustomConfiguration < Configuration
    # Define your custom overloads here
    def memcached_servers
      "localhost:11212"
    end

  end
end
