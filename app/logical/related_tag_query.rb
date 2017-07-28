class RelatedTagQuery
  attr_reader :query

  def initialize(query)
    @query = query.strip
  end

  def tags
    if query =~ /\*/
      pattern_matching_tags
    elsif query.present?
      related_tags
    else
      []
    end
  end

  def wiki_page_tags
    results = wiki_page.try(:tags) || []
    results.reject! do |name|
      name =~ /^(?:list_of_|tag_group|pool_group|howto:|about:|help:|template:)/
    end
    results
  end

  def tags_for_html
    tags
  end

  def to_json
    {:query => query, :tags => tags, :wiki_page_tags => wiki_page_tags}.to_json
  end

protected

  def pattern_matching_tags
    Tag.name_matches(query).where("post_count > 0").order("post_count desc").limit(50).sort_by {|x| x.name}.map(&:name)
  end

  def related_tags
    tag = Tag.named(query.strip).first

    if tag
      tag.related_tag_array.map(&:first)
    else
      []
    end
  end

  def wiki_page
    WikiPage.titled(query).first
  end
end
