require 'pry'

class AdminController < ApplicationController
  get '/admin' do
    @title = "Home - Maze Craze Admin"
    erb :admin
  end

  get '/admin/settings' do
    @title = "Settings - Maze Craze Admin"
    @min_max_threads = { min: MazeCraze::BackgroundThread::MIN_THREADS,
                         max: MazeCraze::BackgroundThread::MAX_THREADS }
    @number_of_threads = MazeCraze::BackgroundThread.number_of_threads
    @maze_formula_constraints = MazeCraze::MazeFormula.constraints
    erb :admin_settings
  end

  post '/admin/settings' do # refactor
    if params['number_of_threads']
      number_of_threads = params['number_of_threads'].to_i
      worker = MazeCraze::BackgroundWorker.instance
      queued_jobs = MazeCraze::BackgroundJob.all_jobs_of_status_type('queued')
      running_jobs = MazeCraze::BackgroundJob.all_jobs_of_status_type('running')

      MazeCraze::BackgroundThread.update_number_of_threads(number_of_threads)
      worker.stop
      worker.start if queued_jobs.any? || running_jobs.any?
      session[:success] = "The settings have been updated."
      redirect '/admin/settings'
    elsif params["formula_type"]
      formula_type = MazeCraze::MazeFormula.maze_formula_type_to_class(params['formula_type'])

      if formula_type.valid_constraints?(params)
        formula_type.update_constraints(params)
        session[:success] = "The #{params['formula_type'].capitalize} Maze settings have been updated."
        redirect '/admin/settings'
      else
        add_hash_to_session_hash(formula_type.constraint_validation(params))
        @title = "Settings - Maze Craze Admin"
        @min_max_threads = { min: MazeCraze::BackgroundThread::MIN_THREADS,
                             max: MazeCraze::BackgroundThread::MAX_THREADS }
        @number_of_threads = MazeCraze::BackgroundThread.number_of_threads
        @maze_formula_constraints = MazeCraze::MazeFormula.constraints
        session[:error] = "Please see the #{params['formula_type'].capitalize} Maze error message(s) and try again."
        erb :admin_settings
      end
    end
  end

  get '/admin/background-jobs' do
    @title = "Background Jobs - Maze Craze Admin"
    @job_statuses = MazeCraze::BackgroundJob::JOB_STATUSES
    @jobs = MazeCraze::BackgroundJob.all_jobs
    worker = MazeCraze::BackgroundWorker.instance

    if @background_workers_status = worker.alive? # this isn't a perfect indicator of whether or not the system alive or dead
      # worker = MazeCraze::BackgroundWorker.instance
      @number_of_threads = MazeCraze::BackgroundThread.number_of_threads
      @thread_stats = MazeCraze::BackgroundThread.thread_details(worker.id)
    end

    erb :background_jobs
  end

  post '/admin/background-jobs' do # refactor
    job_id = params['id']
    worker_id = params['background_worker_id']
    thread_id = params['background_thread_id']
    worker = MazeCraze::BackgroundWorker.instance

    if params['delete_job'] # refactor - use job status instead of work_id and thread_id values
      job = MazeCraze::BackgroundJob.job_from_id(job_id)

      # if job is queued
      if worker_id != '' && thread_id == ''
        worker.skip_job_in_queue(job_id)
        job.delete_from_db
        job.update_queue_order_because_of_deleted_job
      end

      # if job is running
      if thread_id != '' # this could be else
        background_thread = MazeCraze::BackgroundThread.thread_from_id(thread_id)
        MazeCraze::BackgroundThread.all.delete(background_thread).kill_thread
        job.undo
        job.delete_from_db
        worker.new_thread
      end
      session[:success] = "Job ID \##{job_id} was deleted."
    elsif params['cancel_job']
      worker.cancel_job(thread_id, job_id)
      session[:success] = "Job ID \##{job_id} was cancelled and re-queued."
    elsif params['start_worker']
      worker.start
    elsif params['stop_worker']
      worker.stop
    elsif params['restart_threads']
      worker.stop
      worker.start
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
    worker = MazeCraze::BackgroundWorker.instance
    worker.stop if worker.alive?
    erb :background_jobs_sort_queue
  end

  post '/admin/background-jobs/queued/sort' do
    MazeCraze::BackgroundWorker.instance.start
    redirect "/admin/background-jobs"
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
    elsif @formula.valid?(params) || @formula.experiment? && @formula.experiment_valid?
      @formula.save!
      session[:success] = "Your maze formula was saved."
      redirect "/admin/mazes/formulas/new"
    else
      add_hash_to_session_hash(@formula.validation(params))
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

    worker = MazeCraze::BackgroundWorker.instance

    if worker.dead?
      worker.start
    else
      worker.enqueue_job(MazeCraze::BackgroundJob.all.last)
      worker.start if worker.dead?
    end
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
