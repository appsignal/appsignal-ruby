# frozen_string_literal: true

require "hanami"
require "hanami/action"

module HanamiApp
  class App < Hanami::App
  end

  class Routes < Hanami::Routes
    get "/books", :to => "books.index"
  end

  module Actions
    module Books
      class Index < Hanami::Action
        def handle(_request, response)
          response.body = "YOU REQUESTED BOOKS!"
        end
      end

      class Error < Hanami::Action
        def handle(_request, _response)
          raise ExampleException, "exception message"
        end
      end
    end
  end
end
