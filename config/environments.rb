ENV['SINATRA_ENV'] ||= "development"

require 'bundler/setup'
Bundler.require(:default, ENV['SINATRA_ENV'])

# model files must be required in a specific order
model_file_names = ["./app/models/database_connection.rb",
                    "./app/models/maze_rotate.rb",
                    "./app/models/maze_invert.rb",
                    "./app/models/maze_navigate.rb",
                    "./app/models/maze_solve.rb",
                    "./app/models/maze_formula.rb",
                    "./app/models/maze_permutation.rb",
                    "./app/models/maze.rb",
                    "./app/models/maze_square.rb" ]

other_app_file_names = Dir.glob('./app/{helpers,controllers}/*.rb')

app_file_names = other_app_file_names + model_file_names

app_file_names.each { |file| require file }
