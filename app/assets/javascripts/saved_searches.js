Danbooru.SavedSearch = {};

Danbooru.SavedSearch.initialize_all = function() {
  if ($("#c-saved-searches").length) {
    Danbooru.sorttable($("#c-saved-searches table"));
  }
}

$(Danbooru.SavedSearch.initialize_all);
