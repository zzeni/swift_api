## This is not needed for Thin > 1.0.0
ENV['RACK_ENV'] = "production"

require File.expand_path '../swift_api.rb', __FILE__

run Sinatra::Application
