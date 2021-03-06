class Tag < ApplicationRecord
  COSINE_SIMILARITY_RELATED_TAG_THRESHOLD = 1000
  METATAGS = "-user|user|commenter|comm|noter|noteupdater|artcomm|-pool|pool|ordpool|-fav|fav|ordfav|sha256|-rating|rating|-locked|locked|width|height|mpixels|ratio|score|favcount|filesize|source|-source|id|-id|date|age|order|limit|-status|status|tagcount|copytags|parent|-parent|child|pixiv_id|pixiv|search|filetype|-filetype|flagger|-flagger"
  SUBQUERY_METATAGS = "commenter|comm|noter|noteupdater|artcomm|flagger|-flagger"
  has_one :wiki_page, :foreign_key => "title", :primary_key => "name"

  validates :name, uniqueness: true, tag_name: true, on: :create

  module ApiMethods
    def to_legacy_json
      return {
        "name" => name,
        "id" => id,
        "created_at" => created_at.try(:strftime, "%Y-%m-%d %H:%M"),
        "count" => post_count,
        "ambiguous" => false
      }.to_json
    end
  end

  module CountMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def counts_for(tag_names)
        select_all_sql("SELECT name, post_count FROM tags WHERE name IN (?)", tag_names)
      end

      def highest_post_count
        Cache.get("highest-post-count", 4.hours) do
          select("post_count").order("post_count DESC").first.post_count
        end
      end

      def increment_post_counts(tag_names)
        Tag.where(:name => tag_names).update_all("post_count = post_count + 1")
        Post.expire_cache_for_all(tag_names)
      end

      def decrement_post_counts(tag_names)
        Tag.where(:name => tag_names).update_all("post_count = post_count - 1")
        Post.expire_cache_for_all(tag_names)
      end

      def clean_up_negative_post_counts!
        Tag.where("post_count < 0").find_each do |tag|
          tag.fix_post_count
        end
      end
    end

    def real_post_count
      @real_post_count ||= Post.raw_tag_match(name).where("true /* Tag#real_post_count */").count
    end

    def fix_post_count
      update_column(:post_count, real_post_count)
    end
  end

  module StatisticsMethods
    def trending_count_limit
      10
    end

    def trending
      Cache.get("popular-tags-v3", 1.hour) do
        CurrentUser.scoped(User.admins.first, "127.0.0.1") do
          n = 24
          counts = {}

          while counts.empty? && n < 1000
            tag_strings = Post.select_values_sql("select tag_string from posts where created_at >= ?", n.hours.ago)
            tag_strings.each do |tag_string|
              tag_string.scan(/\S+/).each do |tag|
                counts[tag] ||= 0
                counts[tag] += 1
              end
            end
            n *= 2
          end

          counts = counts.to_a.select {|x| x[1] > trending_count_limit}
          counts = counts.map do |tag_name, recent_count|
            tag = Tag.find_or_create_by_name(tag_name)
            [tag_name, recent_count.to_f / tag.post_count.to_f]
          end

          counts.sort_by {|x| -x[1]}.slice(0, 25).map(&:first)
        end
      end
    end
  end

  module NameMethods
    def normalize_name(name)
      name.to_s.mb_chars.downcase.strip.tr(" ", "_").to_s
    end

    def find_or_create_by_name(name, options = {})
      name = normalize_name(name)
      tag = find_by_name(name)

      if tag
        tag
      else
        Tag.new.tap do |t|
          t.name = name
          t.save
        end
      end
    end
  end

  module ParseMethods
    def normalize(query)
      query.to_s.gsub(/\u3000/, " ").strip
    end

    def normalize_query(query, sort: true)
      tags = Tag.scan_query(query.to_s)
      tags = tags.map { |t| Tag.normalize_name(t) }
      tags = tags.sort if sort
      tags = tags.uniq
      tags.join(" ")
    end

    def scan_query(query)
      tagstr = normalize(query)
      list = tagstr.scan(/-?source:".*?"/) || []
      list + tagstr.gsub(/-?source:".*?"/, "").scan(/[^[:space:]]+/).uniq
    end

    def scan_tags(tags, options = {})
      tagstr = normalize(tags)
      list = tagstr.scan(/source:".*?"/) || []
      list += tagstr.gsub(/source:".*?"/, "").scan(/[^[:space:]]+/).uniq
      if options[:strip_metatags]
        list = list.map {|x| x.sub(/^[-~]/, "")}
      end
      list
    end

    def parse_cast(object, type)
      case type
      when :integer
        object.to_i

      when :float
        object.to_f

      when :date
        begin
          Time.zone.parse(object)
        rescue Exception
          nil
        end

      when :age
        object =~ /(\d+)(s(econds?)?|mi(nutes?)?|h(ours?)?|d(ays?)?|w(eeks?)?|mo(nths?)?|y(ears?)?)?/i

        size = $1.to_i
        unit = $2

        case unit
        when /^s/i
          size.seconds.ago
        when /^mi/i
          size.minutes.ago
        when /^h/i
          size.hours.ago
        when /^d/i
          size.days.ago
        when /^w/i
          size.weeks.ago
        when /^mo/i
          size.months.ago
        when /^y/i
          size.years.ago
        else
          size.seconds.ago
        end

      when :ratio
        object =~ /\A(\d+(?:\.\d+)?):(\d+(?:\.\d+)?)\Z/i

        if $1 && $2.to_f != 0.0
         ($1.to_f / $2.to_f).round(2)
        else
          object.to_f.round(2)
        end

      when :filesize
        object =~ /\A(\d+(?:\.\d*)?|\d*\.\d+)([kKmM]?)[bB]?\Z/

      	size = $1.to_f
      	unit = $2

      	conversion_factor = case unit
    	  when /m/i
    	    1024 * 1024
    	  when /k/i
    	    1024
    	  else
    	    1
  	    end

  	    (size * conversion_factor).to_i
      end
    end

    def parse_helper(range, type = :integer)
      # "1", "0.5", "5.", ".5":
      # (-?(\d+(\.\d*)?|\d*\.\d+))
      case range
      when /\A(.+?)\.\.(.+)/
        return [:between, parse_cast($1, type), parse_cast($2, type)]

      when /\A<=(.+)/, /\A\.\.(.+)/
        return [:lte, parse_cast($1, type)]

      when /\A<(.+)/
        return [:lt, parse_cast($1, type)]

      when /\A>=(.+)/, /\A(.+)\.\.\Z/
        return [:gte, parse_cast($1, type)]

      when /\A>(.+)/
        return [:gt, parse_cast($1, type)]

      when /,/
        return [:in, range.split(/,/).map {|x| parse_cast(x, type)}]

      else
        return [:eq, parse_cast(range, type)]

      end
    end

    def parse_helper_fudged(range, type)
      result = parse_helper(range, type)
      # Don't fudge the filesize when searching filesize:123b or filesize:123.
      if result[0] == :eq && type == :filesize && range !~ /[km]b?\Z/i
        result
      elsif result[0] == :eq
        new_min = (result[1] * 0.95).to_i
        new_max = (result[1] * 1.05).to_i
        [:between, new_min, new_max]
      else
        result
      end
    end

    def reverse_parse_helper(array)
      case array[0]
      when :between
        [:between, *array[1..-1].reverse]

      when :lte
        [:gte, *array[1..-1]]

      when :lt
        [:gt, *array[1..-1]]

      when :gte
        [:lte, *array[1..-1]]

      when :gt
        [:lt, *array[1..-1]]

      else
        array
      end
    end

    def parse_tag(tag, output)
      if tag[0] == "-" && tag.size > 1
        output[:exclude] << tag[1..-1].mb_chars.downcase

      elsif tag[0] == "~" && tag.size > 1
        output[:include] << tag[1..-1].mb_chars.downcase

      elsif tag =~ /\*/
        matches = Tag.name_matches(tag.downcase).select("name").limit(Danbooru.config.tag_query_limit).order("post_count DESC").map(&:name)
        matches = ["~no_matches~"] if matches.empty?
        output[:include] += matches

      else
        output[:related] << tag.mb_chars.downcase
      end
    end

    def parse_query(query, options = {})
      q = {}

      q[:tag_count] = 0

      q[:tags] = {
        :related => [],
        :include => [],
        :exclude => []
      }

      scan_query(query).each do |token|
        q[:tag_count] += 1 unless token == "status:deleted" || token =~ /\Alimit:.+\Z/

        if token =~ /\A(#{METATAGS}):(.+)\Z/i
          case $1.downcase
          when "-user"
            q[:uploader_id_neg] ||= []
            user_id = User.name_to_id($2)
            q[:uploader_id_neg] << user_id unless user_id.blank?

          when "user"
            user_id = User.name_to_id($2)
            q[:uploader_id] = user_id unless user_id.blank?

          when "flagger"
            q[:flagger_ids] ||= []

            if $2 == "none"
              q[:flagger_ids] << "none"
            elsif $2 == "any"
              q[:flagger_ids] << "any"
            else
              user_id = User.name_to_id($2)
              q[:flagger_ids] << user_id unless user_id.blank?
            end

          when "-flagger"
            if $2 == "none"
              q[:flagger_ids] ||= []
              q[:flagger_ids] << "any"
            elsif $2 == "any"
              q[:flagger_ids] ||= []
              q[:flagger_ids] << "none"
            else
              q[:flagger_ids_neg] ||= []
              user_id = User.name_to_id($2)
              q[:flagger_ids_neg] << user_id unless user_id.blank?
            end

          when "commenter", "comm"
            q[:commenter_ids] ||= []

            if $2 == "none"
              q[:commenter_ids] << "none"
            elsif $2 == "any"
              q[:commenter_ids] << "any"
            else
              user_id = User.name_to_id($2)
              q[:commenter_ids] << user_id unless user_id.blank?
            end

          when "noter"
            q[:noter_ids] ||= []

            if $2 == "none"
              q[:noter_ids] << "none"
            elsif $2 == "any"
              q[:noter_ids] << "any"
            else
              user_id = User.name_to_id($2)
              q[:noter_ids] << user_id unless user_id.blank?
            end

          when "noteupdater"
            q[:note_updater_ids] ||= []
            user_id = User.name_to_id($2)
            q[:note_updater_ids] << user_id unless user_id.blank?

          when "artcomm"
            q[:artcomm_ids] ||= []
            user_id = User.name_to_id($2)
            q[:artcomm_ids] << user_id unless user_id.blank?

          when "-pool"
            if $2.downcase == "none"
              q[:pool] = "any"
            elsif $2.downcase == "any"
              q[:pool] = "none"
            elsif $2.downcase == "series"
              q[:tags][:exclude] << "pool:series"
            elsif $2.downcase == "collection"
              q[:tags][:exclude] << "pool:collection"
            else
              q[:tags][:exclude] << "pool:#{Pool.name_to_id($2)}"
            end

          when "pool"
            if $2.downcase == "none"
              q[:pool] = "none"
            elsif $2.downcase == "any"
              q[:pool] = "any"
            elsif $2.downcase == "series"
              q[:tags][:related] << "pool:series"
            elsif $2.downcase == "collection"
              q[:tags][:related] << "pool:collection"
            elsif $2.include?("*")
              pools = Pool.name_matches($2).select("id").limit(Danbooru.config.tag_query_limit).order("post_count DESC")
              q[:tags][:include] += pools.map {|pool| "pool:#{pool.id}"}
            else
              q[:tags][:related] << "pool:#{Pool.name_to_id($2)}"
            end

          when "ordpool"
            pool_id = Pool.name_to_id($2)
            q[:tags][:related] << "pool:#{pool_id}"
            q[:ordpool] = pool_id

          when "-fav"
            q[:tags][:exclude] << "fav:#{User.name_to_id($2)}"

          when "fav"
            q[:tags][:related] << "fav:#{User.name_to_id($2)}"

          when "ordfav"
            user_id = User.name_to_id($2)
            q[:tags][:related] << "fav:#{user_id}"
            q[:ordfav] = user_id

          when "search"
            q[:saved_searches] ||= []
            q[:saved_searches] << $2

          when "sha256"
            q[:sha256] = $2.downcase.split(/,/)

          when "-rating"
            q[:rating_negated] = $2.downcase

          when "rating"
            q[:rating] = $2.downcase

          when "-locked"
            q[:locked_negated] = $2.downcase

          when "locked"
            q[:locked] = $2.downcase

          when "id"
            q[:post_id] = parse_helper($2)

          when "-id"
            q[:post_id_negated] = $2.to_i

          when "width"
            q[:width] = parse_helper($2)

          when "height"
            q[:height] = parse_helper($2)

          when "ratio"
            q[:ratio] = parse_helper($2, :ratio)

          when "score"
            q[:score] = parse_helper($2)

          when "favcount"
            q[:fav_count] = parse_helper($2)

          when "filesize"
      	    q[:filesize] = parse_helper_fudged($2, :filesize)

          when "source"
            src = $2.gsub(/\A"(.*)"\Z/, '\1')
            q[:source] = (src.to_escaped_for_sql_like + "%").gsub(/%+/, '%')

          when "-source"
            src = $2.gsub(/\A"(.*)"\Z/, '\1')
            q[:source_neg] = (src.to_escaped_for_sql_like + "%").gsub(/%+/, '%')

          when "date"
            q[:date] = parse_helper($2, :date)

          when "age"
            q[:age] = reverse_parse_helper(parse_helper($2, :age))

          when "tagcount"
            q[:post_tag_count] = parse_helper($2)

          when "parent"
            q[:parent] = $2.downcase

          when "-parent"
            if $2.downcase == "none"
              q[:parent] = "any"
            elsif $2.downcase == "any"
              q[:parent] = "none"
            else
              q[:parent_neg_ids] ||= []
              q[:parent_neg_ids] << $2.downcase
            end

          when "child"
            q[:child] = $2.downcase

          when "order"
            q[:order] = $2.downcase

          when "limit"
            # Do nothing. The controller takes care of it.

          when "-status"
            q[:status_neg] = $2.downcase

          when "status"
            q[:status] = $2.downcase

          when "filetype"
            q[:filetype] = $2.downcase

          when "-filetype"
            q[:filetype_neg] = $2.downcase

          when "pixiv_id", "pixiv"
            q[:pixiv_id] = parse_helper($2)

          end

        else
          parse_tag(token, q[:tags])
        end
      end

      normalize_tags_in_query(q)

      return q
    end

    def normalize_tags_in_query(query_hash)
      query_hash[:tags][:exclude] = query_hash[:tags][:exclude]
      query_hash[:tags][:include] = query_hash[:tags][:include]
      query_hash[:tags][:related] = query_hash[:tags][:related]
    end
  end

  module RelationMethods
    def update_related
      return unless should_update_related?
      CurrentUser.scoped(User.first, "127.0.0.1") do
        self.related_tags = RelatedTagCalculator.calculate_from_sample_to_array(name).join(" ")
      end
      self.related_tags_updated_at = Time.now
      save
    rescue ActiveRecord::StatementInvalid
    end

    def update_related_if_outdated
      if should_update_related?
        if post_count < COSINE_SIMILARITY_RELATED_TAG_THRESHOLD
          delay(:queue => "default").update_related
        elsif post_count >= COSINE_SIMILARITY_RELATED_TAG_THRESHOLD
          key = Cache.sanitize(name)
          cache_check = Cache.get("urt:#{key}")

          if cache_check
            sqs = SqsService.new(Danbooru.config.aws_sqs_reltagcalc_url)
            sqs.send_message("calculate #{name}")
          else
            Cache.put("urt:#{key}", true, 600)
          end
        end
      end
    end

    def related_cache_expiry
      base = Math.sqrt([post_count, 0].max)
      if base > 24 * 30
        24 * 30
      elsif base < 24
        24
      else
        base
      end
    end

    def should_update_related?
      related_tags.blank? || related_tags_updated_at.blank? || related_tags_updated_at < related_cache_expiry.hours.ago
    end

    def related_tag_array
      update_related_if_outdated
      related_tags.to_s.split(/ /).in_groups_of(2)
    end
  end

  module SearchMethods
    def nonempty
      where("tags.post_count > 0")
    end

    def name_matches(name)
      where("tags.name LIKE ? ESCAPE E'\\\\'", name.mb_chars.downcase.to_escaped_for_sql_like)
    end

    def named(name)
      where("tags.name = ?", name)
    end

    def search(params)
      q = where("true")
      params = {} if params.blank?

      if params[:name_matches].present?
        q = q.name_matches(params[:name_matches].strip.tr(" ", "_"))
      end

      if params[:name].present?
        q = q.where("tags.name in (?)", params[:name].split(","))
      end

      if params[:hide_empty].blank? || params[:hide_empty] != "no"
        q = q.where("post_count > 0")
      end

      if params[:has_wiki] == "yes"
        q = q.joins(:wiki_page)
      elsif params[:has_wiki] == "no"
        q = q.joins("LEFT JOIN wiki_pages ON tags.name = wiki_pages.title").where("wiki_pages.title IS NULL")
      end

      params[:order] ||= params.delete(:sort)
      case params[:order]
      when "name"
        q = q.reorder("name")
      when "date"
        q = q.reorder("id desc")
      when "count"
        q = q.reorder("post_count desc")
      else
        q = q.reorder("id desc")
      end

      q
    end
  end

  include ApiMethods
  include CountMethods
  extend StatisticsMethods
  extend NameMethods
  extend ParseMethods
  include RelationMethods
  extend SearchMethods
end
