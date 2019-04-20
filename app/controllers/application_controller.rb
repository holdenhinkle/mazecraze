require './config/environments'
require "sinatra/base"
require "sinatra/reloader"
require "sinatra/content_for"
require 'sinatra/activerecord'
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
    require "sinatra/reloader"
  end

  # don't enable logging when running tests
  configure(:production,:development) do
    enable :logging
  end

  # used to display 404 error pages
  not_found do
    title '404 -- Page Not Found'
    erb :not_found, layout: :layout
  end

  # execute sql statements via activerecord
  def execute(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  # $0 is the executed file
  # __FILE__ == $0
  run! if __FILE__ == $0

  # MAZE - DONE
  # board = { type: :simple, x: 3, y: 2, endpoints: 1, barriers: 1, level: 1 }

  # BRIDGE MAZE - DONE
  # board = { type: :bridge, x: 4, y: 4, endpoints: 1, barriers: 1, bridges: 1, level: 1 }

  # TUNNEL MAZE - DONE
  # 1 tunnel, 1 barrier
  # board = { type: :tunnel, x: 3, y: 3, endpoints: 1, barriers: 1, tunnels: 1, level: 1 }

  # PORTAL MAZE - DONE
  # 1 portal, 1 barrier
  # board = { type: :portal, x: 3, y: 3, endpoints: 1, barriers: 1, portals: 1, level: 1 }

  # Board.new(board)
end
