require 'pry'

class AdminController < ApplicationController
  get '/admin' do
    @title = "Home - Maze Craze Admin"
    erb :admin
  end

  get '/admin/mazes' do
    @title = "Mazes - maze Craze Admin"
    erb :mazes
  end

  get '/admin/mazes/formulas' do
    @title = "Mazes - maze Craze Admin"
    erb :mazes_formulas
  end

  get '/admin/mazes/formulas/new' do
    @title = "New Maze Formula - Maze Craze Admin"
    @maze_types = Maze.types
    @maze_constraints = Maze.basic_contraints
    erb :mazes_formulas_new
  end

  post '/admin/mazes/formulas/new' do
    @title = "Mazes - maze Craze Admin"
    new_formula = { type: params[:maze_type].to_sym,
                    x: params[:x_value].to_i,
                    y: params[:y_value].to_i,
                    endpoints: params[:endpoints].to_i,
                    barriers: params[:barriers].to_i }
    binding.pry
    if Maze.formula_exists?(new_formula)
      session[:message] = { error: "The maze formula you submitted already exists." }
      redirect "/admin/mazes/formulas/new"
    elsif Maze.symbol_to_class(new_formula[:type]).valid?(new_formula)
      session[:message] = { error: "The formula you submitted is invalid. Please see the validation alerts below."}
      Maze.symbol_to_class(new_formula[:type]).new(new_formula)
      erb :mazes_formulas_new
    else
      # save formula to db
      session[:message] = { success: "Your maze formula was successfully submitted. <a href=\"/admin/mazes/approve\">Approve the mazes</a> generated from this formula once they have been generated." }
      redirect "/admin/mazes/formulas/new"
    end

    
    # build new formula hash
    # pass it to mazes_formula
    # check if it's valid
    #   redirect back to new formula if it's not with error message and form validation if not
    #   otherwise 
    #     save formula to db
    #     get new formula page with success message
  end
end
