require 'pry'

class AdminController < ApplicationController
  get '/admin' do
    @title = "Home - Maze Craze Admin"
    erb :admin
  end

  get '/admin/settings' do
    @title = "Settings - Maze Craze Admin"
    @min_max_threads = { min: BackgroundWorker::MIN_THREADS,
                         max: BackgroundWorker::MAX_THREADS }
    @number_of_threads = BackgroundWorker.number_of_threads
    erb :admin_settings
  end

  post '/admin/settings' do
    if params['number_of_threads']
      BackgroundWorker.update_number_of_threads(params['number_of_threads'])
      session[:success] = "The settings have been updated."
    end
    redirect '/admin/settings'
  end

  get '/admin/background-jobs' do
    @title = "Background Jobs - Maze Craze Admin"
    @job_statuses = BackgroundJob::JOB_STATUSES
    @jobs = BackgroundJob.all_jobs
    erb :background_jobs
  end

  post '/admin/background-jobs' do
    # REDO THIS OBJECT_ID STUFF
    object_id = BackgroundWorker.object_id_from_db_id(params[:worker_id])[0]['object_id']
    worker = BackgroundWorker.worker_from_object_id(object_id)[0]
    if params['delete']
      worker.delete_job(params[:job_id])
    elsif params['cancel']
    # worker.kill_job(params[:thread_object_id])
    # update job status
    elsif params['queue']
    end
    redirect "/admin/background-jobs"
  end

  get '/admin/background-jobs/:status' do
    status = params[:status]
    if BackgroundJob::JOB_STATUSES.none?(status)
      session[:error] = "The page you requested doesn't exist."
      redirect '/admin'
    end
    @title = "#{status.capitalize} Background Jobs - Maze Craze Admin"
    @jobs = BackgroundJob.all_jobs_of_status_type(status)
    erb :background_jobs_status
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
    if params['generate_formulas']
      # check if request is already in the queue
      BackgroundJob.new({ type: 'generate_maze_formulas', params: [] }).save!
      session[:success] = "The task 'Generate Maze Formulas' was sent to the queue. You will be notified when it's complete."
      if (worker = BackgroundWorker.active_worker).nil?
        BackgroundWorker.new
      else
        worker.enqueue_job(BackgroundJob.last_job_added.first)
        BackgroundWorker.new unless worker.still_active?
      end
      redirect "/admin/mazes/formulas"
    end
    session[:error] = "The page you requested doesn't exist."
    redirect '/admin'
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
      # check if request is already in the queue
      BackgroundJob.new({ type: 'generate_maze_formulas', params: { 'maze_type' => params['maze_type'] } }).save!
      session[:success] = "The task 'Generate Maze Formulas' was sent to the queue. You will be notified when it's complete."
      if (worker = BackgroundWorker.active_worker).nil?
        BackgroundWorker.new
      else
        worker.enqueue_job(BackgroundJob.last_job_added.first)
        BackgroundWorker.new unless worker.still_active?
      end
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
