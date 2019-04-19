class HomepageController < ApplicationController
  get '/' do
    title("The Best Mazes")
    erb :index, layout: :layout
  end
end
