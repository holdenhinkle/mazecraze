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
    binding.pry
    erb :mazes_formulas_new
  end

  post '/admin/mazes/formulas/new' do
    @params[:experiment] ? @params[:experiment] = true : @params[:experiment] = false
    # MOVE THE FOLLOWING VAR CREATION TO MAZEFORMULA
    params = convert_empty_quotes_to_zero(@params)
    new_formula = { type: params[:maze_type],
                    x: params[:x_value].to_i,
                    y: params[:y_value].to_i,
                    endpoints: params[:endpoints].to_i,
                    barriers: params[:barriers].to_i,
                    bridges: params[:bridges].to_i,
                    tunnels: params[:tunnels].to_i,
                    portals: params[:portals].to_i,
                    experiment: params[:experiment]                  
                  }

    @maze_types = Maze.types
    @maze_types_popover = Maze.types_popover
    @maze_dimensions_popover = Maze.dimensions_popover
    @square_type_popovers = MazeSquare.types_popovers

    if MazeFormula.exists?(new_formula)
      session[:error] = "That maze formula already exists."
      erb :mazes_formulas_new
    elsif params[:experiment] || MazeFormula.valid?(new_formula)
      MazeFormula.save!(new_formula)
      session[:success] = "Your maze formula was saved."
      erb :mazes_formulas_new
    else
      add_hashes_to_session_hash(MazeFormula.validation(new_formula))
      session[:error] = "That maze formula is invalid."
      redirect "/admin/mazes/formulas/new"
    end
  end
end
