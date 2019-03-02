require 'pry'
require 'yaml'
require 'fileutils'
require 'json'

require_relative 'navigable'
require_relative 'solvable'

class Boards
  attr_reader :all_boards

  def initialize(boards)
    @all_boards = {}
    create_boards(boards)
  end

  private

  def create_boards(boards)
    boards.each do |board|
      @all_boards["board_#{board[:x]}x#{board[:y]}".to_sym] = Board.new(board)
    end
  end
end

class Board
  attr_reader :size, :num_starts, :num_barriers, :grids

  def initialize(board)
    @size = board[:x] * board[:y]
    @num_starts = board[:num_starts]
    @num_barriers = board[:num_barriers]
    @grids = create_grids(board)
  end

  private

  def create_grids(board)
    counter = starting_file_number(board[:level]) + 1
    file_path = permutations(layout)
    File.open(file_path, "r").each_line do |grid_layout|
      grid = Grid.new(board, JSON.parse(grid_layout))
      next unless grid.valid?
      save_grid!(grid, counter)
      counter += 1
    end
    FileUtils.rm(file_path)
  end

  def starting_file_number(level)
    largest_number = 0
    Dir[File.join(data_path, "/levels/level_#{level}/*")].each do |f|
      number = f.match(/\d+.yml/).to_s.match(/\d+/).to_s.to_i
      largest_number = number if number > largest_number
    end
    largest_number
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

  def each_permutation(layout)
    layout.permutation { |permutation| yield(permutation) }
  end

  def permutations(layout)
    file_path = File.join(data_path, "/levels/grid_scratch_file.txt")
    FileUtils.mkdir_p(File.dirname(file_path)) unless File.directory?(File.dirname(file_path))
    File.new(file_path, "w") unless File.exist?(file_path)

    each_permutation(layout) do |permutation|
      next if grid_layout_exists?(file_path, permutation)
      File.open(file_path, "a") do |f|
        f.write(permutation)
        f.write("\n")
      end
    end
    file_path
  end

  def grid_layout_exists?(file_path, permutation)
    File.foreach(file_path).any? do |line|
      line.include?(permutation.to_s)
    end
  end

  def count_makers(grid, marker)
    grid.count { |square| square.match(Regexp.new(Regexp.escape(marker))) }
  end

  def format_marker(grid, type)
    s_counter = 0
    grid.each { |marker| s_counter += 1 if marker.match(Regexp.new(Regexp.escape(type))) }
    "#{type}#{s_counter + 1}"
  end

  def save_grid!(grid, index)
    directory = "/levels/level_#{grid.level}"
    directory_path = File.join(data_path, directory)
    FileUtils.mkdir_p(directory_path) unless File.directory?(directory_path)
    File.open(File.join(directory_path, "#{index}.yml"), "w") do |file|
      file.write(grid.to_yaml)
    end
  end

  def data_path
    File.expand_path("../data", __FILE__)
  end
end

class Grid
  include Navigable
  include Solvable

  attr_reader :squares, :x, :y, :solutions, :level

  def initialize(board, grid)
    @squares = create_grid(grid)
    @x = board[:x]
    @y = board[:y]
    @level = board[:level]
    @solutions = []
    solve({ path: [start_square_index], grid: self })
  end

  def valid?
    valid_finish_squares? && one_solution?
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

  def valid_finish_squares?
    all_squares_of_type('f').all? { |_, index| valid_finish_square?(index) }
  end

  #  ** TEST THIS!
  def valid_finish_square?(square)
    return false if connected_to_start_square?(square)
    return false if connected_to_more_than_one_normal_square?(square)
    true
  end

#  ** TEST THIS!
  def connected_to_start_square?(square)
    surrounding_squares(square).any? { |sq| squares[sq].start_square? }
  end

  #  ** TEST THIS!
  def connected_to_more_than_one_normal_square?(square)
    connections = 0
    connections += 1 if normal_not_taken_square_above?(square)
    connections += 1 if normal_not_taken_square_right?(square)
    connections += 1 if normal_not_taken_square_below?(square)
    connections += 1 if normal_not_taken_square_left?(square)
    connections > 1
  end

  #  ** TEST THIS!
  def surrounding_squares(square)
    results = []
    results << square_index_above(square) if square_above?(square)
    results << square_index_right(square) if square_right?(square)
    results << square_index_below(square) if square_below?(square)
    results << square_index_left(square) if square_left?(square)
    results
  end
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
    return true if type.match(/s/)
    false
  end

  def finish_square?
    return true if type.match(/f/)
    false
  end

  def normal_square?
    type == :normal
  end
end

boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 }]

# boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 2, level: 1 }]

# boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 2, level: 1 },
#           { x: 4, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 4, y: 3, num_starts: 1, num_barriers: 2, level: 1 }]

Boards.new(boards)
