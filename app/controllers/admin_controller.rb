require 'pry'

class AdminController < DatabasePersistence
# class AdminController < ApplicationController
  get '/admin' do
    @title = "Home - Maze Craze Admin"
    erb :admin
  end

  get '/admin/mazes' do
    @title = "Mazes - maze Craze Admin"
    erb :mazes
  end

  # get '/admin/mazes/:type' do
  #   @title = "Mazes - maze Craze Admin"
  #   erb :mazes
  # end

  # get '/admin/mazes/id/:id' do
  #   @title = "Mazes - maze Craze Admin"
  #   erb :mazes
  # end

  get '/admin/mazes/formulas' do
    @title = "Maze Formulas - Maze Craze Admin"
    @maze_types = Maze.types
    @formula_status_list = MazeFormula.status_list #RENAME THIS METHOD
    @maze_status_counts = {}
    @maze_types.each do |type|
      status_counts_by_maze_type = {}
      @formula_status_list.each do |status|
        status_counts_by_maze_type[status] = MazeFormula.count_by_type_and_status(type, status).rows[0][0]
      end
      @maze_status_counts[type] = status_counts_by_maze_type
    end
    erb :mazes_formulas
  end

  get '/admin/mazes/formulas/new' do
    @title = "New Maze Formula - Maze Craze Admin"
    @maze_types = Maze.types
    @popovers = MazeFormula.new_formula_form_popovers
    erb :mazes_formulas_new
  end

  post '/admin/mazes/formulas/new' do
    # REFACTOR THIS BLOCK
    @formula = MazeFormula.maze_formula_type_to_class(params[:maze_type]).new(params)
    binding.pry
    if MazeFormula.exists?(@formula)
      # validation hash
      session[:error] = "That maze formula already exists."
      @maze_types = Maze.types
      @popovers = MazeFormula.new_formula_form_popovers  
      erb :mazes_formulas_new
    elsif params[:experiment] && MazeFormula.experiment_valid?(@formula) ||
            MazeFormula.valid?(@formula)
      MazeFormula.save!(@formula)
      session[:success] = "Your maze formula was saved."
      redirect "/admin/mazes/formulas/new"
    else
      add_hashes_to_session_hash(MazeFormula.validation(@formula))
      session[:error] = "That maze formula is invalid."
      @maze_types = Maze.types
      @popovers = MazeFormula.new_formula_form_popovers
      erb :mazes_formulas_new
    end
  end

  get '/admin/mazes/formulas/:type' do
    @maze_type = params[:type]
    if Maze.types.include?(@maze_type)
      @title = "#{@maze_type} Maze Formulas - Maze Craze Admin"
      @formula_status_list = MazeFormula.status_list #RENAME THIS METHOD
      @formulas = MazeFormula.status_list_by_maze_type(@maze_type)
      erb :mazes_formulas_type
    else
      session[:error] = "Invalid maze type."
      redirect '/admin/mazes/formulas'
    end
  end

  post '/admin/mazes/formulas/:type' do
    # add type and id and status validation
    if %w(approved rejected).include?(params[:update_status_to])
      MazeFormula.update_status(params[:formula_id], params[:update_status_to])
      session[:success] = "The status for Maze Formula ID:#{params[:formula_id]} was updated to '#{params[:update_status_to]}'."
      redirect "/admin/mazes/formulas/#{params[:type]}"
    end
    
  end

  get '/admin/mazes/formulas/:type/:id' do
    # add :type validation
    @title = "Mazes - maze Craze Admin"
    @maze_types = Maze.types
    @formula_status_list = MazeFormula.status_list #RENAME THIS METHOD
    erb :mazes_formulas_id
  end
end
