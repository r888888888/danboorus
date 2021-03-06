module PostsHelper
  def missed_post_search_count_js
    return nil unless Danbooru.config.enable_post_search_counts
    
    if params[:ms] == "1" && @post_set.post_count == 0 && @post_set.is_single_tag?
      session_id = session.id
      digest = OpenSSL::Digest.new("sha256")
      sig = OpenSSL::HMAC.hexdigest(digest, Danbooru.config.reportbooru_key, ",#{session_id}")
      return render("posts/partials/index/missed_search_count", session_id: session_id, sig: sig)
    end
  end

  def post_search_count_js
    return nil unless Danbooru.config.enable_post_search_counts
    
    if action_name == "index" && params[:page].nil?
      tags = Tag.scan_query(params[:tags]).sort.join(" ")

      if tags.present?
        key = "ps-#{tags}"
        value = session.id
        digest = OpenSSL::Digest.new("sha256")
        sig = OpenSSL::HMAC.hexdigest(digest, Danbooru.config.reportbooru_key, "#{key},#{value}")
        return render("posts/partials/index/search_count", key: key, value: value, sig: sig)
      end
    end

    return nil
  end

  def post_source_tag(post)
    if post.source =~ %r!\Ahttp://img\d+\.pixiv\.net/img/([^\/]+)/!i
      text = "pixiv/<wbr>#{wordbreakify($1)}".html_safe
      source_search = "source:pixiv/#{$1}/"
    elsif post.source =~ %r!\Ahttp://i\d\.pixiv\.net/img\d+/img/([^\/]+)/!i
      text = "pixiv/<wbr>#{wordbreakify($1)}".html_safe
      source_search = "source:pixiv/#{$1}/"
    elsif post.source =~ %r{\Ahttps?://}i
      text = post.normalized_source.sub(/\Ahttps?:\/\/(?:www\.)?/i, "")
      text = truncate(text, length: 20)
      source_search = "source:#{post.source.sub(/[^\/]*$/, "")}"
    end

    # Only allow http:// and https:// links. Disallow javascript: links.
    if post.normalized_source =~ %r!\Ahttps?://!i
      source_link = link_to(text, post.normalized_source)
    else
      source_link = truncate(post.source, :length => 100)
    end

    if CurrentUser.is_basic? && !source_search.blank?
      source_link + "&nbsp;".html_safe + link_to("&raquo;".html_safe, booru_posts_path(Booru.current.slug, :tags => source_search), :rel => "nofollow")
    else
      source_link
    end
  end

  def has_parent_message(post, parent_post_set)
    html = ""

    html << "This post belongs to a "
    html << link_to("parent", booru_posts_path(Booru.current.slug, :tags => "parent:#{post.parent_id}"))
    html << " (deleted)" if parent_post_set.parent.first.is_deleted?

    sibling_count = parent_post_set.children.count - 1
    if sibling_count > 0
      html << " and has "
      text = sibling_count == 1 ? "a sibling" : "#{sibling_count} siblings"
      html << link_to(text, booru_posts_path(Booru.current.slug, :tags => "parent:#{post.parent_id}"))
    end

    html << " (#{link_to("learn more", booru_wiki_pages_path(Booru.current.slug, :title => "help:post_relationships"))}) "

    html << link_to("&laquo; hide".html_safe, "#", :id => "has-parent-relationship-preview-link")

    html.html_safe
  end

  def has_children_message(post, children_post_set)
    html = ""

    html << "This post has "
    text = children_post_set.children.count == 1 ? "a child" : "#{children_post_set.children.count} children"
    html << link_to(text, booru_posts_path(Booru.current.slug, :tags => "parent:#{post.id}"))

    html << " (#{link_to("learn more", booru_wiki_pages_path(Booru.current.slug, :title => "help:post_relationships"))}) "

    html << link_to("&laquo; hide".html_safe, "#", :id => "has-children-relationship-preview-link")

    html.html_safe
  end
end
