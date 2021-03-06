require 'dtext'

module ApplicationHelper
  def wordbreakify(string)
    lines = string.scan(/.{1,10}/)
    wordbreaked_string = lines.map{|str| h(str)}.join("<wbr>")
    raw(wordbreaked_string)
  end

  def nav_link_to(text, url, options = nil)
    if nav_link_match(params[:controller], url)
      klass = "current"
    else
      klass = nil
    end

    content_tag("li", link_to(text, url, options), :class => klass)
  end

  def fast_link_to(text, link_params, options = {})
    if options
      attributes = options.map do |k, v|
        %{#{k}="#{h(v)}"}
      end.join(" ")
    else
      attributes = ""
    end

    if link_params.is_a?(Hash)
      action = link_params.delete(:action)
      controller = link_params.delete(:controller) || controller_name
      id = link_params.delete(:id)

      link_params = link_params.map {|k, v| "#{k}=#{u(v)}"}.join("&")

      if link_params.present?
        link_params = "?#{link_params}"
      end

      if id
        url = "/#{controller}/#{action}/#{id}#{link_params}"
      else
        url = "/#{controller}/#{action}#{link_params}"
      end
    else
      url = link_params
    end

    raw %{<a href="#{h(url)}" #{attributes}>#{text}</a>}
  end

  def format_text(text, **options)
    raw DTextRagel.parse(text, **options)
  end

  def strip_dtext(text)
    raw(DTextRagel.parse_strip(text))
  end

  def error_messages_for(instance_name)
    instance = instance_variable_get("@#{instance_name}")

    if instance && instance.errors.any?
      %{<div class="error-messages ui-state-error ui-corner-all"><strong>Error</strong>: #{instance.__send__(:errors).full_messages.join(", ")}</div>}.html_safe
    else
      ""
    end
  end

  def time_tag(content, time)
    datetime = time.strftime("%Y-%m-%dT%H:%M%:z")

    content_tag(:time, content || datetime, :datetime => datetime, :title => time.to_formatted_s)
  end

  def humanized_duration(from, to)
    duration = distance_of_time_in_words(from, to)
    datetime = from.iso8601 + "/" + to.iso8601
    title = "#{from.strftime("%Y-%m-%d %H:%M")} to #{to.strftime("%Y-%m-%d %H:%M")}"

    raw content_tag(:time, duration, datetime: datetime, title: title)
  end

  def time_ago_in_words_tagged(time)
    if time.past?
      raw time_tag(time_ago_in_words(time) + " ago", time)
    else
      raw time_tag("in " + distance_of_time_in_words(Time.now, time), time)
    end
  end

  def compact_time(time)
    time_tag(time.strftime("%Y-%m-%d %H:%M"), time)
  end

  def external_link_to(url)
    if url =~ %r!\Ahttps?://!i
      link_to url, url, {rel: :nofollow}
    else
      url
    end
  end

  def link_to_ip(ip)
    link_to ip, booru_moderator_ip_addrs_path(Booru.current.slug, :search => {:ip_addr => ip})
  end

  def link_to_user(user, options = {})
    user_class = user.level_class
    user_class = user_class + " user-banned" if user.is_banned?
    user_class = user_class + " with-style"
    if options[:raw_name]
      name = user.name
    else
      name = user.pretty_name
    end
    link_to(name, user_path(user), :class => user_class)
  end

  def mod_link_to_user(user)
    html = ""
    html << link_to_user(user)
    html << " [" + link_to("+", new_user_feedback_path(:user_feedback => {:user_id => user.id})) + "]"
    html.html_safe
  end

  def dtext_field(object, name, options = {})
    options[:name] ||= name.capitalize
    options[:input_id] ||= "#{object}_#{name}"
    options[:input_name] ||= "#{object}[#{name}]"
    options[:value] ||= instance_variable_get("@#{object}").try(name)
    options[:preview_id] ||= "dtext-preview"
    options[:classes] ||= ""
    options[:type] ||= "text"

    render "dtext/form", options
  end

  def dtext_preview_button(object, name, options = {})
    options[:input_id] ||= "#{object}_#{name}"
    options[:preview_id] ||= "dtext-preview"
    submit_tag("Preview", "data-input-id" => options[:input_id], "data-preview-id" => options[:preview_id])
  end

  def search_field(method, options = {})
    name = options[:label] || method.titleize
    string = '<div class="input"><label for="search_' + method + '">' + name + '</label><input type="text" name="search[' + method + ']" id="search_'  + method + '">'
    if options[:hint]
      string += '<p class="hint">' + options[:hint] + '</p>'
    end
    string += '</div>'
    string.html_safe
  end

  def body_attributes(user = CurrentUser.user)
    attributes = [:id, :name, :level, :level_string]
    attributes += User::Roles.map { |role| :"is_#{role}?" }
    attributes.map do |attr|
      name = attr.to_s.dasherize.delete("?")
      value = user.send(attr)

      %{data-user-#{name}="#{h(value)}"}
    end.join(" ").html_safe
  end
  
protected
  def nav_link_match(controller, url)
    url =~ case controller
    when "sessions", "users", "maintenance/user/login_reminders", "maintenance/user/password_resets", "admin/users"
      /^\/(session|users)/

    when "forum_posts"
      /^\/forum_topics/

    when "comments"
      /^\/comments/

    when "notes", "note_versions"
      /^\/notes/

    when "posts", "uploads", "post_versions", "explore/posts", "moderator/post/dashboards", "favorites"
      /^\/post/

    when "tags", "meta_searches"
      /^\/tags/

    when "pools", "pool_versions"
      /^\/pools/

    when "moderator/dashboards"
      /^\/moderator/

    when "wiki_pages", "wiki_page_versions"
      /^\/wiki_pages/

    when "forum_topics", "forum_posts"
      /^\/forum_topics/

    else
      /^\/static/
    end
  end
end
