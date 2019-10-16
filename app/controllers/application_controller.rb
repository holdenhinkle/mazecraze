require './config/environments'
require "sinatra/base"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require 'yaml'
require 'fileutils'
require 'json'
require 'date'
require 'pry'

class ApplicationController < Sinatra::Base
  helpers ApplicationHelper

  configure do
    enable :sessions
    set :views, File.expand_path('../../views', __FILE__)
    set :public_folder, File.expand_path('../../../assets', __FILE__)
    set :static, true
    set :session_secret, "secret"
    set :erb, escape_html: true
  end

  configure(:development) do
    register Sinatra::Reloader
    also_reload "../../models/database_persistence.rb"
    after_reload do
      puts 'reloaded'
    end
  end

  # don't enable logging when running tests
  configure(:production,:development) do
    enable :logging # IS THIS WORKING?
  end

  not_found do
    title '404 -- Page Not Found'
    erb :not_found, layout: :layout
  end

  # $0 is the executed file
  # __FILE__ == $0
  run! if __FILE__ == $0
end
