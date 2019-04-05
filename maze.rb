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
              :num_starts, :num_path_endpoints, :num_barriers, :num_bridges,
              :num_portals, :num_tunnels

  def initialize(board)
    @x = board[:x]
    @y = board[:y]
    @size = board[:x] * board[:y]
    @num_starts = board[:endpoints] ? 0 : 1
    @num_path_endpoints = board[:endpoints] ? board[:endpoints] : 0
    @num_barriers = board[:num_barriers] ? board[:num_barriers] : 0
    @num_bridges = board[:num_bridges] ? board[:num_bridges] : 0
    @num_portals = board[:num_portals] ? board[:num_portals] : 0
    @num_tunnels = board[:num_tunnels] ? board[:num_tunnels] : 0
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
  # boards = [{ type: :one_line_bridge, x: 4, y: 4, num_barriers: 1, num_bridges: 1, level: 1 }]
  # def create_mazes(board)
  #   new_maze = ["finish", "barrier", "normal", "normal",
  #               "normal", "normal", "bridge", "normal",
  #               "normal", "normal", "normal", "start",
  #               "normal", "normal", "normal", "normal"]

  #   maze = OneLineBridge.new(board, new_maze)
  # end

  # ONE LINE TUNNEL
  # def create_mazes(board)
  #   new_maze = ["start", "barrier", "tunnel_1_b", "normal",
  #               "normal", "normal", "normal", "normal",
  #               "normal", "normal", "barrier", "barrier",
  #               "tunnel_1_a", "normal", "normal", "finish"]
  #   maze = OneLineTunnel.new(board, new_maze)
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
      maze << if maze.count('start') != num_starts
                'start'
              elsif maze.count('finish') != num_starts
                'finish'
              elsif (count_pairs(maze, 'pair') / 2) != num_path_endpoints
                format_pair(maze, 'pair')
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
    when :one_line_simple then 'OneLine'
    when :one_line_portal then "OneLinePortal" # DO THIS
    when :one_line_tunnel then "OneLineTunnel" # DO THIS
    when :one_line_bridge then "OneLineBridge"
    when :multi_line_simple then 'MultiLine' # DO THIS
    when :multi_line_portal then "MultiLinePortal" # DO THIS
    when :multi_line_bridge then "MultiLineBridge" # DO THIS
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
    @squares = create_maze(maze_layout)
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

  def valid_finish_square?
    square = finish_square_index
    return false if connected_to_start_square?(square)
    return false if connected_to_more_than_one_normal_square?(square)
    true
  end

  def finish_square_index
    squares.each_with_index { |square, idx| return idx if square.finish_square? }
  end

  def create_maze(maze)
    maze.map do |square|
      if square =~ /start/
        Square.new(:start, :taken)
      elsif square =~ /finish/
        Square.new(:finish, :not_taken)
      # PAIR AND WARP CAN BE COMBINED -- TUNNEL TOO PROBABLY
      elsif square =~ /pair/
        group = square.match(/\d/).to_s.to_i
        subgroup = square.match(/(?<=_)[a-z]/).to_s
        Pair.new(:pair, :not_taken, group, subgroup)
      elsif square =~ /portal/
        group = square.match(/\d/).to_s.to_i
        subgroup = square.match(/(?<=_)[a-z]/).to_s
        Portal.new(:portal, :not_taken, group, subgroup)
      elsif square =~ /tunnel/
        group = square.match(/\d/).to_s.to_i
        Tunnel.new(:tunnel, :not_taken, group, subgroup)
      elsif square == 'bridge'
        Bridge.new(:bridge, :not_taken)
      elsif square == 'barrier'
        Square.new(:barrier, :taken)
      else
        Square.new(:normal, :not_taken)
      end
    end
  end

  def size
    squares.count
  end
end

class OneLine < Maze
  include NavigateOneline
  include SolveOneLine

  private

  def valid_maze?
    valid_finish_square?
  end

  # def valid_finish_square?
  #   square = finish_square_index
  #   return false if connected_to_start_square?(square)
  #   return false if connected_to_more_than_one_normal_square?(square)
  #   true
  # end

  # def finish_square_index
  #   squares.each_with_index { |square, idx| return idx if square.finish_square? }
  # end
end

