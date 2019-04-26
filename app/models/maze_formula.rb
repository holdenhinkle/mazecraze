class MazeFormula < ActiveRecord::Base
  X_MIN = 3
  X_MAX = 10
  Y_MIN = 2
  Y_MAX = 10
  ENDPOINT_MIN = 1
  ENDPOINT_MAX = 4
  BARRIER_MIN = 1
  BARRIER_MAX = 3

  attr_reader :x, :y, :size,
              :num_endpoints, :num_barriers, :num_bridges,
              :num_portals, :num_tunnels,
              :rotate, :invert

  def initialize(formula)
    @x = formula[:x]
    @y = formula[:y]
    @size = @x * @y
    @num_endpoints = formula[:endpoints]
    @num_barriers = formula[:barriers] ? formula[:barriers] : 0
    @num_bridges = formula[:bridges] ? formula[:bridges] : 0
    @num_portals = formula[:portals] ? formula[:portals] : 0
    @num_tunnels = formula[:tunnels] ? formula[:tunnels] : 0
    @rotate = MazeRotate.new(@x, @y)
    @flip = MazeFlip.new(@x, @y)
    create_mazes(formula)
  end

  def self.new_formula_form_popovers
    maze_types = Maze.types_popover
    maze_dimensions = Maze.dimensions_popover
    maze_square_types = MazeSquare.types_popovers
    maze_types.merge(maze_dimensions).merge(maze_square_types)
  end

  def self.new_formula_hash(params)
    formula = { type: params[:maze_type],
                x: to_integer(params[:x_value]), #rename empty_string_to_zero_string ????
                y: to_integer(params[:y_value]),
                endpoints: to_integer(params[:endpoints]),
                barriers: to_integer(params[:barriers]),
                bridges: to_integer(params[:bridges]),
                tunnels: to_integer(params[:tunnels]),
                portals: to_integer(params[:portals]) }
    params[:experiment] ? formula[:experiment] = true : formula[:experiment] = false
    formula
  end

  def self.exists?(formula)
    sql = <<~SQL
      SELECT * 
      FROM maze_formulas 
      WHERE 
      maze_type = ? AND 
      width = ? AND 
      height = ? AND 
      endpoints = ? AND 
      barriers = ? AND 
      bridges = ? AND 
      tunnels = ? AND 
      portals = ?;
    SQL

    results = execute(sql.gsub!("\n", ""), formula[:type],
                      formula[:x], formula[:y], formula[:endpoints],
                      formula[:barriers], formula[:bridges],
                      formula[:tunnels], formula[:portals])

    return false if results.empty?
    true
  end

  def self.valid?(formula)
    formula_class = maze_type_formula_class(formula[:type])
    [formula_class.x_valid_input?(formula[:x]),
     formula_class.y_valid_input?(formula[:y]),
     formula_class.endpoints_valid_input?(formula[:endpoints]),
     formula_class.barriers_valid_input?(formula[:barriers]),
     formula_class.bridges_valid_input?(formula[:bridges]),
     formula_class.tunnels_valid_input?(formula[:tunnels]),
     formula_class.portals_valid_input?(formula[:portals])].all?
  end

  def self.validation(formula)
    formula_class = maze_type_formula_class(formula[:type])
    validation = { validation: true }
    formula_class.x_validation(validation, formula[:x])
    formula_class.y_validation(validation, formula[:y])
    formula_class.endpoints_validation(validation, formula[:endpoints])
    formula_class.barrier_validation(validation, formula[:barriers])
    formula_class.bridge_validation(validation, formula[:bridges])
    formula_class.tunnel_validation(validation, formula[:tunnels])
    formula_class.portal_validation(validation, formula[:portals])
    validation
  end

  def self.save!(formula)
    sql = <<~SQL
      INSERT INTO maze_formulas 
      (maze_type, width, height, endpoints, barriers, bridges, tunnels, portals, experiment) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    SQL

    execute(sql.gsub!("\n", ""), formula[:type],
            formula[:x], formula[:y], formula[:endpoints],
            formula[:barriers], formula[:bridges],
            formula[:tunnels], formula[:portals], formula[:experiment])
  end

  private

  def self.to_integer(value)
      value == '' ? 0 : value.to_i
  end

  def self.maze_type_formula_class(type)
    class_name_string = type.to_s.split('_').map(&:capitalize).join << 'MazeFormula'
    self.descendants.each do |class_name|
      return class_name if class_name.to_s == class_name_string
    end
  end

  def self.x_valid_input?(x)
    (X_MIN..X_MAX).cover?(x)
  end

  def self.y_valid_input?(y)
    (Y_MIN..Y_MAX).cover?(y)
  end

  def self.endpoints_valid_input?(endpoints)
    (ENDPOINT_MIN..ENDPOINT_MAX).cover?(endpoints)
  end

  def self.barriers_valid_input?(barriers)
    (BARRIER_MIN..BARRIER_MAX).cover?(barriers)
  end

  def self.bridges_valid_input?(bridges)
    bridges == 0
  end

  def self.tunnels_valid_input?(tunnels)
    tunnels == 0
  end

  def self.portals_valid_input?(portals)
    portals == 0
  end

  def self.x_validation(validation, x)
    if (X_MIN..X_MAX).cover?(x)
      validation[:x_validation_css] = 'is-valid'
      validation[:x_validation_feedback_css] = 'valid-feedback'
      validation[:x_validation_feedback] = 'Looks good!'
    else
      validation[:x_validation_css] = 'is-invalid'
      validation[:x_validation_feedback_css] = 'invalid-feedback'
      validation[:x_validation_feedback] = "Width must be between #{X_MIN} and #{X_MAX}."
    end
  end

  def self.y_validation(validation, y)
    if (Y_MIN..Y_MAX).cover?(y)
      validation[:y_validation_css] = 'is-valid'
      validation[:y_validation_feedback_css] = 'valid-feedback'
      validation[:y_validation_feedback] = 'Looks good!'
    else
      validation[:y_validation_css] = 'is-invalid'
      validation[:y_validation_feedback_css] = 'invalid-feedback'
      validation[:y_validation_feedback] = "Height must be between #{Y_MIN} and #{Y_MAX}."
    end
  end

  def self.endpoints_validation(validation, endpoints)
    if (ENDPOINT_MIN..ENDPOINT_MAX).cover?(endpoints)
      validation[:endpoint_validation_css] = 'is-valid'
      validation[:endpoint_validation_feedback_css] = 'valid-feedback'
      validation[:endpoint_validation_feedback] = 'Looks good!'
    else
      validation[:endpoint_validation_css] = 'is-invalid'
      validation[:endpoint_validation_feedback_css] = 'invalid-feedback'
      validation[:endpoint_validation_feedback] = "Number of endpoints must be between #{ENDPOINT_MIN} and #{ENDPOINT_MAX}."
    end
  end

  def self.barrier_validation(validation, barriers)
    if (BARRIER_MIN..BARRIER_MAX).cover?(barriers)
      validation[:barrier_validation_css] = 'is-valid'
      validation[:barrier_validation_feedback_css] = 'valid-feedback'
      validation[:barrier_validation_feedback] = 'Looks good!'
    else
      validation[:barrier_validation_css] = 'is-invalid'
      validation[:barrier_validation_feedback_css] = 'invalid-feedback'
      validation[:barrier_validation_feedback] = "Number of barriers must be between #{BARRIER_MIN} and #{BARRIER_MAX}."
    end
  end

  def self.bridge_validation(validation, bridges)
    if bridges > 0
      validation[:bridge_validation_css] = 'is-invalid'
      validation[:bridge_validation_feedback_css] = 'invalid-feedback'
      validation[:bridge_validation_feedback] = 'Bridge squares are not allowed in Simple mazes.'
    end
  end

  def self.tunnel_validation(validation, tunnels)
    if tunnels > 0
      validation[:tunnel_validation_css] = 'is-invalid'
      validation[:tunnel_validation_feedback_css] = 'invalid-feedback'
      validation[:tunnel_validation_feedback] = 'Tunnel squares are not allowed in Simple mazes.'
    end
  end

  def self.portal_validation(validation, portals)
    if portals > 0
      validation[:portal_validation_css] = 'is-invalid'
      validation[:portal_validation_feedback_css] = 'invalid-feedback'
      validation[:portal_validation_feedback] = 'Portal squares are not allowed in Simple mazes.'
    end
  end

  def create_mazes(formula)
    counter = starting_file_number(formula[:level]) + 1
    permutations_file_path = create_permutations_file_path
    generate_permutations(layout, permutations_file_path)
    File.open(permutations_file_path, "r").each_line do |maze_layout|
      maze = Object.const_get(maze_type(formula[:type])).new(formula, JSON.parse(maze_layout))
      next unless maze.valid?
      save_maze!(maze, counter)
      counter += 1
    end
  end

  # * *
  # FOR testing
  # *

  # ONE LINE BRIDGE
  # def create_mazes(formula)
  #   new_maze = ["endpoint_1_b", "barrier", "normal", "normal",
  #               "normal", "normal", "bridge", "normal",
  #               "normal", "normal", "normal", "endpoint_1_a",
  #               "normal", "normal", "normal", "normal"]

  #   maze = BridgeMaze.new(formula, new_maze)
  #   binding.pry
  # end

  # ONE LINE TUNNEL
  # def create_mazes(formula)
  #   counter = starting_file_number(formula[:level]) + 1
  #   permutations_file_path = "/Users/hamedahinkle/Documents/LaunchSchool/17x_projects/maze/data/do_not_delete/maze_permutations/tunnel_3x3.txt"
  #   File.open(permutations_file_path, "r").each_line do |maze_layout|
  #     maze = Object.const_get(maze_type(formula[:type])).new(formula, JSON.parse(maze_layout))
  #     next unless maze.valid?
  #     save_maze!(maze, counter)
  #     counter += 1
  #   end
  # end

  # ONE LINE PORTAL
  # def create_mazes(formula)
  #   counter = starting_file_number(formula[:level]) + 1
  #   permutations_file_path = "/Users/hamedahinkle/Documents/LaunchSchool/17x_projects/maze/data/do_not_delete/maze_permutations/portal_3x3.txt""
  #   File.open(permutations_file_path, "r").each_line do |maze_layout|
  #     maze = Object.const_get(maze_type(formula[:type])).new(formula, JSON.parse(maze_layout))
  #     next unless maze.valid?
  #     save_maze!(maze, counter)
  #     counter += 1
  #   end
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
    permutation_variations = [permutation] +
                             permutation_rotations_and_inversions(permutation)
    File.foreach(file_path).any? do |line|
      permutation_variations.any? { |rotation| line.include?(rotation.to_s) }
    end
  end

  def permutation_rotations_and_inversions(permutation)
    rotate.all_rotations(permutation).values +
      flip.all_inversions(permutation).values
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
    when :simple then 'SimpleMaze'
    when :portal then "PortalMaze"
    when :tunnel then "TunnelMaze"
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

