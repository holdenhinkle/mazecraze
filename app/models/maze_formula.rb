module MazeCraze
  class MazeFormula
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    MAZE_FORMULA_CLASS_NAMES = { 'simple' => 'SimpleMazeFormula',
                                'bridge' => 'BridgeMazeFormula',
                                'tunnel' => 'TunnelMazeFormula',
                                'portal' => 'PortalMazeFormula' }
    X_MIN = 3
    X_MAX = 10
    Y_MIN = 2
    Y_MAX = 10
    ENDPOINT_MIN = 1
    ENDPOINT_MAX = 4
    BARRIER_MIN = 0
    BARRIER_MAX = 3

    attr_reader :background_job_id,
                :maze_type, :x, :y,
                :endpoints, :barriers, :bridges,
                :tunnels, :portals, :experiment,
                :unique_square_set

    def initialize(formula)
      @background_job_id = formula['background_job_id']
      @maze_type = formula['maze_type']
      @x = integer_value(formula['x'])
      @y = integer_value(formula['y'])
      @endpoints = integer_value(formula['endpoints'])
      @barriers = integer_value(formula['barriers'])
      @bridges = integer_value(formula['bridges'])
      @tunnels = integer_value(formula['tunnels'])
      @portals = integer_value(formula['portals'])
      @experiment = formula[:experiment] ? true : false
      @unique_square_set = if formula['unique_square_set']
                            JSON.parse(formula['unique_square_set'])
                          else
                            create_unique_square_set
                          end
    end

    def self.maze_formula_classes
      MAZE_FORMULA_CLASS_NAMES.keys.each_with_object([]) do |maze_type, maze_formula_classes|
        maze_formula_classes << maze_formula_type_to_class(maze_type)
      end
    end

    def self.maze_formula_type_to_class(type)
      class_name = 'MazeCraze::' + MAZE_FORMULA_CLASS_NAMES[type]
      Kernel.const_get(class_name) if Kernel.const_defined?(class_name)
    end

    def self.generate_formulas(background_job_id, classes = maze_formula_classes)
      new_formula_count = 0
      existed_formula_count = 0

      classes.each do |maze_class|
        formulas = formula_dimensions.each_with_object([]) do |dimensions, formulas|
          ENDPOINT_MIN.upto(ENDPOINT_MAX) do |num_endpoints|
            BARRIER_MIN.upto(BARRIER_MAX) do |num_barriers|
              next if num_endpoints == 1 && num_barriers == 0
              maze_class.generate_formulas(dimensions, num_endpoints, num_barriers) do |formula|
                formula['background_job_id'] = background_job_id
                formulas << formula
              end
            end
          end
        end

        generated_formula_stats = save_formulas!(formulas)
        new_formula_count += generated_formula_stats[:new]
        existed_formula_count += generated_formula_stats[:existed]
      end

      { new: new_formula_count, existed: existed_formula_count }
    end

    def self.formula_dimensions
      (self::X_MIN..self::X_MAX).each_with_object([]) do |dimension, dimensions|
        dimensions << { x: dimension, y: dimension -1 }
        dimensions << { x: dimension, y: dimension }
      end
    end

    def self.save_formulas!(formulas)
      new_formula_count = 0
      existed_formula_count = 0

      formulas.each do |formula|
        new_formula = MazeFormula.new(formula)
        if new_formula.exists?
          existed_formula_count += 1
        else
          new_formula.save!
          new_formula_count += 1
        end
      end

      { new: new_formula_count, existed: existed_formula_count }
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

    def self.retrieve_formula_values(id)
      sql = "SELECT * FROM maze_formulas WHERE id = $1;"
      query(sql, id)[0]
    end

    def exists?
      sql = <<~SQL
        SELECT * 
        FROM maze_formulas 
        WHERE 
        maze_type = $1 AND 
        x = $2 AND 
        y = $3 AND 
        endpoints = $4 AND 
        barriers = $5 AND 
        bridges = $6 AND 
        tunnels = $7 AND 
        portals = $8;
      SQL

      results = query(sql.gsub!("\n", ""), maze_type, x, y, endpoints,
                        barriers, bridges, tunnels, portals)

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
        (background_job_id, maze_type, unique_square_set, x, y, endpoints, barriers, bridges, tunnels, portals, experiment) 
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
      SQL

      query(sql.gsub!("\n", ""), background_job_id, maze_type, unique_square_set, x, y, endpoints,
      barriers, bridges, tunnels, portals, experiment)
    end

    # IS THERE A BETTER PLACE TO PUT THIS:
    def self.status_list
      %w(pending approved rejected)
    end

    def self.count_by_type_and_status(maze_type, status)
      sql = "SELECT count(maze_type) FROM maze_formulas WHERE maze_type = $1 AND status = $2;"
      query(sql, maze_type, status)
    end

    def self.status_list_by_maze_type(maze_type)
      sql = "SELECT id, x, y, endpoints, barriers, bridges, tunnels, portals, experiment, status FROM maze_formulas WHERE maze_type = $1 ORDER BY x, y, endpoints, barriers;"
      query(sql, maze_type)
    end

    def self.update_status(id, status)
      sql = "UPDATE maze_formulas SET status = $1 WHERE id = $2;"
      query(sql, status, id)
    end

    def generate_permutations(id)
      save_permutations(maze_permutations(id), id)
    end

    def maze_permutations(id)
      unique_square_set_permutations.each_with_object([]) do |unique_square_permutation, permutations|
        unique_squares_length = unique_square_permutation.length
        permutations << unique_square_permutation + Array.new(x * y - unique_squares_length, 'normal')
        unique_squares_length.downto(1) do |left_boundry|
          left_boundry.upto(x * y - (unique_squares_length - left_boundry) - 1) do |right_boundry|
            new_permutation = permutations.last.clone
            new_permutation[right_boundry - 1], new_permutation[right_boundry] = 'normal', new_permutation[right_boundry - 1]
            permutations << new_permutation
          end
        end
      end
    end

    def unique_square_set_permutations
      unique_square_set.permutation.to_a.each_with_object([]) do |permutation, permutations| 
        next if permutation.last == 'normal'
        permutations << permutation
      end
    end

    def save_permutations(permutations, id)
      permutations.each do |permutation|
        permutation = MazeCraze::MazePermutation.new(permutation, x, y)
        permutation.save!(id) unless permutation.exists?
      end
    end

    def generate_candidates(id)
      sql = <<~SQL
        SELECT maze_formula_set_permutations.id AS id, maze_type, x, y, endpoints, permutation 
        FROM maze_formula_set_permutations 
        LEFT JOIN maze_formulas ON maze_formula_id = maze_formulas.id 
        WHERE maze_formulas.id = $1;
      SQL

      results = query(sql.gsub!("\n", ""), id)

      results.each do |tuple|
        maze = Maze.maze_type_to_class(tuple["maze_type"]).new(tuple)
        maze.save_candidate!(tuple['id']) if maze.solutions.any?
      end
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
            body: "The width should be between #{self::X_MIN} and #{self::X_MAX} squares wide." },
        y: { title: "Valid Heights",
            body: "The width should be between #{self::Y_MIN} and #{self::Y_MAX} squares high." } }
    end

    def self.x_range
      range_message(self::X_MIN, self::X_MAX)
    end

    def self.y_range
      range_message(self::Y_MIN, self::Y_MAX)
    end

    def self.endpoint_range
      range_message(self::ENDPOINT_MIN, self::ENDPOINT_MAX)
    end

    def self.barrier_range
      range_message(self::BARRIER_MIN, self::BARRIER_MAX)
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
      (self.class::X_MIN..self.class::X_MAX).cover?(x) || experiment? && x > 0
    end

    def y_valid_input?
      (self.class::Y_MIN..self.class::Y_MAX).cover?(y) || experiment? && y > 0
    end

    def endpoints_valid_input?
      (self.class::ENDPOINT_MIN..self.class::ENDPOINT_MAX).cover?(endpoints) || experiment? && endpoints > 1
    end

    def barriers_valid_input?
      if endpoints == 1
        return true if experiment? && barriers >= 1
        (1..self.class::BARRIER_MAX).cover?(barriers)
      else
        return true if experiment? && barriers >= 0
        (self.class::BARRIER_MIN..self.class::BARRIER_MAX).cover?(barriers)
      end
    end

    def bridges_valid_input?
      bridges == 0
    end

    def tunnels_valid_input?
      tunnels == 0
    end

    def portals_valid_input?
      portals == 0
    end

    def x_validation(validation)
      if x_valid_input?
        validation[:x_validation_css] = 'is-valid'
        validation[:x_validation_feedback_css] = 'valid-feedback'
        validation[:x_validation_feedback] = 'Looks good!'
      else
        validation[:x_validation_css] = 'is-invalid'
        validation[:x_validation_feedback_css] = 'invalid-feedback'
        validation[:x_validation_feedback] = "Width must be between #{self.class::X_MIN} and #{self.class::X_MAX}."
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
        validation[:y_validation_feedback] = "Height must be between #{self.class::Y_MIN} and #{self.class::Y_MAX}."
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
          validation[:endpoint_validation_feedback] = "Number of endpoints must be between #{self.class::ENDPOINT_MIN} and #{self.class::ENDPOINT_MAX}."
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
        if barriers == 0 && endpoints == 1
          validation[:barrier_validation_feedback] = "You must have at least 1 barrier if you have 1 endpoint."
        else
          validation[:barrier_validation_feedback] = "Number of barriers must be between #{self.class::BARRIER_MIN} and #{self.class::BARRIER_MAX}."
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

    def create_unique_square_set(maze = [])
      if (count_pairs(maze, 'endpoint') / 2) != endpoints
        create_unique_square_set(maze << format_pair(maze, 'endpoint'))
      elsif (count_pairs(maze, 'portal') / 2) != portals
        create_unique_square_set(maze << format_pair(maze, 'portal'))
      elsif (count_pairs(maze, 'tunnel') / 2) != tunnels
        create_unique_square_set(maze << format_pair(maze, 'tunnel'))
      elsif maze.count('bridge') != bridges
        create_unique_square_set(maze << 'bridge')
      elsif maze.count('barrier') != barriers
        create_unique_square_set(maze << 'barrier')
      else
        maze << 'normal'
      end    
      maze
    end

    def count_pairs(maze, square_type)
      maze.count { |square| square.match(Regexp.new(Regexp.escape(square_type))) }
    end

    def format_pair(maze, square_type)
      count = count_pairs(maze, square_type)
      group = count / 2 + 1
      subgroup = count.even? ? 'a' : 'b'
      "#{square_type}_#{group}_#{subgroup}"
    end
  end

  class SimpleMazeFormula < MazeFormula
    def self.generate_formulas(dimensions, num_endpoints, num_barriers)
      return if (num_endpoints * 2 + num_barriers) > dimensions[:x] * dimensions[:y] / 2
      yield({ 'maze_type' => 'simple',
              'x' => dimensions[:x],
              'y' => dimensions[:y],
              'endpoints' => num_endpoints,
              'barriers' => num_barriers,
              'bridges' => 0,
              'tunnels' => 0,
              'portals' => 0 })
    end
  end

  class BridgeMazeFormula < MazeFormula
    BRIDGE_MIN = 1
    BRIDGE_MAX = 3

    def self.generate_formulas(dimensions, num_endpoints, num_barriers)
      BRIDGE_MIN.upto(BRIDGE_MAX) do |num_bridges|
        next if (num_endpoints * 2 + num_barriers + num_bridges) > dimensions[:x] * dimensions[:y] / 2
        yield({ 'maze_type' => 'bridge',
                'x' => dimensions[:x],
                'y' => dimensions[:y],
                'endpoints' => num_endpoints,
                'barriers' => num_barriers,
                'bridges' => num_bridges,
                'tunnels' => 0,
                'portals' => 0 })
      end
    end

    def bridges_valid_input?
      (BRIDGE_MIN..BRIDGE_MAX).cover?(bridges) || experiment? && bridges > 0
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

    def self.generate_formulas(dimensions, num_endpoints, num_barriers)
      TUNNEL_MIN.upto(TUNNEL_MAX) do |num_tunnels|
        next if (num_endpoints * 2 + num_barriers + num_tunnels * 2) > dimensions[:x] * dimensions[:y] / 2
        yield({ 'maze_type' => 'tunnel',
                'x' => dimensions[:x],
                'y' => dimensions[:y],
                'endpoints' => num_endpoints,
                'barriers' => num_barriers,
                'bridges' => 0,
                'tunnels' => num_tunnels,
                'portals' => 0 })
      end
    end

    def tunnels_valid_input?
      (TUNNEL_MIN..TUNNEL_MAX).cover?(tunnels) || experiment? && tunnels > 0
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

    def self.generate_formulas(dimensions, num_endpoints, num_barriers)
      PORTAL_MIN.upto(PORTAL_MAX) do |num_portals|
        next if (num_endpoints * 2 + num_barriers + num_portals * 2) > dimensions[:x] * dimensions[:y] / 2
        yield({ 'maze_type' => 'portal',
                'x' => dimensions[:x],
                'y' => dimensions[:y],
                'endpoints' => num_endpoints,
                'barriers' => num_barriers,
                'bridges' => 0,
                'tunnels' => 0,
                'portals' => num_portals })
      end
    end

    def portals_valid_input?
      (PORTAL_MIN..PORTAL_MAX).cover?(portals) || experiment? && portals > 0
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
end