class OneLineBridge < Maze
  include NavigateBridge
  include SolveBridge

  private

  def valid_maze?
    valid_finish_square? && valid_bridge_squares?
  end

  # def valid_finish_square?
  #   square = finish_square_index
  #   return false if connected_to_start_square?(square)
  #   return false if connected_to_more_than_one_normal_square?(square)
  #   true
  # end

  # def finish_square_index
  #   squares.each_with_index { |square, idx| return idx if square.finish_square? }
  # end

  def valid_bridge_squares?
    all_squares_of_type('bridge').all? do |square|
      !connected_to_barrier_square?(square) && !border_square?(square)
    end
  end
end

class OneLineTunnel < Maze
  include NavigateTunnel
  include SolveTunnel

  private

  def valid_maze?
    valid_finish_square?
  end
end

class OneLinePortal < Maze
  include NavigatePortal
  include SolvePortal

  private

  def valid_maze?
    valid_finish_square? && valid_portal_squares?
  end

  def valid_portal_squares?
    all_squares_of_type('portal').all? { |index| valid_portal_square?(index) }
  end

  def valid_portal_square?(square)
    return false unless border_square?(square)
    true
  end
end

class MultiLine < Maze
  private

  def valid_maze?
    valid_pair_squares?
  end

  def valid_pair_squares?
    all_squares_of_type('pair').all? { |index| valid_pair_square?(index) }
  end

  def valid_pair_square?(square)
    return false if connected_to_pair_square?(square)
    true
  end
end

class MultiLineBridge < Maze
end

class MultiLinePortal < Maze
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

  def barrier_square?
    return true if type.match(/barrier/)
    false
  end

  def bridge_square?
    return true if type.match(/bridge/)
    false
  end
end

class Pair < Square
  attr_reader :group, :subgroup

  def initialize(type, status, group, subgroup)
    super(type, status)
    @group = group
    @subgroup = subgroup
  end
end

class Tunnel < Pair; end

class Portal < Pair; end

# class Portal < Square
#   attr_reader :group, :subgroup

#   def initialize(type, status, group, subgroup)
#     super(type, status)
#     @group = group
#     @subgroup = subgroup
#   end
# end

class Bridge < Square
  attr_accessor :horizontal_taken, :vertical_taken

  def initialize(type, status)
    super(type, status)
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

# DONE
# SIMPLE GRID
boards = [{ type: :one_line_simple, x: 3, y: 2, num_barriers: 1, level: 1 }]

# 1 bridge, 1 barrier
# boards = [{ type: :one_line_bridge, x: 4, y: 4, num_barriers: 1, num_bridges: 1, level: 1 }]

# IN PROGRESS
# 1 tunnel, 1 barrier
# boards = [{ type: :one_line_tunnel, x: 4, y: 4, num_barriers: 3, num_tunnels: 1, level: 1 }]


# # 2 bridges, 1 barrier
# boards = [{ type: :one_line_bridge, x: 3, y: 2, num_barriers: 1, num_bridges: 2, level: 1 }]

# # 1 bridge
# boards = [{ type: :one_line_bridge, x: 4, y: 4, num_bridges: 1, num_barriers: 1, level: 1 }]

# # 1 portal
# boards = [{ type: :one_line_portal, x: 3, y: 2, num_portals: 1, level: 1 }]

# # 2 portals - 3 x 3
# boards = [{ type: :one_line_bridge, x: 3, y: 3, num_portals: 1, level: 1 }]

# # 2 bridge
# boards = [{ type: :one_line_bridge, x: 3, y: 2, num_bridges: 2, level: 1 }]

#MULTI
# boards = [{ type: :multi_line_simple, x: 3, y: 2, endpoints: 1, num_barriers: 1, level: 1 }]

# boards = [{ type: :multi_line_simple, x: 3, y: 3, endpoints: 3, num_barriers: 2, level: 1 }]


# boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 2, level: 1 }]

# boards = [{ x: 3, y: 2, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 3, y: 3, num_starts: 1, num_barriers: 2, level: 1 },
#           { x: 4, y: 3, num_starts: 1, num_barriers: 1, level: 1 },
#           { x: 4, y: 3, num_starts: 1, num_barriers: 2, level: 1 }]

# WARP GRID

# boards = [{ type: :one_line_bridge, x: 5, y: 5, num_bridges: 2, num_barriers: 2, level: 1 }]

# maze = ["finish", "normal", "normal", "normal", "normal", "barrier", "barrier", "normal", "normal", "normal", "normal", "normal", "normal", "normal", "normal", "normal", "bridge", "normal", "bridge", "normal", "start", "normal", "normal", "normal", "normal"] 

Boards.new(boards)
