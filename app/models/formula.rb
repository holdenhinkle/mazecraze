module MazeCraze
  class Formula
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    MAZE_FORMULA_CLASS_NAMES = { 'simple' => 'SimpleFormula',
                                 'bridge' => 'BridgeFormula',
                                 'tunnel' => 'TunnelFormula',
                                 'portal' => 'PortalFormula' }

    FORMULA_STATUSES = ['queued', 'pending', 'completed'].freeze

    # set and manage maze formula class constraints
    class << self
      def set_maze_formula_constraints
        class << self
          attr_accessor :x_min, :x_max, :y_min, :y_max,
                        :endpoint_min, :endpoint_max,
                        :barrier_min, :barrier_max,
                        :other_squares_to_normal_squares_ratio
        end

        case self.to_s
        when 'bridge'
          class << self
            attr_accessor :bridge_min, :bridge_max
          end
        when 'tunnel'
          class << self
            attr_accessor :tunnel_min, :tunnel_max
          end
        when 'portal'
          class << self
            attr_accessor :portal_min, :portal_max
          end
        end

        @x_min = nil
        @x_max = nil
        @y_min = nil
        @y_max = nil
        @endpoint_min = nil
        @endpoint_max = nil
        @barrier_min = nil
        @barrier_max = nil
        @barrier_min = nil
        @other_squares_to_normal_squares_ratio = nil
        @bridge_min = nil if self.to_s == 'bridge'
        @bridge_max = nil if self.to_s == 'bridge'
        @tunnel_min = nil if self.to_s == 'tunnel'
        @tunnel_max = nil if self.to_s == 'tunnel'
        @portal_min = nil if self.to_s == 'portal'
        @portal_max = nil if self.to_s == 'portal'

        query_arguments = [
          "#{self.to_s}_formula_x_min", "#{self.to_s}_formula_x_max",
          "#{self.to_s}_formula_y_min", "#{self.to_s}_formula_y_max",
          "#{self.to_s}_formula_endpoint_min", "#{self.to_s}_formula_endpoint_max",
          "#{self.to_s}_formula_barrier_min", "#{self.to_s}_formula_barrier_max",
          "#{self.to_s}_formula_other_squares_to_normal_squares_ratio"
        ]

        case self.to_s
        when 'bridge'
          query_arguments.concat(["#{self.to_s}_formula_bridge_min", "#{self.to_s}_formula_bridge_max"])
        when 'tunnel'
          query_arguments.concat(["#{self.to_s}_formula_tunnel_min", "#{self.to_s}_formula_tunnel_max"])
        when 'portal'
          query_arguments.concat(["#{self.to_s}_formula_portal_min", "#{self.to_s}_formula_portal_max"])
        end

        sql = 'SELECT * FROM settings WHERE'
        query_arguments.length.times do |number|
          number += 1
          sql << " name = $#{number}"
          sql << ' OR' unless query_arguments.length == number
        end
        sql << ';'
              
        settings = query(sql, *query_arguments)
    
        settings.each do |setting|
          case setting['name']
          when "#{self.to_s}_formula_x_min"
            self.x_min = setting['integer_value'].to_i
          when "#{self.to_s}_formula_x_max"
            self.x_max = setting['integer_value'].to_i
          when "#{self.to_s}_formula_y_min"
            self.y_min = setting['integer_value'].to_i
          when "#{self.to_s}_formula_y_max"
            self.y_max = setting['integer_value'].to_i
          when "#{self.to_s}_formula_endpoint_min"
            self.endpoint_min = setting['integer_value'].to_i
          when "#{self.to_s}_formula_endpoint_max"
            self.endpoint_max = setting['integer_value'].to_i
          when "#{self.to_s}_formula_barrier_min"
            self.barrier_min = setting['integer_value'].to_i
          when "#{self.to_s}_formula_barrier_max"
            self.barrier_max = setting['integer_value'].to_i
          when "#{self.to_s}_formula_other_squares_to_normal_squares_ratio"
            self.other_squares_to_normal_squares_ratio = setting['integer_value'].to_f
          when "#{self.to_s}_formula_bridge_min"
            self.bridge_min = setting['integer_value'].to_i
          when "#{self.to_s}_formula_bridge_max"
            self.bridge_max = setting['integer_value'].to_i
          when "#{self.to_s}_formula_tunnel_min"
            self.tunnel_min = setting['integer_value'].to_i
          when "#{self.to_s}_formula_tunnel_max"
            self.tunnel_max = setting['integer_value'].to_i
          when "#{self.to_s}_formula_portal_min"
            self.portal_min = setting['integer_value'].to_i
          when "#{self.to_s}_formula_portal_max"
            self.portal_max = setting['integer_value'].to_i
          end
        end
      end

      def constraints
        settings = { simple: {}, bridge: {}, tunnel: {}, portal: {} }
        
        sql = 'SELECT name, integer_value FROM settings WHERE name LIKE $1 AND integer_value IS NOT NULL;'
        query(sql, "%formula%").each do |setting|
          if setting['name'].include?('simple')
            settings[:simple][setting['name'].gsub('simple_formula_', '').to_sym] = setting['integer_value'].to_i
          elsif setting['name'].include?('bridge')
            settings[:bridge][setting['name'].gsub('bridge_formula_', '').to_sym] = setting['integer_value'].to_i
          elsif setting['name'].include?('tunnel')
            settings[:tunnel][setting['name'].gsub('tunnel_formula_', '').to_sym] = setting['integer_value'].to_i
          elsif setting['name'].include?('portal')
            settings[:portal][setting['name'].gsub('portal_formula_', '').to_sym] = setting['integer_value'].to_i
          end
        end

        sql = 'SELECT name, decimal_value FROM settings WHERE name LIKE $1 AND decimal_value IS NOT NULL;'
        query(sql, "%formula%").each do |setting|
          if setting['name'].include?('simple')
            settings[:simple][setting['name'].gsub('simple_formula_', '').to_sym] = setting['decimal_value'].to_f
          elsif setting['name'].include?('bridge')
            settings[:bridge][setting['name'].gsub('bridge_formula_', '').to_sym] = setting['decimal_value'].to_f
          elsif setting['name'].include?('tunnel')
            settings[:tunnel][setting['name'].gsub('tunnel_formula_', '').to_sym] = setting['decimal_value'].to_f
          elsif setting['name'].include?('portal')
            settings[:portal][setting['name'].gsub('portal_formula_', '').to_sym] = setting['decimal_value'].to_f
          end
        end

        settings
      end

      def valid_constraints?(constraints)
        correct_constraint_types(constraints)

        if self.to_s == 'simple'
          general_constraints_valid?(constraints)
        else
          general_constraints_valid?(constraints) && formula_type_constraints_valid?(constraints)
        end
      end

      def correct_constraint_types(constraints)
        constraints.each do |name, value|
          next if name == 'formula_type'

          if name == 'ratio'
            constraints[name] = value.to_f
          else
            constraints[name] = value.to_i
          end
        end
      end

      def general_constraints_valid?(constraints)
        [min_constraint_valid?(constraints['x_min'], constraints['x_max'], 'x'),
        max_constraint_valid?(constraints['x_min'], constraints['x_max'], 'x'),
        min_constraint_valid?(constraints['y_min'], constraints['y_max'], 'y'),
        max_constraint_valid?(constraints['y_min'], constraints['y_max'], 'y'),
        min_constraint_valid?(constraints['endpoint_min'], constraints['endpoint_max'], 'endpoint'),
        max_constraint_valid?(constraints['endpoint_min'], constraints['endpoint_max'], 'endpoint'),
        min_constraint_valid?(constraints['barrier_min'], constraints['barrier_max'], 'barrier'),
        max_constraint_valid?(constraints['barrier_min'], constraints['barrier_max'], 'barrier'),
        ratio_valid?(constraints['ratio'])].all?
      end

      def formula_type_constraints_valid?(constraints)
        case self.to_s
        when 'bridge'
          [min_constraint_valid?(constraints['bridge_min'], constraints['bridge_max'], 'bridge'),
          max_constraint_valid?(constraints['bridge_min'], constraints['bridge_max'], 'bridge')].all?
        when 'tunnel'
          [min_constraint_valid?(constraints['tunnel_min'], constraints['tunnel_max'], 'tunnel'),
          max_constraint_valid?(constraints['tunnel_min'], constraints['tunnel_max'], 'tunnel')].all?
        when 'portal'
          [min_constraint_valid?(constraints['portal_min'], constraints['portal_max'], 'tunnel'),
          max_constraint_valid?(constraints['portal_min'], constraints['portal_max'], 'tunnel')].all?
        end
      end

      def min_constraint_valid?(min, max, type)
        return min > -1 && min <= max if type == 'barrier'
        min > 0 && min <= max
      end

      def max_constraint_valid?(min, max, type)
        return max > 0 && max >= min if type == 'barrier'
        max > 1 && max >= min
      end

      def min_constraint_invalid?(min, max, type)
        !min_constraint_valid?(min, max, type)
      end

      def max_constraint_invalid?(min, max, type)
        !max_constraint_valid?(min, max, type)
      end

      def ratio_valid?(ratio)
        ratio > 0 && ratio < 1
      end

      def ratio_invalid?(ratio)
        !ratio_valid?(ratio)
      end

      def constraint_validation(constraints)
        validation = {}

        validation_lists = [method(:general_constraints_validation), 
                            method(:formula_type_constraints_validation)]
    
        validation_lists.each do |list|
          list.call(constraints) do |type, min_or_max, min, max, ratio|

            if type == 'ratio' && ratio_invalid?(ratio)
              ratio_constraint_validation(constraints, validation, ratio)
            elsif type != 'ratio' && public_send(min_or_max == 'min' ? 'min_constraint_invalid?' : 'max_constraint_invalid?', min, max, type)
              not_ratio_constraint_validation(constraints, validation, type, min_or_max, min, max)
            end
          end
        end

        validation
      end

      def general_constraints_validation(constraints)
        list = [['x', 'min', constraints['x_min'], constraints['x_max']],
                ['x', 'max', constraints['x_min'], constraints['x_max']],
                ['y', 'min', constraints['y_min'], constraints['y_max']],
                ['y', 'max', constraints['y_min'], constraints['y_max']],
                ['endpoint', 'min', constraints['endpoint_min'], constraints['endpoint_max']],
                ['endpoint', 'max', constraints['endpoint_min'], constraints['endpoint_max']],
                ['barrier', 'min', constraints['barrier_min'], constraints['barrier_max']],
                ['barrier', 'max', constraints['barrier_min'], constraints['barrier_max']],
                ['ratio', nil, nil, nil, constraints['ratio']]]

        list.each { |constraint_info| yield(*constraint_info) }
      end

      def formula_type_constraints_validation(constraints)
        list = case self.to_s
              when 'bridge'
                [['bridge', 'min', constraints['bridge_min'], constraints['bridge_max']],
                  ['bridge', 'max', constraints['bridge_min'], constraints['bridge_max']]]
              when 'tunnel'
                [['tunnel', 'min', constraints['tunnel_min'], constraints['tunnel_max']],
                  ['tunnel', 'max', constraints['tunnel_min'], constraints['tunnel_max']]]
              when 'portal'
                [['portal', 'min', constraints['portal_min'], constraints['portal_max']],
                  ['portal', 'max', constraints['portal_min'], constraints['portal_max']]]
              else
                []
              end
        
        list.each { |constraint_info| yield(*constraint_info) }
      end

      def ratio_constraint_validation(constraints, validation, ratio)
        validation["#{constraints['formula_type']}_ratio_validation_css"] = 'is-invalid'
        validation["#{constraints['formula_type']}_ratio_feedback_css"] = 'invalid-feedback'
        validation["#{constraints['formula_type']}_ratio_feedback"] =
          'The value must be between 0.01 and 0.99.'
      end

      def not_ratio_constraint_validation(constraints, validation, type, min_or_max, min, max)
        validation["#{constraints['formula_type']}_#{type}_#{min_or_max}_validation_css"] = 'is-invalid'
        validation["#{constraints['formula_type']}_#{type}_#{min_or_max}_feedback_css"] = 'invalid-feedback'
        feedback = "#{constraints['formula_type']}_#{type}_#{min_or_max}_feedback"
        constraint_to_validate = min_or_max == 'min' ? min : max
        
        if type == 'barrier' && constraint_to_validate < 0
          validation[feedback] = "Value must be greater than or equal to 0."
        elsif type != 'barrier' && constraint_to_validate < 1
          validation[feedback] = "Value must be greater than or equal to 1."
        elsif min_or_max == 'min'
          validation[feedback] = "Value must be less than or equal to #{type} max value."
        elsif min_or_max == 'max'
          validation[feedback] = "Value must be greater than or equal to #{type} min value."
        end
      end

      def update_constraints(constraints)
        formula_class = formula_type_to_class(constraints['formula_type'])
        name_partial = "#{constraints['formula_type']}_formula"

        constraints.each do |constraint, value|
          next if constraint == 'formula_type'

          formula_class.update_constraint_in_class(constraint, value)
          update_constraint_in_db(name_partial, constraint, value)
        end
      end

      def update_constraint_in_class(constraint, value)
        case constraint
        when "x_min"
          self.x_min = value
        when "x_max"
          self.x_max = value
        when "y_min"
          self.y_min = value
        when "y_max"
          self.y_max = value
        when "endpoint_min"
          self.endpoint_min = value
        when "endpoint_max"
          self.endpoint_max = value
        when "barrier_min"
          self.barrier_min = value
        when "barrier_max"
          self.barrier_max = value
        when "other_squares_to_normal_squares_ratio"
          self.other_squares_to_normal_squares_ratio = value
        when "bridge_min"
          self.bridge_min = value
        when "bridge_max"
          self.bridge_max = value
        when "tunnel_min"
          self.tunnel_min = value
        when "tunnel_max"
          self.tunnel_max = value
        when "portal_min"
          self.portal_min = value
        when "portal_max"
          self.portal_max = value
        end
      end

      def update_constraint_in_db(name_partial, constraint, value)
        if constraint == 'ratio'
          sql = 'UPDATE settings SET decimal_value = $1 WHERE name = $2;'
          query(sql, value, "#{name_partial}_other_squares_to_normal_squares_ratio")
        else
          sql = 'UPDATE settings SET integer_value = $1 WHERE name = $2;'
          query(sql, value, "#{name_partial}_#{constraint}")
        end
      end

      # get class(es)
      def maze_formula_classes
        maze_formula_classes = []

        MAZE_FORMULA_CLASS_NAMES.keys.each do |maze_type|
          maze_formula_classes << formula_type_to_class(maze_type)
        end

        maze_formula_classes
      end

      def formula_type_to_class(type)
        class_name = 'MazeCraze::' + MAZE_FORMULA_CLASS_NAMES[type]
        Kernel.const_get(class_name) if Kernel.const_defined?(class_name)
      end

      # auto-generate maze formulas
      def generate_formulas(background_job_id, classes)
        classes = [classes] if !classes.is_a? Array

        new_count = 0
        existed_count = 0

        classes.each do |maze_class|
          formulas = maze_class.formula_dimensions.each_with_object([]) do |dimensions, formulas|
            maze_class.endpoint_min.upto(maze_class.endpoint_max) do |num_endpoints|
              maze_class.barrier_min.upto(maze_class.barrier_max) do |num_barriers|
                next if num_endpoints == 1 && num_barriers == 0
                maze_class.generate_formulas(dimensions, num_endpoints, num_barriers) do |formula|
                  formula['background_job_id'] = background_job_id
                  formulas << formula
                end
              end
            end
          end

          results = save_formulas(formulas)

          new_count += results[:new]
          existed_count += results[:existed]
        end

        { new: new_count, existed: existed_count }
      end

      def formula_dimensions
        (self.x_min..self.x_max).each_with_object([]) do |dimension, dimensions|
          dimensions << { x: dimension, y: dimension -1 }
          dimensions << { x: dimension, y: dimension }
        end
      end

      def save_formulas(formulas)
        new_formula_count = 0
        existed_formula_count = 0

        formulas.each do |formula|
          new_formula =  formula_type_to_class(formula['maze_type']).new(formula)
          if new_formula.exists?
            existed_formula_count += 1
          else
            new_formula.save!
            new_formula_count += 1
          end
        end

        { new: new_formula_count, existed: existed_formula_count }
      end

      # generate new maze formula page popups
      def form_popovers
        popovers = build_popovers # rename build_popovers

        popovers.keys.each do |element|
          next if element == :maze_types
          popovers[element][:body] << "<p><strong>Valid Ranges:</strong></p>"

          maze_formula_classes.each do |formula_class|
            range = case element
                    when :x
                      formula_class.x_range
                    when :y
                      formula_class.y_range
                    when :endpoint
                      formula_class.endpoint_range
                    when :barrier
                      formula_class.barrier_range
                    when :bridge
                      formula_class.bridge_range
                    when :tunnel
                      formula_class.tunnel_range
                    when :portal
                      formula_class.portal_range
                    end
            
            popovers[element][:body] << "<p><strong>#{formula_class.to_s.capitalize}</strong> Maze: "
            popovers[element][:body] << if range == [0, 0]
                                          "not allowed"
                                        else
                                          "between #{range.first} and #{range.last}"
                                        end
            popovers[element][:body] << "</p>"
          end
        end

        popovers
      end

      def build_popovers # rename build_popovers
        MazeCraze::Maze.types_popover.merge(MazeCraze::MazeSquare.types_popover).merge(maze_dimensions_popover)
      end

      def maze_dimensions_popover
        { x: { title: 'Valid Widths', body: "<p>Here's a description of the width field.</p>" },
          y: { title: 'Valid Heights', body: "<p>Here's a description of the height field.</p>" } }
      end

      # misc class methods
      def formula_values(id)
        sql = "SELECT * FROM formulas WHERE id = $1;"
        query(sql, id)
      end

      def count_by_type_and_status(maze_type, status)
        sql = "SELECT count(maze_type) FROM formulas WHERE maze_type = $1 AND status = $2;"
        query(sql, maze_type, status)
      end

      def status_list_by_maze_type(maze_type)
        sql = "SELECT id, x, y, endpoints, barriers, bridges, tunnels, portals, experiment, status FROM formulas WHERE maze_type = $1 ORDER BY x, y, endpoints, barriers;"
        query(sql, maze_type)
      end

      def update_status(id, status)
        sql = "UPDATE formulas SET status = $1 WHERE id = $2;"
        query(sql, status, id)
      end

      def x_range
        [x_min, x_max]
      end
  
      def y_range
        [y_min, y_max]
      end
  
      def endpoint_range
        [endpoint_min, endpoint_max]
      end
  
      def barrier_range
        [barrier_min, barrier_max]
      end
  
      def bridge_range
        [0, 0]
      end
  
      def tunnel_range
        [0, 0]
      end
  
      def portal_range
        [0, 0]
      end
    end

    attr_reader :id, :background_job_id,
                :maze_type, :x, :y,
                :endpoints, :barriers, :experiment,
                :set

    attr_accessor :id

    def initialize(formula)
      @id = formula['id']
      @background_job_id = formula['background_job_id']
      @maze_type = formula['maze_type']
      @x = integer_value(formula['x'])
      @y = integer_value(formula['y'])
      @endpoints = integer_value(formula['endpoints'])
      @barriers = integer_value(formula['barriers'])
      @experiment = formula[:experiment] ? true : false
      @set = if formula['set']
                            JSON.parse(formula['set'])
                          else
                            create_set
                          end
    end

    def experiment?
      experiment
    end

    def valid?(input)
      [x_valid_input?(input['x']),
      y_valid_input?(input['y']),
      endpoints_valid_input?(input['endpoints']),
      barriers_valid_input?(input['barriers']),
      bridges_valid_input?(input['bridges']),
      tunnels_valid_input?(input['tunnels']),
      portals_valid_input?(input['portals'])].all?
    end

    def experiment_valid?
      [barriers_valid_input?('_'),
      bridges_valid_input?('_'),
      tunnels_valid_input?('_'),
      portals_valid_input?('_')].all?
    end

    def validation(input)
      validation = { validation: true }

      items = ['x', 'y', 'endpoints', 'barriers', 'bridges', 'tunnels', 'portals']

      items.each do |item|
        generate_validation(input[item], validation, item)
      end

      validation
    end

    def generate_validation(input, validation, item)
      validation_css = "#{item}_validation_css"
      validation_feedback_css = "#{item}_validation_feedback_css"
      validation_feedback = "#{item}_validation_feedback"

      if public_send("#{item}_valid_input?", input)
        validation[validation_css] = 'is-valid'
        validation[validation_feedback_css] = 'valid-feedback'
        validation[validation_feedback] = 'Looks good!'
      else
        validation[validation_css] = 'is-invalid'
        validation[validation_feedback_css] = 'invalid-feedback'
        validation[validation_feedback] = validation_invalid_feedback(item)
      end
    end

    def x_valid_input?(_)
      (self.class.x_min..self.class.x_max).cover?(x) || experiment? && x > 0
    end

    def y_valid_input?(_)
      (self.class.y_min..self.class.y_max).cover?(y) || experiment? && y > 0
    end

    def endpoints_valid_input?(_)
      (self.class.endpoint_min..self.class.endpoint_max).cover?(endpoints) || experiment? && endpoints > 1
    end

    def barriers_valid_input?(_)
      if endpoints == 1
        return true if experiment? && barriers >= 1
        (1..self.class.barrier_max).cover?(barriers)
      else
        return true if experiment? && barriers >= 0
        (self.class.barrier_min..self.class.barrier_max).cover?(barriers)
      end
    end

    def bridges_valid_input?(input)
      input.empty? || input == '0'
    end

    def tunnels_valid_input?(input)
      input.empty? || input == '0'
    end

    def portals_valid_input?(input)
      input.empty? || input == '0'
    end

    def validation_invalid_feedback(item)
      case item
      when 'x' then x_validation_invalid_feedback
      when 'y' then y_validation_invalid_feedback
      when 'endpoints' then endpoints_validation_invalid_feedback
      when 'barriers' then barriers_validation_invalid_feedback
      when 'bridges' then bridges_validation_invalid_feedback
      when 'tunnels' then tunnels_validation_invalid_feedback
      when 'portals' then portals_validation_invalid_feedback
      end
    end

    def x_validation_invalid_feedback
      "Width must be between #{self.class.x_min} and #{self.class.x_max}."
    end

    def y_validation_invalid_feedback
      "Height must be between #{self.class.y_min} and #{self.class.y_max}."
    end

    def endpoints_validation_invalid_feedback
      if experiment?
        "Experiments must have at least 1 endpoint."
      else
        "Number of endpoints must be between #{self.class.endpoint_min} and #{self.class.endpoint_max}."
      end
    end

    def barriers_validation_invalid_feedback
      if barriers == 0 && endpoints == 1
        "You must have at least 1 barrier if you have 1 endpoint."
      else
        "Number of barriers must be between #{self.class.barrier_min} and #{self.class.barrier_max}."
      end
    end

    def bridges_validation_invalid_feedback
      'Bridge squares are only allowed on bridge mazes.'
    end

    def tunnels_validation_invalid_feedback
      'Tunnel squares are only allowed on tunnel mazes.'
    end

    def portals_validation_invalid_feedback
      'Portal squares are only allowed on portal mazes.'
    end

    private

    def integer_value(value)
      value == '' ? 0 : value.to_i
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

  class SimpleFormula < Formula
    def self.to_s
      'simple'
    end

    set_maze_formula_constraints

    def self.generate_formulas(dimensions, num_endpoints, num_barriers)
      return if (num_endpoints * 2 + num_barriers) / 
                (dimensions[:x] * dimensions[:y]) > 
                other_squares_to_normal_squares_ratio

      yield({ 'maze_type' => 'simple',
              'x' => dimensions[:x],
              'y' => dimensions[:y],
              'endpoints' => num_endpoints,
              'barriers' => num_barriers,
              'bridges' => 0,
              'tunnels' => 0,
              'portals' => 0 })
    end

    def create_set(maze = [])
      if (count_pairs(maze, 'endpoint') / 2) != endpoints
        create_set(maze << format_pair(maze, 'endpoint'))
      elsif maze.count('barrier') != barriers
        create_set(maze << 'barrier')
      else
        maze << 'normal'
      end
      maze
    end

    def exists?
      sql = <<~SQL
        SELECT * 
        FROM formulas 
        WHERE 
        maze_type = $1 AND 
        x = $2 AND 
        y = $3 AND 
        endpoints = $4 AND 
        barriers = $5;
      SQL

      results = query(sql.gsub!("\n", ""), maze_type, x, y, endpoints, barriers)

      return false if results.values.empty?
      true
    end

    def save!
      sql = <<~SQL
        INSERT INTO formulas 
        (background_job_id, maze_type, set, x, y, endpoints, barriers, experiment) 
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8);
      SQL

      self.id = query(sql.gsub!("\n", ""), background_job_id, maze_type, set, x, y, endpoints,
      barriers, experiment)
    end
  end

  class BridgeFormula < Formula
    def self.to_s
      'bridge'
    end
    
    set_maze_formula_constraints

    def self.bridge_range
      [bridge_min, bridge_max]
    end

    def self.generate_formulas(dimensions, num_endpoints, num_barriers)
      bridge_min.upto(bridge_max) do |num_bridges|
        next if (num_endpoints * 2 + num_barriers + num_bridges) / 
        (dimensions[:x] * dimensions[:y]) > 
        other_squares_to_normal_squares_ratio

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

    attr_reader :bridges

    def initialize(formula)
      @bridges = integer_value(formula['bridges'])
      super(formula)
    end

    def bridges_valid_input?(_)
      (self.class.bridge_min..self.class.bridge_max).cover?(bridges) || experiment? && bridges > 0
    end

    def bridges_validation_invalid_feedback
      if experiment?
        "Bridge experiments must have at least 1 bridge."
      else
        "Number of bridges must be between #{self.class.bridge_min} and #{self.class.bridge_max}."
      end
    end

    def create_set(maze = [])
      if (count_pairs(maze, 'endpoint') / 2) != endpoints
        create_set(maze << format_pair(maze, 'endpoint'))
      elsif maze.count('bridge') != bridges
        create_set(maze << 'bridge')
      elsif maze.count('barrier') != barriers
        create_set(maze << 'barrier')
      else
        maze << 'normal'
      end
      maze
    end

    def exists?
      sql = <<~SQL
        SELECT * 
        FROM formulas 
        WHERE 
        maze_type = $1 AND 
        x = $2 AND 
        y = $3 AND 
        endpoints = $4 AND 
        barriers = $5 AND 
        bridges = $6;
      SQL

      results = query(sql.gsub!("\n", ""), maze_type, x, y, endpoints, barriers, bridges)

      return false if results.values.empty?
      true
    end

    def save!
      sql = <<~SQL
        INSERT INTO formulas 
        (background_job_id, maze_type, set, x, y, endpoints, barriers, bridges, experiment) 
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);
      SQL

      query(sql.gsub!("\n", ""), background_job_id, maze_type, set, x, y, endpoints,
      barriers, bridges, experiment)
    end
  end

  class TunnelFormula < Formula
    def self.to_s
      'tunnel'
    end
        
    set_maze_formula_constraints

    def self.tunnel_range
      [tunnel_min, tunnel_max]
    end

    def self.generate_formulas(dimensions, num_endpoints, num_barriers)
      tunnel_min.upto(tunnel_max) do |num_tunnels|
        next if ((num_endpoints * 2) + num_barriers + (num_tunnels * 2)) / 
        (dimensions[:x] * dimensions[:y]) > 
        other_squares_to_normal_squares_ratio

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

    attr_reader :tunnels

    def initialize(formula)
      @tunnels = integer_value(formula['tunnels'])
      super(formula)
    end

    def tunnels_valid_input?(_)
      (self.class.tunnel_min..self.class.tunnel_max).cover?(tunnels) || experiment? && tunnels > 0
    end

    def tunnels_validation_invalid_feedback
      if experiment?
        "Tunnel experiments must have at least 1 tunnel."
      else
        "Number of tunnels must be between #{self.class.tunnel_min} and #{self.class.tunnel_max}."
      end
    end

    def create_set(maze = [])
      if (count_pairs(maze, 'endpoint') / 2) != endpoints
        create_set(maze << format_pair(maze, 'endpoint'))
      elsif (count_pairs(maze, 'tunnel') / 2) != tunnels
        create_set(maze << format_pair(maze, 'tunnel'))
      elsif maze.count('barrier') != barriers
        create_set(maze << 'barrier')
      else
        maze << 'normal'
      end
      maze
    end

    def exists?
      sql = <<~SQL
        SELECT * 
        FROM formulas 
        WHERE 
        maze_type = $1 AND 
        x = $2 AND 
        y = $3 AND 
        endpoints = $4 AND 
        barriers = $5 AND 
        tunnels = $6;
      SQL

      results = query(sql.gsub!("\n", ""), maze_type, x, y, endpoints, barriers, tunnels)

      return false if results.values.empty?
      true
    end

    def save!
      sql = <<~SQL
        INSERT INTO formulas 
        (background_job_id, maze_type, set, x, y, endpoints, barriers, tunnels, experiment) 
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);
      SQL

      query(sql.gsub!("\n", ""), background_job_id, maze_type, set, x, y, endpoints,
      barriers, tunnels, experiment)
    end
  end

  class PortalFormula < Formula
    def self.to_s
      'portal'
    end
    
    set_maze_formula_constraints

    def self.portal_range
      [portal_min, portal_max]
    end

    def self.generate_formulas(dimensions, num_endpoints, num_barriers)
      portal_min.upto(portal_max) do |num_portals|
        next if ((num_endpoints * 2) + num_barriers + (num_portals * 2)) / 
        (dimensions[:x] * dimensions[:y]) > 
        other_squares_to_normal_squares_ratio

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

    attr_reader :portals

    def initialize(formula)
      @portals = integer_value(formula['portals'])
      super(formula)
    end

    def portals_valid_input?(_)
      (self.class.portal_min..self.class.portal_max).cover?(portals) || experiment? && portals > 0
    end

    def portals_validation_invalid_feedback
      if experiment?
        "Portal experiments must have at least 1 portal."
      else
        "Number of portals must be between #{self.class.portal_min} and #{self.class.portal_max}."
      end
    end

    def create_set(maze = [])
      if (count_pairs(maze, 'endpoint') / 2) != endpoints
        create_set(maze << format_pair(maze, 'endpoint'))
      elsif (count_pairs(maze, 'portal') / 2) != portals
        create_set(maze << format_pair(maze, 'portal'))
      elsif maze.count('barrier') != barriers
        create_set(maze << 'barrier')
      else
        maze << 'normal'
      end
      maze
    end

    def exists?
      sql = <<~SQL
        SELECT * 
        FROM formulas 
        WHERE 
        maze_type = $1 AND 
        x = $2 AND 
        y = $3 AND 
        endpoints = $4 AND 
        barriers = $5 AND 
        portals = $6;
      SQL

      results = query(sql.gsub!("\n", ""), maze_type, x, y, endpoints, barriers, portals)

      return false if results.values.empty?
      true
    end

    def save!
      sql = <<~SQL
        INSERT INTO formulas 
        (background_job_id, maze_type, set, x, y, endpoints, barriers, portals, experiment) 
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);
      SQL

      query(sql.gsub!("\n", ""), background_job_id, maze_type, set, x, y, endpoints,
      barriers, portals, experiment)
    end
  end
end
