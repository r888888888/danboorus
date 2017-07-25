module PostSets
  class Artist < PostSets::Post
    attr_reader :artist

    def initialize(artist)
      super(artist.name)
      @artist = artist
    end

    def posts
      @posts ||= begin
        query = ::Post.tag_match(@artist.name).where("true").limit(10)
        query.to_a
        query
      end
    rescue ::Post::SearchError
      ::Post.where("false")
    end

    def presenter
      ::PostSetPresenters::Post.new(self)
    end
  end
end
