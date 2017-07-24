module Moderator
  module Dashboard
    class Report
      attr_reader :min_date, :max_level

      def initialize(min_date, max_level)
        @min_date = min_date.present? ? min_date.to_date : 1.week.ago
        @max_level = max_level.present? ? max_level.to_i : User::Levels::MEMBER
      end

      def flags
        ActiveRecord::Base.without_timeout do
          Queries::PostFlag.all(min_date)
        end
      end
    end
  end
end
