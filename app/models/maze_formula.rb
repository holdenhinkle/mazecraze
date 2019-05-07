class MazeFormula
  MAZE_FORMULA_CLASS_NAMES = ['SimpleMazeFormula',
                              'BridgeMazeFormula',
                              'TunnelMazeFormula',
                              'PortalMazeFormula']
  X_MIN = 3
  X_MAX = 10
  Y_MIN = 2
  Y_MAX = 10
  ENDPOINT_MIN = 1
  ENDPOINT_MAX = 4
  BARRIER_MIN = 0
  BARRIER_MAX = 3

  attr_reader :type, :x, :y,
              :num_endpoints, :num_barriers, :num_bridges,
              :num_tunnels, :num_portals, :experiment,
              :db

  def initialize(params)
    @type = params[:maze_type]
    @x = integer_value(params[:x_value])
    @y = integer_value(params[:y_value])
    @num_endpoints = integer_value(params[:endpoints])
    @num_barriers = integer_value(params[:barriers])
    @num_bridges = integer_value(params[:bridges])
    @num_tunnels = integer_value(params[:tunnels])
    @num_portals = integer_value(params[:portals])
    @experiment = params[:experiment] ? true : false
    @db = DatabaseConnection.new
    # @rotate = MazeRotate.new(@x, @y)
    # @flip = MazeFlip.new(@x, @y)
  end

  def self.maze_formula_type_to_class(type)
    class_name = type.split('_').map(&:capitalize).join << 'MazeFormula'
    Kernel.const_get(class_name) if Kernel.const_defined?(class_name)
  end

  def self.form_popovers
    popovers = build_popovers
    popovers.keys.each do |element|
      next if [:title, :body].include?(element)
      range = case element
              when :x
                x_range
              when :y
                y_range
              when :endpoint
                endpoint_range
              when :barrier
                barrier_range
              when :bridge
                bridge_range
              when :tunnel
                bridge_range
              when :portal
                bridge_range
              end
      popovers[element][:body] = popovers[element][:body].prepend(range)
    end
    popovers
  end

  def self.build_popovers
    maze_types_popover = Maze.types_popover
    maze_square_types_popovers = MazeSquare.types_popovers
    maze_types_popover.merge(maze_dimensions_popovers).merge(maze_square_types_popovers)
  end

  def exists?
    sql = <<~SQL
      SELECT * 
      FROM maze_formulas 
      WHERE 
      maze_type = $1 AND 
      width = $2 AND 
      height = $3 AND 
      endpoints = $4 AND 
      barriers = $5 AND 
      bridges = $6 AND 
      tunnels = $7 AND 
      portals = $8;
    SQL

    results = db.query(sql.gsub!("\n", ""), type, x, y, num_endpoints,
                       num_barriers, num_bridges, num_tunnels, num_portals)

    return false if results.values.empty?
    true
  end

  def experiment?
    experiment
  end

  def valid?
    [x_valid_input?,
     y_valid_input?,
     endpoints_valid_input?,
     barriers_valid_input?,
     bridges_valid_input?,
     tunnels_valid_input?,
     portals_valid_input?].all?
  end

  def experiment_valid?
    [barriers_valid_input?,
     bridges_valid_input?,
     tunnels_valid_input?,
     portals_valid_input?].all?
  end

  def validation
    validation = { validation: true }
    x_validation(validation)
    y_validation(validation)
    endpoints_validation(validation)
    barrier_validation(validation)
    bridge_validation(validation)
    tunnel_validation(validation)
    portal_validation(validation)
    validation
  end

  def save!
    sql = <<~SQL
      INSERT INTO maze_formulas 
      (maze_type, width, height, endpoints, barriers, bridges, tunnels, portals, experiment) 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);
    SQL

    db.query(sql.gsub!("\n", ""), type, x, y, num_endpoints,
    num_barriers, num_bridges, num_tunnels, num_portals, experiment)

    # execute(sql.gsub!("\n", ""), formula[:type],
    #         formula[:x], formula[:y], formula[:endpoints],
    #         formula[:barriers], formula[:bridges],
    #         formula[:tunnels], formula[:portals], formula[:experiment])
  end

  # IS THERE A BETTER PLACE TO PUT THIS
  def self.status_list
    %w(pending approved rejected)
  end

  def self.count_by_type_and_status(type, status)
    sql = "SELECT count(maze_type) FROM maze_formulas WHERE maze_type = ? AND status = ?;"
    execute(sql, type, status)
  end

  def self.status_list_by_maze_type(type)
    sql = "SELECT id, width, height, endpoints, barriers, bridges, tunnels, portals, experiment, status FROM maze_formulas WHERE maze_type = ? ORDER BY width, height, endpoints, barriers;"
    execute(sql, type)
  end

  def self.update_status(id, status)
    sql = "UPDATE maze_formulas SET status = ? WHERE id = ?;"
    execute(sql, status, id)
  end

  # LEFT OFF HERE 
  # def self.valid_id?(id)
  #   sql = "SELECT * FROM maze_formulas WHERE id = ?;"
  #   results = execute(sql, id)
  # end

  private

  def integer_value(value)
    value == '' ? 0 : value.to_i
  end

  def self.maze_dimensions_popovers
    { x: { title: "Valid Widths",
           body: "The width should be between #{X_MIN} and #{X_MAX} squares wide." },
      y: { title: "Valid Heights",
          body: "The width should be between #{Y_MIN} and #{Y_MAX} squares high." } }
  end

  def self.x_range
    range_message(X_MIN, X_MAX)
  end

  def self.y_range
    range_message(Y_MIN, Y_MAX)
  end

  def self.endpoint_range
    range_message(ENDPOINT_MIN, ENDPOINT_MAX)
  end

  def self.barrier_range
    range_message(BARRIER_MIN, BARRIER_MAX)
  end

  def self.bridge_range
    range_message(BridgeMazeFormula::BRIDGE_MIN, BridgeMazeFormula::BRIDGE_MAX)
  end

  def self.tunnel_range
    range_message(TunnelMazeFormula::TUNNEL_MIN, TunnelMazeFormula::TUNNEL_MAX)
  end

  def self.portal_range
    range_message(PortalMazeFormula::PORTAL_MIN, PortalMazeFormula::PORTAL_MAX)
  end

  def self.range_message(min, max)
    "<p><strong>Valid input:</strong><br>Between #{min} and #{max}<p><hr>"
  end

  def x_valid_input?
    (X_MIN..X_MAX).cover?(x) || experiment? && x > 0
  end

  def y_valid_input?
    (Y_MIN..Y_MAX).cover?(y) || experiment? && y > 0
  end

  def endpoints_valid_input?
    (ENDPOINT_MIN..ENDPOINT_MAX).cover?(num_endpoints) || experiment? && num_endpoints > 1
  end

  def barriers_valid_input?
    if num_endpoints == 1
      return true if experiment? && num_barriers >= 1
      (1..BARRIER_MAX).cover?(num_barriers)
    else
      return true if experiment? && num_barriers >= 0
      (BARRIER_MIN..BARRIER_MAX).cover?(num_barriers)
    end
  end

  def bridges_valid_input?
    num_bridges == 0
  end

  def tunnels_valid_input?
    num_tunnels == 0
  end

  def portals_valid_input?
    num_portals == 0
  end

  def x_validation(validation)
    if x_valid_input?
      validation[:x_validation_css] = 'is-valid'
      validation[:x_validation_feedback_css] = 'valid-feedback'
      validation[:x_validation_feedback] = 'Looks good!'
    else
      validation[:x_validation_css] = 'is-invalid'
      validation[:x_validation_feedback_css] = 'invalid-feedback'
      validation[:x_validation_feedback] = "Width must be between #{X_MIN} and #{X_MAX}."
    end
  end

  def y_validation(validation)
    if y_valid_input?
      validation[:y_validation_css] = 'is-valid'
      validation[:y_validation_feedback_css] = 'valid-feedback'
      validation[:y_validation_feedback] = 'Looks good!'
    else
      validation[:y_validation_css] = 'is-invalid'
      validation[:y_validation_feedback_css] = 'invalid-feedback'
      validation[:y_validation_feedback] = "Height must be between #{Y_MIN} and #{Y_MAX}."
    end
  end

  def endpoints_validation(validation)
    if endpoints_valid_input?
      validation[:endpoint_validation_css] = 'is-valid'
      validation[:endpoint_validation_feedback_css] = 'valid-feedback'
      validation[:endpoint_validation_feedback] = 'Looks good!'
    else
      validation[:endpoint_validation_css] = 'is-invalid'
      validation[:endpoint_validation_feedback_css] = 'invalid-feedback'
      if experiment?
        validation[:endpoint_validation_feedback] = "Experiments must have at least 1 endpoint."
      else
        validation[:endpoint_validation_feedback] = "Number of endpoints must be between #{ENDPOINT_MIN} and #{ENDPOINT_MAX}."
      end
    end
  end

  def barrier_validation(validation)
    if barriers_valid_input?
      validation[:barrier_validation_css] = 'is-valid'
      validation[:barrier_validation_feedback_css] = 'valid-feedback'
      validation[:barrier_validation_feedback] = 'Looks good!'
    else
      validation[:barrier_validation_css] = 'is-invalid'
      validation[:barrier_validation_feedback_css] = 'invalid-feedback'
      if num_barriers == 0 && num_endpoints == 1
        validation[:barrier_validation_feedback] = "You must have at least 1 barrier if you have 1 endpoint."
      else
        validation[:barrier_validation_feedback] = "Number of barriers must be between #{BARRIER_MIN} and #{BARRIER_MAX}."
      end
    end
  end

  def bridge_validation(validation)
    if !bridges_valid_input?
      validation[:bridge_validation_css] = 'is-invalid'
      validation[:bridge_validation_feedback_css] = 'invalid-feedback'
      validation[:bridge_validation_feedback] = 'Bridge squares are only allowed on bridge mazes.'
    end
  end

  def tunnel_validation(validation)
    if !tunnels_valid_input?
      validation[:tunnel_validation_css] = 'is-invalid'
      validation[:tunnel_validation_feedback_css] = 'invalid-feedback'
      validation[:tunnel_validation_feedback] = 'Tunnel squares are only allowed on tunnel mazes.'
    end
  end

  def portal_validation(validation)
    if !portals_valid_input?
      validation[:portal_validation_css] = 'is-invalid'
      validation[:portal_validation_feedback_css] = 'invalid-feedback'
      validation[:portal_validation_feedback] = 'Portal squares are only allowed on portal mazes.'
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
    (x * y).times do
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

  def bridges_valid_input?
    (BRIDGE_MIN..BRIDGE_MAX).cover?(num_bridges) || experiment? && num_bridges > 0
  end

  def bridge_validation(validation)
    if bridges_valid_input?
      validation[:bridge_validation_css] = 'is-valid'
      validation[:bridge_validation_feedback_css] = 'valid-feedback'
      validation[:bridge_validation_feedback] = 'Looks good!'
    else
      validation[:bridge_validation_css] = 'is-invalid'
      validation[:bridge_validation_feedback_css] = 'invalid-feedback'
      if experiment?
        validation[:bridge_validation_feedback] = "Bridge experiments must have at least 1 bridge."
      else
        validation[:bridge_validation_feedback] = "Number of bridges must be between #{BRIDGE_MIN} and #{BRIDGE_MAX}."
      end
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

  def x_valid_input?
    (X_MIN..X_MAX).cover?(x) || experiment? && x > 0
  end

  def y_valid_input?
    (Y_MIN..Y_MAX).cover?(y) || experiment? && y > 0
  end

  def tunnels_valid_input?
    (TUNNEL_MIN..TUNNEL_MAX).cover?(num_tunnels) || experiment? && num_tunnels > 0
  end

  def tunnel_validation(validation)
    if tunnels_valid_input?
      validation[:tunnel_validation_css] = 'is-valid'
      validation[:tunnel_validation_feedback_css] = 'valid-feedback'
      validation[:tunnel_validation_feedback] = 'Looks good!'
    else
      validation[:tunnel_validation_css] = 'is-invalid'
      validation[:tunnel_validation_feedback_css] = 'invalid-feedback'
      if experiment?
        validation[:tunnel_validation_feedback] = "Tunnel experiments must have at least 1 tunnel."
      else
        validation[:tunnel_validation_feedback] = "Number of tunnels must be between #{TUNNEL_MIN} and #{TUNNEL_MAX}."
      end
    end
  end
end

class PortalMazeFormula < MazeFormula
  PORTAL_MIN = 1
  PORTAL_MAX = 3

  def portals_valid_input?
    (PORTAL_MIN..PORTAL_MAX).cover?(num_portals) || experiment? && num_portals > 0
  end

  def portal_validation(validation)
    if portals_valid_input?
      validation[:portal_validation_css] = 'is-valid'
      validation[:portal_validation_feedback_css] = 'valid-feedback'
      validation[:portal_validation_feedback] = 'Looks good!'
    else
      validation[:portal_validation_css] = 'is-invalid'
      validation[:portal_validation_feedback_css] = 'invalid-feedback'
      if experiment?
        validation[:portal_validation_feedback] = "Portal experiments must have at least 1 portal."
      else
        validation[:portal_validation_feedback] = "Number of portals must be between #{PORTAL_MIN} and #{PORTAL_MAX}."
      end
    end
  end
end
