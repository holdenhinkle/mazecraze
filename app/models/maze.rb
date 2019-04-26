class Maze
  X_MIN = 3
  X_MAX = 10
  Y_MIN = 2
  Y_MAX = 10
  ENDPOINT_MIN = 1
  ENDPOINT_MAX = 4
  BARRIER_MIN = 1
  BARRIER_MAX = 3

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
    self.descendants.map { |type| type.to_s }
  end

  # def self.basic_contraints
  #   { x: { min: X_MIN, max: X_MAX },
  #     y: { min: Y_MIN, max: Y_MAX },
  #     endpoints: { min: 1, max: 5 } }
  # end

  def self.to_class(type)
    self.descendants.each { |class_name| return class_name if class_name.to_s == type }
  end

  def self.types_popover
    popover_content = ""
    types_popovers.values.each do |content|
      popover_content << "<h6>#{content[:title]}</h6>"
      popover_content << "<p>#{content[:body]}</p>"
    end
    { title: "Maze Types", body: popover_content }
  end

  def self.types_popovers
    popover_content = {}
    self.descendants.each do |class_name| 
      popover_content[class_name.to_sym] = class_name.popover
    end
    popover_content
  end

  def self.dimensions_popover
    { x: { title: "Valid Widths",
           body: "The maze width should be between #{X_MIN} and #{X_MAX} squares wide." },
      y: { title: "Valid Heights",
          body: "The maze width should be between #{Y_MIN} and #{Y_MAX} squares high." } }
  end

  def self.validation(formula)
    validation = { validation: true }
    Maze.to_class(formula[:type]).x_validation(validation, formula)
    Maze.to_class(formula[:type]).y_validation(validation, formula)
    Maze.to_class(formula[:type]).endpoints_validation(validation, formula)
    Maze.to_class(formula[:type]).barrier_validation(validation, formula)
    Maze.to_class(formula[:type]).bridge_validation(validation, formula)
    Maze.to_class(formula[:type]).tunnel_validation(validation, formula)
    Maze.to_class(formula[:type]).portal_validation(validation, formula)
    validation
  end

  def valid?
    valid_maze? && one_solution?
  end

  def all_squares_taken?
    squares.all?(&:taken?)
  end

  private

  def self.x_validation(validation, formula)
    if (X_MIN..X_MAX).cover?(formula[:x])
      validation[:x_validation_css] = 'is-valid'
      validation[:x_validation_feedback_css] = 'valid-feedback'
      validation[:x_validation_feedback] = 'Looks good!'
    else
      validation[:x_validation_css] = 'is-invalid'
      validation[:x_validation_feedback_css] = 'invalid-feedback'
      validation[:x_validation_feedback] = "Width must be between #{X_MIN} and #{X_MAX}."
    end
  end

  def self.y_validation(validation, formula)
    if (Y_MIN..Y_MAX).cover?(formula[:y])
      validation[:y_validation_css] = 'is-valid'
      validation[:y_validation_feedback_css] = 'valid-feedback'
      validation[:y_validation_feedback] = 'Looks good!'
    else
      validation[:y_validation_css] = 'is-invalid'
      validation[:y_validation_feedback_css] = 'invalid-feedback'
      validation[:y_validation_feedback] = "Height must be between #{Y_MIN} and #{Y_MAX}."
    end
  end

  def self.endpoints_validation(validation, formula)
    if (ENDPOINT_MIN..ENDPOINT_MAX).cover?(formula[:endpoints])
      validation[:endpoint_validation_css] = 'is-valid'
      validation[:endpoint_validation_feedback_css] = 'valid-feedback'
      validation[:endpoint_validation_feedback] = 'Looks good!'
    else
      validation[:endpoint_validation_css] = 'is-invalid'
      validation[:endpoint_validation_feedback_css] = 'invalid-feedback'
      validation[:endpoint_validation_feedback] = "Number of endpoints must be between #{ENDPOINT_MIN} and #{ENDPOINT_MAX}."
    end
  end

  def self.barrier_validation(validation, formula)
    if (BARRIER_MIN..BARRIER_MAX).cover?(formula[:barriers])
      validation[:barrier_validation_css] = 'is-valid'
      validation[:barrier_validation_feedback_css] = 'valid-feedback'
      validation[:barrier_validation_feedback] = 'Looks good!'
    else
      validation[:barrier_validation_css] = 'is-invalid'
      validation[:barrier_validation_feedback_css] = 'invalid-feedback'
      validation[:barrier_validation_feedback] = "Number of barriers must be between #{BARRIER_MIN} and #{BARRIER_MAX}."
    end
  end

  def self.bridge_validation(validation, formula)
    if formula[:bridges] > 0
      validation[:bridge_validation_css] = 'is-invalid'
      validation[:bridge_validation_feedback_css] = 'invalid-feedback'
      validation[:bridge_validation_feedback] = 'Bridge squares are not allowed in Simple mazes.'
    end
  end

  def self.tunnel_validation(validation, formula)
    if formula[:tunnels] > 0
      validation[:tunnel_validation_css] = 'is-invalid'
      validation[:tunnel_validation_feedback_css] = 'invalid-feedback'
      validation[:tunnel_validation_feedback] = 'Tunnel squares are not allowed in Simple mazes.'
    end
  end

  def self.portal_validation(validation, formula)
    if formula[:portals] > 0
      validation[:portal_validation_css] = 'is-invalid'
      validation[:portal_validation_feedback_css] = 'invalid-feedback'
      validation[:portal_validation_feedback] = 'Portal squares are not allowed in Simple mazes.'
    end
  end

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
  def self.to_s
    'simple'
  end

  def self.to_sym
    :simple
  end

  def self.popover
    { title: "Simple Mazes", body: "Here's a description of a simple maze."}
  end

  def self.valid?(formula)
    # add ratio of x * y and number of barriers?
    (X_MIN..X_MAX).cover?(formula[:x]) &&
    (Y_MIN..Y_MAX).cover?(formula[:y]) &&
    (ENDPOINT_MIN..ENDPOINT_MAX).cover?(formula[:endpoints]) &&
    (BARRIER_MIN..BARRIER_MAX).cover?(formula[:barriers]) &&
    [formula[:bridges], formula[:tunnels], formula[:portals]].all? do |value|
      value == 0
    end
  end

  # def self.validation(formula)
  #   validation = {}
  #   x_validation(validation)
  #   y_validation(validation)
  #   endpoints_validation(validation)
  #   barrier_validation(validation)
  #   validation
    # if (X_MIN..X_MAX).cover?(formula[:x])
    #   validation[:x_validation_css] = 'is-valid'
    #   validation[:x_validation_feedback_css] = 'valid-feedback'
    #   validation[:x_validation_feedback] = 'Looks good!'
    # else
    #   validation[:x_validation_css] = 'is-invalid'
    #   validation[:x_validation_feedback_css] = 'invalid-feedback'
    #   validation[:x_validation_feedback] = 'Wdith (x-axis) feedback goes here'
    # end
    # if (Y_MIN..Y_MAX).cover?(formula[:y])
    #   validation[:y_validation_css] = 'is-valid'
    #   validation[:y_validation_feedback_css] = 'valid-feedback'
    #   validation[:y_validation_feedback] = 'Looks good!'
    # else
    #   validation[:y_validation_css] = 'is-invalid'
    #   validation[:y_validation_feedback_css] = 'invalid-feedback'
    #   validation[:y_validation_feedback] = 'Height (y-axis) feedback goes here'
    # end
    # if (ENDPOINT_MIN..ENDPOINT_MAX).cover?(formula[:endpoints])
    #   validation[:endpoint_validation_css] = 'is-valid'
    #   validation[:endpoint_validation_feedback_css] = 'valid-feedback'
    #   validation[:endpoint_validation_feedback] = 'Looks good!'
    # else
    #   validation[:endpoint_validation_css] = 'is-invalid'
    #   validation[:endpoint_validation_feedback_css] = 'invalid-feedback'
    #   validation[:endpoint_validation_feedback] = 'Endpoint feedback goes here'
    # end
    # if (BARRIER_MIN..BARRIER_MAX).cover?(formula[:barriers])
    #   validation[:barrier_validation_css] = 'is-valid'
    #   validation[:barrier_validation_feedback_css] = 'valid-feedback'
    #   validation[:barrier_validation_feedback] = 'Looks good!'
    # else
    #   validation[:barrier_validation_css] = 'is-invalid'
    #   validation[:barrier_validation_feedback_css] = 'invalid-feedback'
    #   validation[:barrier_validation_feedback] = 'Barrier feedback goes here'
    # end
  #   validation
  # end

  private

end

class BridgeMaze < Maze
  include NavigateBridgeMaze
  include SolveBridgeMaze

  def self.to_s
    'bridge'
  end

  def self.to_sym
    :bridge
  end

  def self.popover
    { title: "Bridge Mazes", body: "Here's a description of a bridge maze."}
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

  def self.to_s
    'tunnel'
  end

  def self.to_sym
    :tunnel
  end

  def self.popover
    { title: "Tunnel Mazes", body: "Here's a description of a tunnel maze."}
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

  def self.to_s
    'portal'
  end

  def self.to_sym
    :portal
  end

  def self.popover
    { title: "Portal Mazes", body: "Here's a description of a portal maze."}
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
