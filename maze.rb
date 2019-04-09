require 'pry'
require 'yaml'
require 'fileutils'
require 'json'
require 'date'

require_relative 'navigate'
require_relative 'solve'

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
  attr_reader :mazes, :x, :y, :size,
              :num_endpoints, :num_barriers, :num_bridges,
              :num_portals, :num_tunnels

  def initialize(board)
    @x = board[:x]
    @y = board[:y]
    @size = board[:x] * board[:y]
    @num_endpoints = board[:endpoints]
    @num_barriers = board[:barriers] ? board[:barriers] : 0
    @num_bridges = board[:bridges] ? board[:bridges] : 0
    @num_portals = board[:portals] ? board[:portals] : 0
    @num_tunnels = board[:tunnels] ? board[:tunnels] : 0
    @mazes = create_mazes(board)
  end

  private

  def create_mazes(board)
    counter = starting_file_number(board[:level]) + 1
    permutations_file_path = create_permutations_file_path
    generate_permutations(layout, permutations_file_path)
    File.open(permutations_file_path, "r").each_line do |maze_layout|
      maze = Object.const_get(maze_type(board[:type])).new(board, JSON.parse(maze_layout))
      next unless maze.valid?
      save_maze!(maze, counter)
      counter += 1
    end
  end

  # * *
  # FOR testing
  # *

  # ONE LINE BRIDGE
  # def create_mazes(board)
  #   new_maze = ["endpoint_1_b", "barrier", "normal", "normal",
  #               "normal", "normal", "bridge", "normal",
  #               "normal", "normal", "normal", "endpoint_1_a",
  #               "normal", "normal", "normal", "normal"]

  #   maze = BridgeMaze.new(board, new_maze)
  #   binding.pry
  # end

  # ONE LINE TUNNEL
  # def create_mazes(board)
  #   counter = starting_file_number(board[:level]) + 1
  #   permutations_file_path = "/Users/hamedahinkle/Documents/LaunchSchool/17x_projects/maze/data/do_not_delete/maze_permutations/tunnel_3x3.txt"
  #   File.open(permutations_file_path, "r").each_line do |maze_layout|
  #     maze = Object.const_get(maze_type(board[:type])).new(board, JSON.parse(maze_layout))
  #     next unless maze.valid?
  #     save_maze!(maze, counter)
  #     counter += 1
  #   end
  # end

  # ONE LINE PORTAL
  # def create_mazes(board)
  #   new_maze = ["endpoint_1_a", "portal_1_a", "normal", "normal",
  #               "normal", "normal", "normal", "normal",
  #               "normal", "normal", "normal", "barrier",
  #               "normal", "portal_1_b", "normal", "endpoint_1_b"]

  #   maze = PortalMaze.new(board, new_maze)
  #   binding.pry
  # end

  def create_permutations_file_path
    permutations_directory = "/levels/maze_permutations/"
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
      next if maze_layout_exists?(permutations_file_path, permutation)
      File.open(permutations_file_path, "a") do |f|
        f.write(permutation)
        f.write("\n")
      end
    end
  end

  def maze_layout_exists?(file_path, permutation)
    File.foreach(file_path).any? do |line|
      line.include?(permutation.to_s)
    end
  end

  def layout
    maze = []
    size.times do
      maze << if (count_pairs(maze, 'endpoint') / 2) != num_endpoints
                format_pair(maze, 'endpoint')
              elsif (count_pairs(maze, 'portal') / 2) != num_portals
                format_pair(maze, 'portal')
              elsif (count_pairs(maze, 'tunnel') / 2) != num_tunnels
                format_pair(maze, 'tunnel')
              elsif maze.count('bridge') != num_bridges
                'bridge'
              elsif maze.count('barrier') != num_barriers
                'barrier'
              else
                'normal'
              end
    end
    maze
  end

  def maze_type(type)
    case type
    when :simple then 'Maze'
    when :portal then "PortalMaze" # DO THIS
    when :tunnel then "TunnelMaze" # DO THIS
    when :bridge then "BridgeMaze"
    end
  end

  def save_maze!(maze, index)
    directory = "/levels/level_#{maze.level}"
    directory_path = File.join(data_path, directory)
    FileUtils.mkdir_p(directory_path) unless File.directory?(directory_path)
    File.open(File.join(directory_path, "#{index}.yml"), "w") do |file|
      file.write(maze.to_yaml)
    end
  end

  def count_pairs(maze, type)
    maze.count { |square| square.match(Regexp.new(Regexp.escape(type))) }
  end

  def format_pair(maze, type)
    count = count_pairs(maze, type)
    group = count / 2 + 1
    subgroup = count.even? ? 'a' : 'b'
    "#{type}_#{group}_#{subgroup}"
  end
end

