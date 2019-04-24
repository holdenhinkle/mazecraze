class MazeFormula < ActiveRecord::Base
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
    Maze.to_class(formula[:type]).valid?(formula)
  end

  def self.validation(formula)
    Maze.to_class(formula[:type]).validation(formula)
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
