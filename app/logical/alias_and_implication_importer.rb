class AliasAndImplicationImporter
  attr_accessor :text, :commands, :forum_id, :skip_secondary_validations

  def initialize(text, forum_id, rename_aliased_pages = "0", skip_secondary_validations = true)
    @forum_id = forum_id
    @text = text
    @skip_secondary_validations = skip_secondary_validations
  end

  def process!(approver = CurrentUser.user)
    tokens = AliasAndImplicationImporter.tokenize(text)
    parse(tokens, approver)
  end

  def validate!
    tokens = AliasAndImplicationImporter.tokenize(text)
    validate(tokens)
  end

  def self.tokenize(text)
    text = text.dup
    text.gsub!(/^\s+/, "")
    text.gsub!(/\s+$/, "")
    text.gsub!(/ {2,}/, " ")
    text.split(/\r\n|\r|\n/).map do |line|
      if line =~ /^(?:create implication|implicating|implicate|imply) (\S+) -> (\S+)$/i
        [:create_implication, $1, $2]

      elsif line =~ /^(?:remove implication|unimplicating|unimplicate|unimply) (\S+) -> (\S+)$/i
        [:remove_implication, $1, $2]

      elsif line =~ /^(?:mass update|updating|update|change) (.+?) -> (.*)$/i
        [:mass_update, $1, $2]

      elsif line.strip.empty?
        # do nothing
      else
        raise "Unparseable line: #{line}"
      end
    end
  end

  def validate(tokens)
    tokens.map do |token|
      case token[0]

      when :create_implication
        tag_implication = TagImplication.new(:forum_topic_id => forum_id, :status => "pending", :antecedent_name => token[1], :consequent_name => token[2], :skip_secondary_validations => skip_secondary_validations)
        unless tag_implication.valid?
          raise "Error: #{tag_implication.errors.full_messages.join("; ")} (create implication #{tag_implication.antecedent_name} -> #{tag_implication.consequent_name})"
        end

      when :remove_implication, :mass_update
        # okay

      else
        raise "Unknown token: #{token[0]}"
      end
    end
  end

private

  def parse(tokens, approver)
    ActiveRecord::Base.transaction do
      tokens.map do |token|
        case token[0]
        when :create_implication
          tag_implication = TagImplication.create(:forum_topic_id => forum_id, :status => "pending", :antecedent_name => token[1], :consequent_name => token[2], :skip_secondary_validations => skip_secondary_validations)
          unless tag_implication.valid?
            raise "Error: #{tag_implication.errors.full_messages.join("; ")} (create implication #{tag_implication.antecedent_name} -> #{tag_implication.consequent_name})"
          end
          tag_implication.approve!(approver: approver, update_topic: false)

        when :remove_implication
          tag_implication = TagImplication.where("antecedent_name = ? and consequent_name = ?", token[1], token[2]).first
          raise "Implication for #{token[1]} not found" if tag_implication.nil?
          tag_implication.destroy

        when :mass_update
          Delayed::Job.enqueue(Moderator::TagBatchChange.new(token[1], token[2], CurrentUser.user, CurrentUser.ip_addr), :queue => "default")

        else
          raise "Unknown token: #{token[0]}"
        end
      end
    end
  end
end
