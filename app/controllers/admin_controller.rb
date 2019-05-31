require 'pry'

class AdminController < ApplicationController
  get '/admin' do
    @title = "Home - Maze Craze Admin"
    erb :admin
  end

  get '/admin/background-jobs' do
    @title = "Background Jobs - Maze Craze Admin"
    erb :background_jobs
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
    @maze_types = Maze::MAZE_TYPE_CLASS_NAMES.keys
    @formula_status_list = MazeFormula.status_list #RENAME THIS METHOD
    @maze_status_counts = {}
    @maze_types.each do |type|
      status_counts_by_maze_type = {}
      @formula_status_list.each do |status|
        status_counts_by_maze_type[status] = MazeFormula.count_by_type_and_status(type, status)
      end
      @maze_status_counts[type] = status_counts_by_maze_type
    end
    erb :mazes_formulas
  end

  post '/admin/mazes/formulas' do
    generated_formula_stats = MazeFormula.generate_formulas if params['generate_formulas']
    new_message = "#{generated_formula_stats[:new]} new maze formulas were created."
    existed_message = "#{generated_formula_stats[:existed]} formulas already existed."
    session[:success] = new_message + ' ' + existed_message
    redirect "/admin/mazes/formulas"
  end

  get '/admin/mazes/formulas/new' do
    @title = "New Maze Formula - Maze Craze Admin"
    @maze_types = Maze::MAZE_TYPE_CLASS_NAMES.keys
    @popovers = MazeFormula.form_popovers
    erb :mazes_formulas_new
  end

  post '/admin/mazes/formulas/new' do
    @formula = MazeFormula.maze_formula_type_to_class(params[:maze_type]).new(params)
    if @formula.exists?
      session[:error] = "That maze formula already exists."
    elsif @formula.experiment? && @formula.experiment_valid? || @formula.valid?
      @formula.save!
      session[:success] = "Your maze formula was saved."
      redirect "/admin/mazes/formulas/new"
    else
      add_hashes_to_session_hash(@formula.validation)
      session[:error] = "That maze formula is invalid."
    end
    @maze_types = Maze::MAZE_TYPE_CLASS_NAMES.keys
    @popovers = MazeFormula.form_popovers
    erb :mazes_formulas_new
  end

  get '/admin/mazes/formulas/:type' do
    @maze_type = params[:type]
    if Maze::MAZE_TYPE_CLASS_NAMES.keys.include?(@maze_type)
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
    if params[:update_status_to] == 'approved'
      formula_values = MazeFormula.retrieve_formula_values(params[:formula_id])
      @formula = MazeFormula.maze_formula_type_to_class(formula_values['maze_type']).new(formula_values)
      @formula.generate_permutations(params[:formula_id])
      @formula.generate_candidates(params[:formula_id])
      MazeFormula.update_status(params[:formula_id], params[:update_status_to]) # change to instance method
      session[:success] = "The status for Maze Formula ID:#{params[:formula_id]} was updated to '#{params[:update_status_to]}'."
    elsif params['generate_formulas']
      maze_formula_class = MazeFormula.maze_formula_type_to_class(params['maze_type'])
      generated_formula_stats = MazeFormula.generate_formulas([maze_formula_class])
      new_message = "#{generated_formula_stats[:new]} new #{params['maze_type'].upcase} maze formulas were created."
      existed_message = "#{generated_formula_stats[:existed]} #{params['maze_type'].upcase} maze formulas already existed."
      session[:success] = new_message + ' ' + existed_message
    end
    redirect "/admin/mazes/formulas/#{params['maze_type']}"
  end

  get '/admin/mazes/formulas/:type/:id' do
    # add :type validation
    @title = "Mazes - maze Craze Admin"
    @maze_types = Maze::MAZE_TYPE_CLASS_NAMES.keys
    @formula_status_list = MazeFormula.status_list #RENAME THIS METHOD
    erb :mazes_formulas_id
  end
end
