class Maze
  include MazeNavigate
  include MazeSolve

  attr_reader :type, :level, :x, :y, :squares, :valid, :solutions

  def initialize(maze_formula, maze_layout)
    @type = maze_formula[:type]
    @level = maze_formula[:level]
    @x = maze_formula[:x]
    @y = maze_formula[:y]
    @squares = create_maze(maze_layout, maze_formula[:endpoints])
    @valid = valid_maze?
    @solutions = []
    solve([{ path: [start_square_index], maze: self }]) if @valid
  end

  def self.types
    self.descendants.map { |type| type.symbol }
  end

  def self.basic_contraints
    { x: { min: 3, max: 10 },
      y: { min: 2, max: 10 },
      endpoints: { min: 1, max: 5 },
      barriers: { min: 1, max: 3 } }
  end

  def self.symbol_to_class(type)
    self.descendants.each { |class_name| return class_name if class_name.symbol == type }
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

class SimpleMaze < Maze
  def self.symbol
    :simple
  end

  def self.contraints
  end

  def self.valid?
  end
end

class BridgeMaze < Maze
  include NavigateBridgeMaze
  include SolveBridgeMaze

  def self.symbol
    :bridge
  end

  def self.contraints
    { bridges: { min: 1, max: 3 } }
  end

  def self.valid?
  end

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
  include NavigateTunnelMaze
  include SolveTunnelMaze

  def self.symbol
    :tunnel
  end

  def self.contraints
    { tunnels: { min: 1, max: 3 } }
  end

  def self.valid?
  end

  private

  # def valid_maze?
  #   valid_finish_square?
  # end
end

class PortalMaze < Maze
  include NavigatePortalMaze
  include SolvePortalMaze

  def self.symbol
    :portal
  end

  def self.contraints
    { portal: { min: 1, max: 3 } }
  end

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
