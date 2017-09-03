class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  concerning :Extensions do
    class_methods do
      def columns(*params)
        super.reject {|x| x.sql_type == "tsvector"}
      end

      def without_timeout
        connection.execute("SET STATEMENT_TIMEOUT = 0") unless Rails.env == "test"
        yield
      ensure
        connection.execute("SET STATEMENT_TIMEOUT = #{CurrentUser.user.try(:statement_timeout) || 3_000}") unless Rails.env == "test"
      end

      def with_timeout(n, default_value = nil, new_relic_params = {})
        connection.execute("SET STATEMENT_TIMEOUT = #{n}") unless Rails.env == "test"
        yield
      rescue ::ActiveRecord::StatementInvalid => x
        if Rails.env.production?
          NewRelic::Agent.notice_error(x, :custom_params => new_relic_params.merge(:user_id => CurrentUser.user.id, :user_ip_addr => CurrentUser.ip_addr))
        end
        return default_value
      ensure
        connection.execute("SET STATEMENT_TIMEOUT = #{CurrentUser.user.try(:statement_timeout) || 3_000}") unless Rails.env == "test"
      end

      def belongs_to_booru
        class_eval do
          belongs_to :booru
          before_validation(on: :create) do |rec| 
            rec.booru_id = Booru.current.id
          end
        end
      end

      def belongs_to_creator
        class_eval do
          belongs_to :creator, class_name: "User"
          before_validation(on: :create) do |rec| 
            rec.creator_id = CurrentUser.id
          end

          define_method :creator_name do
            User.id_to_name(creator_id)
          end
        end
      end

      def belongs_to_updater
        class_eval do
          belongs_to :updater, class_name: "User"
          before_validation do |rec| 
            rec.updater_id = CurrentUser.id
          end

          define_method :updater_name do
            User.id_to_name(updater_id)
          end
        end
      end
    end

    %w(execute select_value select_values select_all).each do |method_name|
      define_method("#{method_name}_sql") do |sql, *params|
        self.class.connection.__send__(method_name, self.class.sanitize_sql_array([sql, *params]))
      end

      self.class.__send__(:define_method, "#{method_name}_sql") do |sql, *params|
        connection.__send__(method_name, sanitize_sql_array([sql, *params]))
      end
    end
  end

  module ApiMethods
    extend ActiveSupport::Concern

    def as_json(options = {})
      options ||= {}
      options[:except] ||= []
      options[:except] += hidden_attributes

      options[:methods] ||= []
      options[:methods] += method_attributes

      super(options)
    end

    def to_xml(options = {}, &block)
      options ||= {}

      options[:except] ||= []
      options[:except] += hidden_attributes

      options[:methods] ||= []
      options[:methods] += method_attributes

      super(options, &block)
    end

    def serializable_hash(*args)
      hash = super(*args)
      hash.transform_keys { |key| key.delete("?") }
    end

    protected

    def hidden_attributes
      [:uploader_ip_addr, :updater_ip_addr, :creator_ip_addr, :ip_addr]
    end

    def method_attributes
      []
    end
  end

  include ApiMethods
end
