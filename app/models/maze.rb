module MazeCraze
  class Maze
    include MazeCraze::MazeNavigate
    include MazeCraze::MazeSolve
    include MazeCraze::Queryable
    extend MazeCraze::Queryable

    MAZE_VARIATIONS = ['original', 'rotated_90_degrees', 'rotated_180_degrees', 'rotated_270_degrees', 'flipped_vertically', 'flipped_horizontally'].freeze

    class << self
      def maze_type_to_class(type)
        class_name = 'MazeCraze::' + MAZE_TYPE_CLASS_NAMES[type]
        Kernel.const_get(class_name) if Kernel.const_defined?(class_name)
      end

      def generate_mazes(formula_id, background_job_id)
        permutation_tuples = MazeCraze::Permutation.permutations_by_formula_id(formula_id)

        maze_count = 0

        permutation_tuples.each do |maze_args|
          maze = Maze.maze_type_to_class(maze_args["maze_type"]).new(maze_args)
          next unless maze.solutions.any?

          permutation = Permutation.new(JSON.parse(maze_args['permutation']), maze_args['x'], maze_args['y'], nil, nil)
          
          permutation.variations.each do |variation, board|
            maze_args['variation'] = variation
            maze_args['permutation'] = board.to_json
            maze_variation = Maze.maze_type_to_class(maze_args["maze_type"]).new(maze_args)
            maze_variation.save!(background_job_id, maze_args['id'], board, variation)
            maze_count += 1
          end
        end

        maze_count
      end
  
      def types_popover
        popover = { maze_types: { title: 'Maze Types', body: '' } }
        types_popovers.values.each do |content|
          popover[:maze_types][:body] << "<p><strong>#{content[:title]}</strong><br>#{content[:body]}</p>"
        end
        popover
      end
  
      def types_popovers
        MAZE_TYPE_CLASS_NAMES.values.each_with_object({}) do |class_name, popover_content|
          maze_class = Kernel.const_get('MazeCraze::' + class_name) if Kernel.const_defined?('MazeCraze::' + class_name)
          popover_content[maze_class.to_symbol] = maze_class.popover
        end
      end
    end
    
    MAZE_TYPE_CLASS_NAMES = { 'simple' => 'SimpleMaze',
                              'bridge' => 'BridgeMaze',
                              'tunnel' => 'TunnelMaze',
                              'portal' => 'PortalMaze' }

    attr_reader :maze_type, :level, :x, :y, :squares, :valid, :solutions

    def initialize(maze)
      @maze_type = maze['maze_type']
      @x = maze['x'].to_i
      @y = maze['y'].to_i
      @squares = create_maze(JSON.parse(maze['permutation']), maze['endpoints'].to_i)
      @solutions = []
      
      if maze['solutions']
        @solutions = maze['solutions']
      elsif valid_maze?
        solve([{ path: [start_square_index], maze: self }])
      end
    end

    def save!(background_job_id, permutation_id, board, variation)
      sql = <<~SQL
        INSERT INTO mazes 
        (background_job_id, permutation_id, board, number_of_solutions, solutions, variation) 
        VALUES ($1, $2, $3, $4, $5, $6);
      SQL

      query(sql.gsub!("\n", ""), background_job_id, permutation_id, board, @solutions.length, @solutions, variation)
    end

    def valid?
      valid_maze?
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
          group = square_group(square)
          subgroup = square_subgroup(square)
          if subgroup == 'a' && number_of_endpoints == 1
            MazeCraze::EndpointSquare.new(:endpoint, :taken, group, subgroup, index)
          else
            MazeCraze::EndpointSquare.new(:endpoint, :not_taken, group, subgroup, index)
          end
        elsif square =~ /portal/
          MazeCraze::PortalSquare.new(:portal, :not_taken, square_group(square),square_subgroup(square), index)
        elsif square =~ /tunnel/
          MazeCraze::TunnelSquare.new(:tunnel, :not_taken, square_group(square), square_subgroup(square), index)
        elsif square == 'bridge'
          MazeCraze::BridgeSquare.new(:bridge, :not_taken, index)
        elsif square == 'barrier'
          MazeCraze::MazeSquare.new(:barrier, :taken, index)
        else
          MazeCraze::MazeSquare.new(:normal, :not_taken, index)
        end
      end
    end

    def square_group(square)
      square.match(/\d/).to_s.to_i
    end

    def square_subgroup(square)
      square.match(/(?<=_)[a-z]/).to_s
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
    include MazeCraze::NavigateBridgeMaze
    include MazeCraze::SolveBridgeMaze

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
    include MazeCraze::NavigateTunnelMaze
    include MazeCraze::SolveTunnelMaze

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
    include MazeCraze::NavigatePortalMaze
    include MazeCraze::SolvePortalMaze

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
end
