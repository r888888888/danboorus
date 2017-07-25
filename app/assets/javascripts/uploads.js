(function() {
  Danbooru.Upload = {};

  Danbooru.Upload.initialize_all = function() {
    if ($("#c-uploads,#c-posts").length) {
      this.initialize_enter_on_tags();
      this.initialize_info_manual();
    }

    if ($("#c-uploads").length) {
      $("#image").load(this.initialize_image);
      this.initialize_info_bookmarklet();
      this.initialize_similar();
      this.initialize_shortcuts();
      $("#related-tags-button").trigger("click");
      $("#find-artist-button").trigger("click");

      $("#toggle-artist-commentary").click(function(e) {
        Danbooru.Upload.toggle_commentary();
        e.preventDefault();
      });
    }
  }

  Danbooru.Upload.initialize_shortcuts = function() {
    Danbooru.keydown("e", "edit", function(e) {
      $("#upload_tag_string").focus();
      e.preventDefault();
    });
  };

  Danbooru.Upload.initialize_enter_on_tags = function() {
    $("#upload_tag_string,#post_tag_string").on("keydown.danbooru.submit", null, "return", function(e) {
      if (!Danbooru.autocompleting) {
        $("#form").trigger("submit");
        $("#quick-edit-form").trigger("submit");
        $("#upload_tag_string,#post_tag_string").off(".submit");
      }

      e.preventDefault();
    });
  }

  Danbooru.Upload.initialize_info_bookmarklet = function() {
    $("#source-info ul").hide();
    $("#fetch-data-bookmarklet").click(function(e) {
      var xhr = $.get(e.target.href);
      xhr.success(Danbooru.Upload.fill_source_info);
      xhr.fail(function(data) {
        $("#source-info span#loading-data").html("Error: " + data.responseJSON["message"])
      });
      e.preventDefault();
    });
    $("#fetch-data-bookmarklet").trigger("click");
  }

  Danbooru.Upload.initialize_info_manual = function() {
    $("#source-info ul").hide();

    $("#fetch-data-manual").click(function(e) {
      var source = $("#upload_source,#post_source").val();
      if (!/\S/.test(source)) {
        Danbooru.error("Error: You must enter a URL into the source field to get its data");
      } else if (!/^https?:\/\//.test(source)) {
        Danbooru.error("Error: Source is not a URL");
      } else {
        $("#source-info span#loading-data").show();
        var xhr = $.get("/source.json?url=" + encodeURIComponent(source));
        xhr.success(Danbooru.Upload.fill_source_info);
        xhr.fail(function(data) {
          $("#source-info span#loading-data").html("Error: " + data.responseJSON["message"])
        });
      }
      e.preventDefault();
    });
  }

  Danbooru.Upload.fill_source_info = function(data) {
    $("#source-tags").empty();
    $.each(data.tags, function(i, v) {
      $("<a>").attr("href", v[1]).text(v[0]).appendTo("#source-tags");
    });

    $("#source-artist").html($("<a>").attr("href", data.profile_url).text(data.artist_name));

    Danbooru.RelatedTag.translated_tags = data.translated_tags;
    Danbooru.RelatedTag.build_all();

    var new_artist_href = "/artists/new?other_names="
                        + encodeURIComponent(data.artist_name)
                        + "&urls="
                        + encodeURIComponent($.unique([data.profile_url, data.normalized_for_artist_finder_url]).join("\n"));

    $("#source-record").html($("<a>").attr("href", new_artist_href).text("Create New"));

    if (data.image_urls.length > 1) {
      $("#gallery-warning").show();
    } else {
      $("#gallery-warning").hide();
    }

    $("#upload_artist_commentary_title").val(data.artist_commentary.dtext_title);
    $("#upload_artist_commentary_desc").val(data.artist_commentary.dtext_description);
    Danbooru.Upload.toggle_commentary();

    $("#source-info span#loading-data").hide();
    $("#source-info ul").show();
  }

  Danbooru.Upload.update_scale = function() {
    var $image = $("#image");
    var ratio = $image.data("scale-factor");
    if (ratio < 1) {
      $("#scale").html("Scaled " + parseInt(100 * ratio) + "% (original: " + $image.data("original-width") + "x" + $image.data("original-height") + ")");
    } else {
      $("#scale").html("Original: " + $image.data("original-width") + "x" + $image.data("original-height"));
    }
  }

  Danbooru.Upload.initialize_image = function() {
    var $image = $("#image");
    if ($image.length) {
      var width = $image.width();
      var height = $image.height();
      $image.data("original-width", width);
      $image.data("original-height", height);
      Danbooru.Post.resize_image_to_window($image);
      Danbooru.Post.initialize_post_image_resize_to_window_link();
      Danbooru.Upload.update_scale();
      $("#image-resize-to-window-link").click(Danbooru.Upload.update_scale);
    }
  }

  Danbooru.Upload.toggle_commentary = function() {
    if ($(".artist-commentary").is(":visible")) {
      $("#toggle-artist-commentary").text("show »");
    } else {
      $("#toggle-artist-commentary").text("« hide");
    }

    $(".artist-commentary").slideToggle();
  };
})();

$(function() {
  Danbooru.Upload.initialize_all();
});
