class BooruInitializer
  attr_reader :booru

  def initialize(booru)
    @booru = booru
  end

  # copies a default set of wiki pages from main
  def copy_wiki_pages
    Booru.main.wiki_pages.where(title: ["help:notes", "help:post_relationships", "help:comments", "help:dtext", "help:forum", "help:home", "help:pools", "help:blacklists", "help:tags", "help:cheatsheet", "help:users", "help:translated_tags"]).find_each do |wp|
      wpc = wp.clone
      wpc.booru_id = booru.id
      wpc.save
    end
  end
end
