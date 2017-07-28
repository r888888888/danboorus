(function() {
  Danbooru.RelatedTag = {};

  Danbooru.RelatedTag.initialize_all = function() {
    if ($("#c-posts").length || $("#c-uploads").length) {
      this.initialize_buttons();
      $("#related-tags-container").hide();
      $("#upload_tag_string,#post_tag_string").keyup(Danbooru.RelatedTag.update_selected);
    }
  }

  Danbooru.RelatedTag.initialize_buttons = function() {
    this.common_bind("#related-tags-button", "");
    this.common_bind("#related-general-button", "general");
    this.common_bind("#related-artists-button", "artist");
    this.common_bind("#related-characters-button", "character");
    this.common_bind("#related-copyrights-button", "copyright");
  }

  Danbooru.RelatedTag.tags_include = function(name) {
    var current = $("#upload_tag_string,#post_tag_string").val().toLowerCase().match(/\S+/g) || [];
    if ($.inArray(name.toLowerCase(), current) > -1) {
      return true;
    } else {
      return false;
    }
  }

  Danbooru.RelatedTag.common_bind = function(button_name, category) {
    $(button_name).click(function(e) {
      var $dest = $("#related-tags");
      $dest.empty();
      Danbooru.RelatedTag.build_recent_and_frequent($dest);
      $dest.append("<em>Loading...</em>");
      $("#related-tags-container").show();
      $.get("/related_tag.json", {
        "query": Danbooru.RelatedTag.current_tag(),
        "category": category
      }).success(Danbooru.RelatedTag.process_response);
      e.preventDefault();
    });
  }

  Danbooru.RelatedTag.current_tag = function() {
    // 1. abc def |  -> def
    // 2. abc def|   -> def
    // 3. abc de|f   -> def
    // 4. abc |def   -> def
    // 5. abc| def   -> abc
    // 6. ab|c def   -> abc
    // 7. |abc def   -> abc
    // 8. | abc def  -> abc

    var $field = $("#upload_tag_string,#post_tag_string");
    var string = $field.val();
    var n = string.length;
    var a = $field.get(0).selectionStart;
    var b = $field.get(0).selectionStart;

    if ((a > 0) && (a < (n - 1)) && (!/\s/.test(string[a])) && (/\s/.test(string[a - 1]))) {
      // 4 is the only case where we need to scan forward. in all other cases we
      // can drag a backwards, and then drag b forwards.

      while ((b < n) && (!/\s/.test(string[b]))) {
        b++;
      }
    } else if (string.search(/\S/) > b) { // case 8
      b = string.search(/\S/);
      while ((b < n) && (!/\s/.test(string[b]))) {
        b++;
      }
    } else {
      while ((a > 0) && ((/\s/.test(string[a])) || (string[a] === undefined))) {
        a--;
        b--;
      }

      while ((a > 0) && (!/\s/.test(string[a - 1]))) {
        a--;
        b--;
      }

      while ((b < (n - 1)) && (!/\s/.test(string[b]))) {
        b++;
      }
    }

    b++;
		return string.slice(a, b);
  }

  Danbooru.RelatedTag.process_response = function(data) {
    Danbooru.RelatedTag.recent_search = data;
    Danbooru.RelatedTag.build_all();
  }

  Danbooru.RelatedTag.update_selected = function(e) {
    var current_tags = $("#upload_tag_string,#post_tag_string").val().toLowerCase().match(/\S+/g) || [];
    var $all_tags = $("#related-tags a");
    $all_tags.removeClass("selected");

    $all_tags.each(function(i, tag) {
      if (current_tags.indexOf(tag.textContent.replace(/ /g, "_")) > -1) {
        $(tag).addClass("selected");
      }
    });
  }

  Danbooru.RelatedTag.build_all = function() {
    if (Danbooru.RelatedTag.recent_search === null || Danbooru.RelatedTag.recent_search === undefined) {
      return;
    }

    Danbooru.RelatedTag.show();

    var query = Danbooru.RelatedTag.recent_search.query;
    var related_tags = Danbooru.RelatedTag.recent_search.tags;
    var wiki_page_tags = Danbooru.RelatedTag.recent_search.wiki_page_tags;
    var $dest = $("#related-tags");
    $dest.empty();

    this.build_recent_and_frequent($dest);

    $dest.append(this.build_html(query, related_tags, "general"));
    this.build_translated($dest);
    if (wiki_page_tags.length) {
      $dest.append(Danbooru.RelatedTag.build_html("wiki:" + query, wiki_page_tags, "wiki"));
    }
    if (Danbooru.meta("ccs-server")) {
      if (Danbooru.RelatedTag.recent_ccs) {
        if (Danbooru.RelatedTag.recent_ccs.length) {
          Danbooru.RelatedTag.build_ccs($dest);
        }
      } else {
        Danbooru.RelatedTag.recent_ccs = []; // semaphore to only make 1 call
        Danbooru.RelatedTag.fetch_ccs($dest);
      }
    }
  }

  Danbooru.RelatedTag.fetch_ccs = function($dest) {
    $.getJSON(Danbooru.meta("ccs-server") + "/query", {
      "url": Danbooru.meta("image-url"),
      "ref": Danbooru.meta("image-ref"),
      "sig": Danbooru.meta("image-sig")
    }, function(data) {
      Danbooru.RelatedTag.recent_ccs = data.filter(function(x) {return x[0] > 0.25;});
      Danbooru.RelatedTag.recent_ccs = $.map(Danbooru.RelatedTag.recent_ccs, function(x) {return [[x[1], 4]];});

      if (Danbooru.RelatedTag.recent_ccs.length) {
        Danbooru.RelatedTag.build_ccs($dest);
      }
    });
  }

  Danbooru.RelatedTag.build_recent_and_frequent = function($dest) {
    var recent_tags = Danbooru.Cookie.get("recent_tags_with_categories");
    var favorite_tags = Danbooru.Cookie.get("favorite_tags_with_categories");
    if (recent_tags.length) {
      $dest.append(this.build_html("recent", this.other_tags(recent_tags), "recent"));
    }
    if (favorite_tags.length) {
      $dest.append(this.build_html("frequent", this.other_tags(favorite_tags), "frequent"));
    }
  }

  Danbooru.RelatedTag.other_tags = function(string) {
    if (string && string.length) {
      return $.map(string.match(/\S+ \d+/g), function(x, i) {
        var submatch = x.match(/(\S+) (\d+)/);
        return [[submatch[1], submatch[2]]];
      });
    } else {
      return [];
    }
  }

  Danbooru.RelatedTag.build_ccs = function($dest) {
    if (Danbooru.RelatedTag.recent_ccs) {
      $dest.append(this.build_html("Guessed Characters", Danbooru.RelatedTag.recent_ccs, "ccs"))
    }
  }

  Danbooru.RelatedTag.build_translated = function($dest) {
    if (Danbooru.RelatedTag.translated_tags && Danbooru.RelatedTag.translated_tags.length) {
      $dest.append(this.build_html("Translated Tags", Danbooru.RelatedTag.translated_tags, "translated"));
    }
  }

  Danbooru.RelatedTag.build_html = function(query, related_tags, name, is_wide_column) {
    if (query === null || query === "") {
      return "";
    }

    query = query.replace(/_/g, " ");
    var header = $("<em/>");

    var match = query.match(/^wiki:(.+)/);
    if (match) {
      header.html($("<a/>").attr("href", "/wiki_pages?title=" + encodeURIComponent(match[1])).attr("target", "_blank").text(query));
    } else {
      header.text(query);
    }

    var $div = $("<div/>");
    $div.attr("id", name + "-related-tags-column");
    $div.addClass("tag-column");
    if (is_wide_column) {
      $div.addClass("wide-column");
    }
    var $ul = $("<ul/>");
    $ul.append(
      $("<li/>").append(
        header
      )
    );

    $.each(related_tags, function(i, tag) {
      if (tag[0][0] !== " ") {
        var $link = $("<a/>");
        $link.text(tag[0].replace(/_/g, " "));
        $link.addClass("tag-type-" + tag[1]);
        $link.attr("href", "/posts?tags=" + encodeURIComponent(tag[0]));
        $link.click(Danbooru.RelatedTag.toggle_tag);
        if (Danbooru.RelatedTag.tags_include(tag[0])) {
          $link.addClass("selected");
        }
        $ul.append(
          $("<li/>").append($link)
        );
      } else {
        var text = tag[0];
        if (text.match(/^ http/)) {
          text = text.substring(1, 1000);
          var $url = $("<a/>");
          $url.text(text);
          $url.attr("href", text);
          $url.attr("target", "_blank");
          $ul.append($("<li/>").html($url));
        } else {
          $ul.append($("<li/>").text(text));
        }
      }
    });

    $div.append($ul);
    return $div;
  }

  Danbooru.RelatedTag.toggle_tag = function(e) {
    var $field = $("#upload_tag_string,#post_tag_string");
    var tag = $(e.target).html().replace(/ /g, "_").replace(/&gt;/g, ">").replace(/&lt;/g, "<").replace(/&amp;/g, "&");

    if (Danbooru.RelatedTag.tags_include(tag)) {
      var escaped_tag = Danbooru.regexp_escape(tag);
      $field.val($field.val().replace(new RegExp("(^|\\s)" + escaped_tag + "($|\\s)", "gi"), "$1$2"));
    } else {
      $field.val($field.val() + " " + tag);
    }
    $field.val($field.val().trim().replace(/ +/g, " ") + " ");

    $field[0].selectionStart = $field.val().length;
    Danbooru.RelatedTag.update_selected();
    e.preventDefault();
  }

  Danbooru.RelatedTag.toggle = function() {
    if ($("#related-tags").is(":visible")) {
      Danbooru.RelatedTag.hide();
    } else {
      Danbooru.RelatedTag.show();
      $("#related-tags-button").trigger("click");
    }
  }

  Danbooru.RelatedTag.show = function() {
    $("#related-tags").show()
    $("#toggle-related-tags-link").text("«");
    $("#edit-dialog").height("auto");
  }

  Danbooru.RelatedTag.hide = function() {
    $("#related-tags").hide();
    $("#toggle-related-tags-link").text("»");
  }
})();

$(function() {
  Danbooru.RelatedTag.initialize_all();
});
