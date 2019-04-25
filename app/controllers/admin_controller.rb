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
    @popovers = MazeFormula.new_formula_form_popovers
    erb :mazes_formulas_new
  end

  post '/admin/mazes/formulas/new' do
    @formula = MazeFormula.new_formula_hash(params)
    if MazeFormula.exists?(@formula)
      session[:error] = "That maze formula already exists."
      @maze_types = Maze.types
      @popovers = MazeFormula.new_formula_form_popovers  
      erb :mazes_formulas_new
    elsif params[:experiment] || MazeFormula.valid?(@formula)
      MazeFormula.save!(@formula)
      session[:success] = "Your maze formula was saved."
      erb :mazes_formulas_new
    else
      add_hashes_to_session_hash(MazeFormula.validation(@formula))
      session[:error] = "That maze formula is invalid."
      @maze_types = Maze.types
      @popovers = MazeFormula.new_formula_form_popovers  
      redirect "/admin/mazes/formulas/new"
    end
  end
end
