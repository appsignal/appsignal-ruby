# frozen_string_literal: true

module Appsignal
  module Utils
    module RailsHelper
      def self.detected_rails_app_name
        rails_class = Rails.application.class
        if rails_class.respond_to? :module_parent_name # Rails 6
          rails_class.module_parent_name
        else # Older Rails versions
          rails_class.parent_name
        end
      end
    end
  end
end
