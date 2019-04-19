class PlayController < ApplicationController
  get '/play' do
    title("Let's Play")
    erb :play, layout: :layout
  end
end
