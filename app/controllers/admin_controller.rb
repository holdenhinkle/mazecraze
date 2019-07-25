require 'pry'

class AdminController < ApplicationController
  get '/admin' do
    @title = "Home - Maze Craze Admin"
    erb :admin
  end

  get '/admin/settings' do
    @title = "Settings - Maze Craze Admin"
    @min_max_threads = { min: MazeCraze::BackgroundWorker::MIN_THREADS,
                         max: MazeCraze::BackgroundWorker::MAX_THREADS }
    @number_of_threads = MazeCraze::BackgroundWorker.number_of_threads
    @maze_formula_constraints = MazeCraze::MazeFormula.constraints
    erb :admin_settings
  end

  post '/admin/settings' do
    # ** REFACTOR
    if params['number_of_threads']
      MazeCraze::BackgroundWorker.update_number_of_threads(params['number_of_threads'].to_i)
      session[:success] = "The settings have been updated."
      MazeCraze::BackgroundWorker.stop
      MazeCraze::BackgroundWorker.start
      redirect '/admin/settings'
    elsif params["formula_type"]
      formula_type = MazeCraze::MazeFormula.maze_formula_type_to_class(params['formula_type'])
      if formula_type.valid_constraints?(params)
        # formula_type.update_constraints(params)
        session[:success] = "The #{params['formula_type'].capitalize} Maze settings have been updated."
        redirect '/admin/settings'
      else
        session[:error] = "Please see the #{params['formula_type'].capitalize} Maze error message(s) and try again."
        add_hashes_to_session_hash(formula_type.constraint_validation(params))
        # refactor this
        @title = "Settings - Maze Craze Admin"
        @min_max_threads = { min: MazeCraze::BackgroundWorker::MIN_THREADS,
                             max: MazeCraze::BackgroundWorker::MAX_THREADS }
        @number_of_threads = MazeCraze::BackgroundWorker.number_of_threads
        @maze_formula_constraints = MazeCraze::MazeFormula.constraints
        erb :admin_settings
      end
    end
  end






  get '/admin/background-jobs' do
    @title = "Background Jobs - Maze Craze Admin"
    @job_statuses = MazeCraze::BackgroundJob::JOB_STATUSES
    @jobs = MazeCraze::BackgroundJob.all_jobs
    if @background_workers_status = MazeCraze::BackgroundWorker.active_workers.any?
      @workers = MazeCraze::BackgroundWorker.active_workers
      @worker = @workers.first
      @number_of_threads = MazeCraze::BackgroundWorker.number_of_threads
      @thread_stats = MazeCraze::BackgroundThread.status_of_workers_threads(@worker.id)
    end
    erb :background_jobs
  end





  post '/admin/background-jobs' do
    job_id = params['id']
    worker_id = params['background_worker_id']
    thread_id = params['background_thread_id']
    worker = MazeCraze::BackgroundWorker.worker_from_id(worker_id)

    if params['delete_job']
      if worker_id != ''
        worker.delete_job(job_id) # skip job in queue - rename
      end
      if thread_id != ''
        MazeCraze::BackgroundThread.background_thread_from_id(thread_id).kill_thread
        worker.new_thread
      end
      MazeCraze::BackgroundJob.job_from_id(job_id).delete
      session[:success] = "Job ID \##{job_id} was deleted."
    elsif params['cancel_job']
      worker.kill_specific_job(thread_id, job_id)
      session[:success] = "Job ID \##{job_id} was cancelled and re-queued."
    elsif params['start_worker']
      MazeCraze::BackgroundWorker.new
    elsif params['stop_worker']
      MazeCraze::BackgroundWorker.stop
    elsif params['restart_threads']
      MazeCraze::BackgroundWorker.start
    end

    redirect "/admin/background-jobs"
  end

  get '/admin/background-jobs/:status' do
    status = params[:status]
    if MazeCraze::BackgroundJob::JOB_STATUSES.none?(status)
      session[:error] = "The page you requested doesn't exist."
      redirect '/admin'
    end

    @title = "#{status.capitalize} Background Jobs - Maze Craze Admin"
    @jobs = MazeCraze::BackgroundJob.all_jobs_of_status_type(status)
    erb :background_jobs_status
  end

  get '/admin/background-jobs/queued/sort' do
    erb :background_jobs_sort_queue
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
    @maze_types = MazeCraze::Maze::MAZE_TYPE_CLASS_NAMES.keys
    @formula_status_list = MazeCraze::MazeFormula.status_list #RENAME THIS METHOD
    @maze_status_counts = {}

    @maze_types.each do |type|
      status_counts_by_maze_type = {}
      @formula_status_list.each do |status|
        status_counts_by_maze_type[status] = MazeCraze::MazeFormula.count_by_type_and_status(type, status)
      end
      @maze_status_counts[type] = status_counts_by_maze_type
    end

    erb :mazes_formulas
  end

  post '/admin/mazes/formulas' do
    redirect "/admin/mazes/formulas" unless params['generate_formulas']

    job_type = 'generate_maze_formulas'
    job_params = []

    if MazeCraze::BackgroundJob.duplicate_job?(job_type, job_params)
      session[:error] = duplicate_jobs_error_message(job_type, job_params)
    else
      new_background_job(job_type, job_params)
      session[:success] = "The task 'Generate Maze Formulas' was sent to the queue. You will be notified when it's complete."
    end

    redirect "/admin/mazes/formulas"
  end

  get '/admin/mazes/formulas/new' do
    @title = "New Maze Formula - Maze Craze Admin"
    @maze_types = MazeCraze::Maze::MAZE_TYPE_CLASS_NAMES.keys
    @popovers = MazeCraze::MazeFormula.form_popovers
    erb :mazes_formulas_new
  end

  post '/admin/mazes/formulas/new' do
    @formula = MazeCraze::MazeFormula.maze_formula_type_to_class(params[:maze_type]).new(params)

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

    @maze_types = MazeCraze::Maze::MAZE_TYPE_CLASS_NAMES.keys
    @popovers = MazeCraze::MazeFormula.form_popovers
    erb :mazes_formulas_new
  end

  get '/admin/mazes/formulas/:type' do
    @maze_type = params[:type]

    if MazeCraze::Maze::MAZE_TYPE_CLASS_NAMES.keys.include?(@maze_type)
      @title = "#{@maze_type} Maze Formulas - Maze Craze Admin"
      @formula_status_list = MazeCraze::MazeFormula.status_list #RENAME THIS METHOD
      @formulas = MazeCraze::MazeFormula.status_list_by_maze_type(@maze_type)
      erb :mazes_formulas_type
    else
      session[:error] = "Invalid maze type."
      redirect '/admin/mazes/formulas'
    end
  end

  def new_background_job(job_type, job_params)
    MazeCraze::BackgroundJob.new({ type: job_type, params: job_params })

    workers = MazeCraze::BackgroundWorker.active_workers

    if workers.none?
      MazeCraze::BackgroundWorker.new
    else
      worker = workers[0]
      worker.enqueue_job(MazeCraze::BackgroundJob.all.last)
      MazeCraze::BackgroundWorker.new if worker.dead?
    end

    # if (worker = MazeCraze::BackgroundWorker.active_worker).nil? # I DON'T LIKE THIS!
    #   MazeCraze::BackgroundWorker.new
    # else
    #   worker.enqueue_job(MazeCraze::BackgroundJob.all.last)
    #   MazeCraze::BackgroundWorker.new if worker.dead?
    # end
  end

  def duplicate_jobs_error_message(job, params)
    duplicate_jobs = MazeCraze::BackgroundJob.duplicate_jobs(job, params)

    message = if duplicate_jobs.values.length > 1
                "#{duplicate_jobs.values.length} duplicate jobs exist: "
              else
                "1 duplicate job exists: "
              end

    jobs = []

    duplicate_jobs.each do |duplicate_job|
      jobs << "Job ID \##{duplicate_job['id']} (Status: #{duplicate_job['status'].capitalize})"
    end

    message << jobs.join(', ') + '.'
  end

  post '/admin/mazes/formulas/:type' do
    if params[:update_status_to] == 'approved'
      formula_values = MazeCraze::MazeFormula.retrieve_formula_values(params[:formula_id])
      @formula = MazeCraze::MazeFormula.maze_formula_type_to_class(formula_values['maze_type']).new(formula_values)
      @formula.generate_permutations(params[:formula_id])
      @formula.generate_candidates(params[:formula_id])
      MazeCraze::MazeFormula.update_status(params[:formula_id], params[:update_status_to]) # change to instance method
      session[:success] = "The status for Maze Formula ID:#{params[:formula_id]} was updated to '#{params[:update_status_to]}'."
    elsif params['generate_formulas']
      job_type = 'generate_maze_formulas'
      job_params = { 'maze_type' => params['maze_type'] }
      if MazeCraze::BackgroundJob.duplicate_job?(job_type, job_params)
        session[:error] = duplicate_jobs_error_message(job_type, job_params)
      else
        new_background_job(job_type, job_params)
        session[:success] = "The task 'Generate #{params['maze_type'].capitalize} Maze Formulas' was sent to the queue. You will be notified when it's complete."
      end
    end
    redirect "/admin/mazes/formulas/#{params['maze_type']}"
  end

  get '/admin/mazes/formulas/:type/:id' do
    # add :type validation
    @title = "Mazes - maze Craze Admin"
    @maze_types = MazeCraze::Maze::MAZE_TYPE_CLASS_NAMES.keys
    @formula_status_list = MazeCraze::MazeFormula.status_list #RENAME THIS METHOD
    erb :mazes_formulas_id
  end
end
