module TagsHelper
  def alias_and_implication_list(tag)
    return "" if tag.nil?

    html = ""

    automatic_tags = TagImplication.automatic_tags_for([tag.name])
    if automatic_tags.any?
      html << "<p class='hint'>This tag automatically adds "
      html << raw(automatic_tags.map {|x| link_to(x, show_or_new_wiki_pages_path(:title => x))}.join(", "))
      html << " (#{link_to "learn more", wiki_pages_path(title: "help:autotags")}).</p>"
    end

    if tag.antecedent_implications.any?
      html << "<p class='hint'>This tag implicates "
      html << raw(tag.antecedent_implications.map {|x| link_to(x.consequent_name, show_or_new_wiki_pages_path(:title => x.consequent_name))}.join(", "))
      html << " (#{link_to "learn more", wiki_pages_path(title: "help:tag_implications")}).</p>"
    end

    if tag.consequent_implications.any?
      html << "<p class='hint'>The following tags implicate this tag: "
      html << raw(tag.consequent_implications.map {|x| link_to(x.antecedent_name, show_or_new_wiki_pages_path(:title => x.antecedent_name))}.join(", "))
      html << " (#{link_to "learn more", wiki_pages_path(title: "help:tag_implications")}).</p>"
    end

    html.html_safe
  end
  
  def tag_post_count_style(tag)
    @highest_post_count ||= Tag.highest_post_count
    width_percent = Math.log([tag.post_count, 1].max, @highest_post_count) * 100
    "background: linear-gradient(to left, #DDD #{width_percent}%, white #{width_percent}%)"
  end
end