class Maze
  include Navigate
  include Solve

  attr_reader :type, :level, :x, :y, :squares, :valid, :solutions

  def initialize(board, maze_layout)
    @type = board[:type]
    @level = board[:level]
    @x = board[:x]
    @y = board[:y]
    @squares = create_maze(maze_layout, board[:endpoints])
    @valid = valid_maze?
    @solutions = []
    solve([{ path: [start_square_index], maze: self }]) if @valid
  end

  def valid?
    valid_maze? && one_solution?
  end

  def all_squares_taken?
    squares.all?(&:taken?)
  end

  private

  def valid_maze?
    if number_of_endpoints == 2 # write #number_of_endpoints
      valid_finish_square?
    else
      valid_endpoint_squares?
    end
  end

  def number_of_endpoints
    number_of_squares_by_type(:endpoint)
  end

  # if single-endpoint maze
  def valid_finish_square?
    square = finish_square_index
    return false if connected_to_start_square?(square)
    return false if connected_to_more_than_one_normal_square?(square)
    true
  end

  def finish_square_index
    squares.each_with_index { |square, idx| return idx if square.finish_square? }
  end

  # if multi-endpoint maze
  def valid_endpoint_squares?
    all_square_indexes_of_type('endpoint').all? { |index| valid_endpoint_square?(index) }
  end

  def valid_endpoint_square?(square)
    return false if connected_to_endpoint_square?(square)
    true
  end

  def create_maze(maze, number_of_endpoints)
    maze.map.with_index do |square, index|
      if square =~ /endpoint/
        group = square.match(/\d/).to_s.to_i
        subgroup = square.match(/(?<=_)[a-z]/).to_s
        if subgroup == 'a' && number_of_endpoints == 1
          EndpointSquare.new(:endpoint, :taken, group, subgroup, index)
        else
          EndpointSquare.new(:endpoint, :not_taken, group, subgroup, index)
        end
      elsif square =~ /portal/
        group = square.match(/\d/).to_s.to_i
        subgroup = square.match(/(?<=_)[a-z]/).to_s
        PortalSquare.new(:portal, :not_taken, group, subgroup, index)
      elsif square =~ /tunnel/
        group = square.match(/\d/).to_s.to_i
        subgroup = square.match(/(?<=_)[a-z]/).to_s
        TunnelSquare.new(:tunnel, :not_taken, group, subgroup, index)
      elsif square == 'bridge'
        BridgeSquare.new(:bridge, :not_taken, index)
      elsif square == 'barrier'
        Square.new(:barrier, :taken, index)
      else
        Square.new(:normal, :not_taken, index)
      end
    end
  end

  def size
    squares.count
  end
end

class BridgeMaze < Maze
  include NavigateBridge
  include SolveBridge

  private

  def valid_maze?
    valid_finish_square? && valid_bridge_squares?
  end

  def valid_bridge_squares?
    all_square_indexes_of_type('bridge').all? do |square|
      !connected_to_barrier_square?(square) && !border_square?(square)
    end
  end
end

class TunnelMaze < Maze
  include NavigateTunnel
  include SolveTunnel

  private

  # def valid_maze?
  #   valid_finish_square?
  # end
end

class PortalMaze < Maze
  include NavigatePortal
  include SolvePortal

  private

  def valid_maze?
    valid_finish_square? && valid_portal_squares?
  end

  def valid_portal_squares?
    all_portal_squares_on_border_of_maze? &&
      all_portal_pairs_on_opposite_sides_of_same_row_or_column?
  end

  def all_portal_squares_on_border_of_maze?
    all_square_indexes_of_type('portal').all? do |square_index|
      portal_square_on_border_of_maze?(square_index)
    end
  end

  def portal_square_on_border_of_maze?(square_index)
    return false unless border_square?(square_index)
    true
  end

  def all_portal_pairs_on_opposite_sides_of_same_row_or_column?
    portal_pair_indexes.all? do |square_indexes|
      portal_pair_on_opposite_sides_of_same_row?(square_indexes) ||
        portal_pair_on_opposite_sides_of_same_column?(square_indexes)
    end
  end
end

class Square
  attr_reader :type, :index
  attr_accessor :status

  def initialize(type, status, index)
    @status = status
    @type = type
    @index = index
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
    type == :endpoint && subgroup == 'a'
  end

  def finish_square?
    type == :endpoint && subgroup == 'b'
  end

  def normal_square?
    type == :normal
  end

  def barrier_square?
    type == :barrier
  end

  def bridge_square?
    type == :bridge
  end

  def endpoint_square?
    type == :endpoint
  end

  def tunnel_square?
    type == :tunnel
  end

  def portal_square?
    type == :portal
  end
end

class PairSquare < Square
  attr_reader :group, :subgroup

  def initialize(type, status, group, subgroup, index)
    super(type, status, index)
    @group = group
    @subgroup = subgroup
  end
end

class EndpointSquare < PairSquare; end

class TunnelSquare < PairSquare; end

class PortalSquare < PairSquare; end

class BridgeSquare < Square
  attr_accessor :horizontal_taken, :vertical_taken

  def initialize(type, status, index)
    super(type, status, index)
    @horizontal_taken = false
    @vertical_taken = false
  end

  def vertical_taken?
    vertical_taken
  end

  def vertical_not_taken?
    !vertical_taken
  end

  def vertical_taken!
    self.vertical_taken = true
  end

  def horizontal_taken?
    horizontal_taken
  end

  def horizontal_not_taken?
    !horizontal_taken
  end

  def horizontal_taken!
    self.horizontal_taken = true
  end
end

# SIMPLE MAZE - DONE
boards = [{ type: :simple, x: 3, y: 2, endpoints: 1, barriers: 1, level: 1 }]

# BRIDGE - DONE
# boards = [{ type: :bridge, x: 4, y: 4, endpoints: 1, barriers: 1, bridges: 1, level: 1 }]

# TUNNEL - DONE
# 1 tunnel, 1 barrier
# boards = [{ type: :tunnel, x: 3, y: 3, endpoints: 1, barriers: 1, tunnels: 1, level: 1 }]

# WARP - DONE
# 1 warp, 1 barrier
# boards = [{ type: :portal, x: 3, y: 3, endpoints: 1, barriers: 1, portals: 1, level: 1 }]

Boards.new(boards)
