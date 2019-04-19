ENV['SINATRA_ENV'] ||= "development"

require 'bundler/setup'
Bundler.require(:default, ENV['SINATRA_ENV'])

# model files must be required in a specific order
model_file_names = ["./app/models/rotate_maze.rb",
                    "./app/models/flip_maze.rb",
                    "./app/models/navigate_maze.rb",
                    "./app/models/solve_maze.rb",
                    "./app/models/board.rb",
                    "./app/models/maze.rb",
                    "./app/models/square.rb" ]

other_app_file_names = Dir.glob('./app/{helpers,controllers}/*.rb')

app_file_names = other_app_file_names + model_file_names

app_file_names.each { |file| require file }