class SimpleMazeFormula < MazeFormula

end

class BridgeMazeFormula < MazeFormula
  BRIDGE_MIN = 1
  BRIDGE_MAX = 3

  def self.bridge_validation(validation, formula)
    if (BRIDGE_MIN..BRIDGE_MAX).cover?(formula[:bridges])
      validation[:bridge_validation_css] = 'is-invalid'
      validation[:bridge_validation_feedback_css] = 'invalid-feedback'
      validation[:bridge_validation_feedback] = "Number of bridges must be between #{BRIDGE_MIN} and #{BRIDGE_MAX}."
    end
  end
end

class TunnelMazeFormula < MazeFormula
  X_MIN = 5
  X_MAX = 15
  Y_MIN = 5
  Y_MAX = 15
  TUNNEL_MIN = 1
  TUNNEL_MAX = 3

  def self.tunnel_validation(validation, formula)
    if (TUNNEL_MIN..TUNNEL_MAX).cover?(formula[:tunnels])
      validation[:tunnel_validation_css] = 'is-invalid'
      validation[:tunnel_validation_feedback_css] = 'invalid-feedback'
      validation[:tunnel_validation_feedback] = "Number of tunnels must be between #{TUNNEL_MIN} and #{TUNNEL_MAX}."
    end
  end
end

class PortalMazeFormula < MazeFormula
  PORTAL_MIN = 1
  PORTAL_MAX = 3

  def self.portal_validation(validation, formula)
    if (PORTAL_MIN..PORTAL_MAX).cover?(formula[:portals])
      validation[:portal_validation_css] = 'is-invalid'
      validation[:portal_validation_feedback_css] = 'invalid-feedback'
      validation[:portal_validation_feedback] = "Number of portals must be between #{PORTAL_MIN} and #{PORTAL_MAX}."
    end
  end
end

