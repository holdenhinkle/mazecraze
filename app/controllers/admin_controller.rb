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
    if params['number_of_threads']
      number_of_threads = params['number_of_threads'].to_i
      queued_jobs = MazeCraze::BackgroundJob.all_jobs_of_status_type('queued')
      running_jobs = MazeCraze::BackgroundJob.all_jobs_of_status_type('running')

      MazeCraze::BackgroundWorker.update_number_of_threads(number_of_threads)
      MazeCraze::BackgroundWorker.stop # if MazeCraze::BackgroundWorker.alive?
      MazeCraze::BackgroundWorker.start if queued_jobs.any? || running_jobs.any?
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
        @min_max_threads = { min: MazeCraze::BackgroundWorker::MIN_THREADS,
                             max: MazeCraze::BackgroundWorker::MAX_THREADS }
        @number_of_threads = MazeCraze::BackgroundWorker.number_of_threads
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

    if @background_workers_status = MazeCraze::BackgroundWorker.alive?
      worker = MazeCraze::BackgroundWorker.worker
      @number_of_threads = MazeCraze::BackgroundWorker.number_of_threads
      @thread_stats = MazeCraze::BackgroundThread.thread_details(worker.id)
    end

    erb :background_jobs
  end

  post '/admin/background-jobs' do
    job_id = params['id']
    worker_id = params['background_worker_id']
    thread_id = params['background_thread_id']
    worker = MazeCraze::BackgroundWorker.worker

    if params['delete_job']
      job = MazeCraze::BackgroundJob.job_from_id(job_id)

      # if job is queued
      if worker_id != '' && thread_id == ''
        worker.skip_job_in_queue(job_id)
        job.delete_from_db
        job.update_queue_order_because_of_deleted_job
      end


      # if thread_id == ''
      #   job.update_queue_order_because_of_deleted_job
      # end

      # if job is running
      if thread_id != '' # this could be else
        binding.pry if MazeCraze::BackgroundThread.thread_from_id(thread_id).thread.nil?
        binding.pry if MazeCraze::BackgroundThread.thread_from_id(thread_id).nil?
        binding.pry if MazeCraze::BackgroundThread.thread_from_id(thread_id).is_a? Array

        # MazeCraze::BackgroundThread.thread_from_id(thread_id).kill_thread
        bg_thread_class = MazeCraze::BackgroundThread
        bg_thread_obj = bg_thread_class.thread_from_id(thread_id)
        worker = MazeCraze::BackgroundWorker.worker

        worker.threads.delete(bg_thread_class.all.delete(bg_thread_obj).kill_thread)
        job.undo
        job.delete_from_db

        # remove thread from threads array
        worker.new_thread
      end
      session[:success] = "Job ID \##{job_id} was deleted."
    elsif params['cancel_job']

      binding.pry if MazeCraze::BackgroundThread.all.count != MazeCraze::BackgroundWorker.worker.threads.count

      worker.cancel_job(thread_id, job_id)
      session[:success] = "Job ID \##{job_id} was cancelled and re-queued."
    elsif params['start_worker']
      MazeCraze::BackgroundWorker.start
    elsif params['stop_worker']
      MazeCraze::BackgroundWorker.stop
    elsif params['restart_threads']
      MazeCraze::BackgroundWorker.stop
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
    MazeCraze::BackgroundWorker.stop if MazeCraze::BackgroundWorker.alive?
    erb :background_jobs_sort_queue
  end

  post '/admin/background-jobs/queued/sort' do
    MazeCraze::BackgroundWorker.start
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

    worker = MazeCraze::BackgroundWorker.worker

    if worker.nil?
      MazeCraze::BackgroundWorker.new
    else
      worker.enqueue_job(MazeCraze::BackgroundJob.all.last)
      MazeCraze::BackgroundWorker.new if worker.dead?
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
