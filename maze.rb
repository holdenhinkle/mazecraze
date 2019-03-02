require 'pry'
require 'yaml'
require 'fileutils'
require 'json'
require 'date'

require_relative 'navigable'
require_relative 'solvable'

class Boards
  attr_reader :all_boards

  def initialize(boards)
    create_boards(boards)
  end

  private

  def create_boards(boards)
    boards.each { |board| Board.new(board) }
  end
end

class Board
  attr_reader :x, :y, :size, :num_starts, :num_barriers, :grids

  def initialize(board)
    @x = board[:x]
    @y = board[:y]
    @size = board[:x] * board[:y]
    @num_starts = board[:num_starts]
    @num_barriers = board[:num_barriers]
    @grids = create_grids(board)
  end

  private

  def create_grids(board)
    counter = starting_file_number(board[:level]) + 1
    permutations_file_path = create_permutations_file_path
    generate_permutations(layout, permutations_file_path)
    File.open(permutations_file_path, "r").each_line do |grid_layout|
      grid = SimpleGrid.new(board, JSON.parse(grid_layout))
      next unless grid.valid && grid.solutions.size == 1
      save_grid!(grid, counter)
      counter += 1
    end
  end

  def create_permutations_file_path
    permutations_directory = "/levels/grid_permutations/"
    file_name = "#{x}x _by_#{y}y_#{num_barriers}b_#{DateTime.now}.txt"
    File.join(data_path, permutations_directory, file_name)
  end

  def data_path
    File.expand_path("../data", __FILE__)
  end

  def starting_file_number(level)
    largest_number = 0
    Dir[File.join(data_path, "/levels/level_#{level}/*")].each do |f|
      number = f.match(/\d+.yml/).to_s.match(/\d+/).to_s.to_i
      largest_number = number if number > largest_number
    end
    largest_number
  end

  def each_permutation(layout)
    layout.permutation { |permutation| yield(permutation) }
  end

  def generate_permutations(layout, permutations_file_path)
    FileUtils.mkdir_p(File.dirname(permutations_file_path)) unless
      File.directory?(File.dirname(permutations_file_path))
    File.new(permutations_file_path, "w") unless
      File.exist?(permutations_file_path)

    each_permutation(layout) do |permutation|
      next if grid_layout_not_unique?(permutations_file_path, permutation)
      File.open(permutations_file_path, "a") do |f|
        f.write(permutation)
        f.write("\n")
      end
    end
  end

  def grid_layout_not_unique?(file_path, permutation)
    File.foreach(file_path).any? do |line|
      line.include?(permutation.to_s)
    end
  end

  def layout
    grid = []
    size.times do
      grid << if count_makers(grid, 's') != num_starts
                format_marker(grid, 's')
              elsif count_makers(grid, 'f') != num_starts
                format_marker(grid, 'f')
              elsif grid.count('b') != num_barriers
                'b'
              else
                'n'
              end
    end
    grid
  end

  # def grid_type()

  # end

  def save_grid!(grid, index)
    directory = "/levels/level_#{grid.level}"
    directory_path = File.join(data_path, directory)
    FileUtils.mkdir_p(directory_path) unless File.directory?(directory_path)
    File.open(File.join(directory_path, "#{index}.yml"), "w") do |file|
      file.write(grid.to_yaml)
    end
  end

  def count_makers(grid, marker)
    grid.count { |square| square.match(Regexp.new(Regexp.escape(marker))) }
  end

  def format_marker(grid, type)
    s_counter = 0
    grid.each do |marker| 
      s_counter += 1 if marker.match(Regexp.new(Regexp.escape(type)))
    end
    "#{type}#{s_counter + 1}"
  end
end

class Grid
  include Navigable
  include Solvable

  attr_reader :type, :level, :x, :y, :squares, :valid, :solutions

  def initialize(board, grid_layout)
    @type = board[:type]
    @level = board[:level]
    @x = board[:x]
    @y = board[:y]
    @squares = create_grid(grid_layout)
    @valid = valid_grid?
    @solutions = []
    solve([{ path: [start_square_index], grid: self }]) if @valid
  end

  def all_squares_taken?
    squares.all?(&:taken?)
  end

  private

  def create_grid(grid)
    grid.map do |square|
      if square.match(/s/)
        Square.new("start_#{square.match(/\d/)}".to_sym, :taken)
      elsif square.match(/f/)
        Square.new("finish_#{square.match(/\d/)}".to_sym, :not_taken)
      elsif square == 'b'
        Square.new(:barrier, :taken)
      elsif square == 'n'
        Square.new(:normal, :not_taken)
      end
    end
  end

  def size
    squares.count
  end
end

class SimpleGrid < Grid
  def valid_grid?
    valid_finish_squares?
  end

  def valid_finish_squares?
    all_squares_of_type('f').all? { |_, index| valid_finish_square?(index) }
  end

  private

  def valid_finish_square?(square)
    return false if connected_to_start_square?(square)
    return false if connected_to_more_than_one_normal_square?(square)
    true
  end
end

class WarpableGrid < Grid
end

class BridgableGrid < Grid
end

class Square
  attr_reader :type
  attr_accessor :status

  def initialize(type, status)
    @status = status
    @type = type
  end

  def taken?
    return true if status == :taken
    false
  end

  def not_taken?
    !taken?
  end

  def taken!
    self.status = :taken
  end

  def start_square?
    return true if type.match(/start/)
    false
  end

  def finish_square?
    return true if type.match(/finish/)
    false
  end

  def normal_square?
    type == :normal
  end
end

boards = [{ type: :simple_line, x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 }]

# boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 2, level: 1 }]

# boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 2, level: 1 },
#           { x: 4, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 4, y: 3, num_starts: 1, num_barriers: 2, level: 1 }]

Boards.new(boards)
