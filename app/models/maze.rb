class Maze
  MAZE_TYPE_CLASS_NAMES = { 'simple' => 'SimpleMaze',
                            'bridge' => 'BridgeMaze',
                            'tunnel' => 'TunnelMaze',
                            'portal' => 'PortalMaze' }

  include MazeNavigate
  include MazeSolve

  attr_reader :maze_type, :level, :x, :y, :squares, :valid, :solutions

  def initialize(maze)
    @maze_type = maze['maze_type']
    @x = maze['x'].to_i
    @y = maze['y'].to_i
    @squares = []

    if maze['squares']
      @squares = maze['squares']
    else
      @squares = create_maze(JSON.parse(maze['permutation']),
                             maze['endpoints'].to_i)
    end

    @solutions = []

    if maze['solutions']
      @solutions = maze['solutions']
    elsif valid_maze?
      solve([{ path: [start_square_index], maze: self }])
    end
  end

  def self.maze_type_to_class(type)
    class_name = MAZE_TYPE_CLASS_NAMES[type]
    Kernel.const_get(class_name) if Kernel.const_defined?(class_name)
  end

  def self.types_popover
    popover_content = ""
    types_popovers.values.each do |content|
      popover_content << "<p><strong>#{content[:title]}</strong><br>#{content[:body]}</p>"
    end
    { title: "Maze Types", body: popover_content }
  end

  def self.types_popovers
    popover_content = {}
    MAZE_TYPE_CLASS_NAMES.values.each do |class_name|
      maze_class = Kernel.const_get(class_name) if Kernel.const_defined?(class_name)
      popover_content[maze_class.to_symbol] = maze_class.popover
    end
    popover_content
  end

  def valid?
    valid_maze? # && one_solution?
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
        MazeSquare.new(:barrier, :taken, index)
      else
        MazeSquare.new(:normal, :not_taken, index)
      end
    end
  end

  def size
    squares.count
  end
end

class SimpleMaze < Maze
  def self.to_string
    'simple'
  end

  def self.to_symbol
    name = to_string
    name.gsub!(' ', '_') if name.include?(' ')
    name.to_sym
  end

  def self.popover
    { title: "Simple Mazes", body: "Here's a description of a simple maze."}
  end
end

class BridgeMaze < Maze
  include NavigateBridgeMaze
  include SolveBridgeMaze

  def self.to_string
    'bridge'
  end

  def self.to_symbol
    name = to_string
    name.gsub!(' ', '_') if name.include?(' ')
    name.to_sym
  end

  def self.popover
    { title: "Bridge Mazes", body: "Here's a description of a bridge maze."}
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

  def self.to_string
    'tunnel'
  end

  def self.to_symbol
    name = to_string
    name.gsub!(' ', '_') if name.include?(' ')
    name.to_sym
  end

  def self.popover
    { title: "Tunnel Mazes", body: "Here's a description of a tunnel maze."}
  end

  private

  def valid_maze?
    valid_finish_square?
  end
end

class PortalMaze < Maze
  include NavigatePortalMaze
  include SolvePortalMaze

  def self.to_string
    'portal'
  end

  def self.to_symbol
    name = to_string
    name.gsub!(' ', '_') if name.include?(' ')
    name.to_sym
  end

  def self.popover
    { title: "Portal Mazes", body: "Here's a description of a portal maze."}
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
