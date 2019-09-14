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
    @maze_formula_constraints = MazeCraze::Formula.constraints
    erb :admin_settings
  end

  post '/admin/settings' do # refactor
    if params['number_of_threads']
      worker = MazeCraze::BackgroundWorker.instance
      worker.stop
      MazeCraze::BackgroundThread.update_number_of_threads(params['number_of_threads'].to_i)
      queued_jobs = MazeCraze::BackgroundJob.jobs_of_status_type('queued')
      worker.start if queued_jobs.any?
      session[:success] = "The settings have been updated."
      redirect '/admin/settings'
    elsif params["formula_type"]
      formula_type = MazeCraze::Formula.formula_type_to_class(params['formula_type'])

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
        @maze_formula_constraints = MazeCraze::Formula.constraints
        session[:error] = "Please see the #{params['formula_type'].capitalize} Maze error message(s) and try again."
        erb :admin_settings
      end
    end
  end

  get '/admin/background-jobs' do
    @title = "Background Jobs - Maze Craze Admin"
    @job_statuses = MazeCraze::BackgroundJob::JOB_STATUSES
    @jobs = MazeCraze::BackgroundJob.all_jobs

    until @jobs['running'].all? { |job, _| job['start_time'] }
      @jobs = MazeCraze::BackgroundJob.all_jobs
    end

    binding.pry if @jobs['running'].any? { |job, _| job['start_time'].nil? }

    worker = MazeCraze::BackgroundWorker.instance

    if @background_workers_status = worker.alive? # this isn't a perfect indicator of whether or not the system alive or dead
      @number_of_threads = MazeCraze::BackgroundThread.number_of_threads
      @thread_stats = MazeCraze::BackgroundThread.thread_details(worker.id)
    end

    erb :background_jobs
  end

  post '/admin/background-jobs' do
    if params['delete_job'] || params['cancel_job']
      job = MazeCraze::BackgroundJob.job_from_id(params['job_id'])
    elsif params['start'] || params['stop'] || params['restart']
      worker = MazeCraze::BackgroundWorker.instance
    end

    if params['delete_job']
      job.delete(params['job_status'])
      session[:success] = "Job ID \##{job.id} was deleted."
    elsif params['cancel_job']
      job.cancel
      session[:success] = "Job ID \##{job.id} was cancelled and re-queued."
    elsif params['start']
      worker.start
    elsif params['stop']
      worker.stop
    elsif params['restart']
      worker.restart
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
    @jobs = MazeCraze::BackgroundJob.jobs_of_status_type(status)
    erb :background_jobs_status
  end

  get '/admin/background-jobs/queued/sort' do
    worker = MazeCraze::BackgroundWorker.instance
    worker.stop if worker.alive?
    @queued_jobs = MazeCraze::BackgroundJob.jobs_of_status_type('queued', 'queue_order', 'ASC')
    erb :background_jobs_sort_queue
  end

  post '/admin/background-jobs/queued/sort' do
    MazeCraze::BackgroundJob.manually_sort_order(params['updated_queue_orders'])
    # add validation:
      # error:
        # only numbers
      # success:
        # success message
    redirect "/admin/background-jobs/queued/sort"
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
    @formula_statuses = MazeCraze::Formula::FORMULA_STATUSES
    @maze_status_counts = {}

    @maze_types.each do |type|
      status_counts_by_maze_type = {}
      @formula_statuses.each do |status|
        status_counts_by_maze_type[status] = MazeCraze::Formula.count_by_type_and_status(type, status)
      end
      @maze_status_counts[type] = status_counts_by_maze_type
    end

    erb :mazes_formulas
  end

  post '/admin/mazes/formulas' do
    redirect "/admin/mazes/formulas" unless params['generate_formulas']

    job_type = 'generate_formulas'
    job_params = []

    if MazeCraze::BackgroundJob.duplicate_job?(job_type, job_params)
      session[:error] = duplicate_job_error_message(job_type, job_params)
    else
      MazeCraze::BackgroundJob.new_background_job(job_type, job_params)
      session[:success] = "The task 'Generate Maze Formulas' was sent to the queue. You will be notified when it's complete."
    end

    redirect "/admin/mazes/formulas"
  end

  get '/admin/mazes/formulas/new' do
    @title = "New Maze Formula - Maze Craze Admin"
    @maze_types = MazeCraze::Maze::MAZE_TYPE_CLASS_NAMES.keys
    @popovers = MazeCraze::Formula.form_popovers
    erb :mazes_formulas_new
  end

  post '/admin/mazes/formulas/new' do
    @formula = MazeCraze::Formula.formula_type_to_class(params[:maze_type]).new(params)

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
    @popovers = MazeCraze::Formula.form_popovers
    erb :mazes_formulas_new
  end

  get '/admin/mazes/formulas/:type' do
    if MazeCraze::Maze::MAZE_TYPE_CLASS_NAMES.keys.include?(params[:type])
      @title = "#{params[:type]} Maze Formulas - Maze Craze Admin"
      @formula_statuses = MazeCraze::Formula::FORMULA_STATUSES
      @formulas = MazeCraze::Formula.status_list_by_maze_type(params[:type])
      erb :mazes_formulas_type
    else
      session[:error] = "Invalid maze type."
      redirect '/admin/mazes/formulas'
    end
  end

  def duplicate_job_error_message(job, params)
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

  post '/admin/mazes/formulas/:type' do # refactor
    if params['job_type'] == 'generate_permutations'
      error_intro = "Jobs for the following formulas were already created: "
      duplicate_job_errors = []
      queued_job_ids = []
      params['formula_ids'].each do |id|
        job_params = { 'formula_id' => id  }
        if MazeCraze::BackgroundJob.duplicate_job?(params['job_type'], job_params)
          duplicate_job = MazeCraze::BackgroundJob.duplicate_jobs(params['job_type'], job_params).first
          duplicate_job_errors << "ID \##{id} (Job ID \##{duplicate_job['id']} (Status: #{duplicate_job['status'].capitalize})"
        else
          MazeCraze::Formula.update_status(id, 'queued')
          MazeCraze::BackgroundJob.new_background_job(params['job_type'], job_params)
          queued_job_ids.push(id)
        end
      end
      session[:success] = "Jobs for the following formulas were created and queued: #{queued_job_ids.join(', ')}." if queued_job_ids.any?
      session[:error] = error_intro + duplicate_job_errors.join(', ') if !duplicate_job_errors.empty?

    elsif params['job_type'] == 'generate_formulas'
      job_params = { 'maze_type' => params['type'] }

      if MazeCraze::BackgroundJob.duplicate_job?(params['job_type'], job_params)
        session[:error] = duplicate_job_error_message(params['job_type'], job_params)
      else
        MazeCraze::BackgroundJob.new_background_job(params['job_type'], job_params)
        session[:success] = "The job 'Generate #{params['type'].capitalize} Maze Formulas' was created and queued."
      end
    end

    redirect "/admin/mazes/formulas/#{params['type']}"
  end

  get '/admin/mazes/formulas/:type/:id' do
    # add :type validation
    @title = "Mazes - maze Craze Admin"
    @maze_types = MazeCraze::Maze::MAZE_TYPE_CLASS_NAMES.keys
    @formula_statuses = MazeCraze::Formula::FORMULA_STATUSES
    erb :mazes_formulas_id
  end
end
