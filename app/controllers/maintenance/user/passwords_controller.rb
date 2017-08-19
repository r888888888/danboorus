module Maintenance
  module User
    class PasswordsController < ApplicationController
      before_filter :basic_only

      def edit
        @user = CurrentUser.user
      end
    end
  end
end
