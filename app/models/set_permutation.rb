module MazeCraze
  class SetPermutation
    include MazeCraze::Queryable

    PERMUTATION_STATUSES = ['queued', 'pending', 'completed'].freeze

    class << self
      def generate_permutations(formula)
        permutations = []
        set_permutations(formula.set).each do |set|
          set_length = set.length
          permutations << set + Array.new(formula.x * formula.y - set_length, 'normal')
          set_length.downto(1) do |left_boundry|
            left_boundry.upto(formula.x * formula.y - (set_length - left_boundry) - 1) do |right_boundry|
              new_permutation = permutations.last.clone
              new_permutation[right_boundry - 1], new_permutation[right_boundry] = 'normal', new_permutation[right_boundry - 1]
              permutations << new_permutation
            end
          end
        end
        save_permutations(permutations, formula)
      end

      def set_permutations(set)
        set.permutation.to_a.each_with_object([]) do |set, sets|
          next if set.last == 'normal'
          sets << set
        end
      end

      def save_permutations(permutations, formula)
        permutations.each do |permutation|
          permutation = SetPermutation.new(permutation, formula.id, formula.background_job_id, formula.x, formula.y)
          permutation.save! unless permutation.exists?
        end
      end
    end

    attr_reader :permutation, :maze_formula_id, :background_job_id

    def initialize(permutation, maze_id, job_id, x, y)
      @permutation = permutation
      @maze_formula_id = maze_id
      @background_job_id = job_id
      @rotate = MazeCraze::MazeRotate.new(x, y)
      @invert = MazeCraze::MazeInvert.new(x, y)
    end

    def exists?
      exists = false
      db = DatabaseConnection.new
      each_variation do |sql, variation|
        results = db.query(sql, variation)
        if results.values.any?
          exists = true
          break
        end
      end
      db.disconnect
      exists
    end

    def save!
      sql = "INSERT INTO set_permutations (background_job_id, maze_formula_id, permutation) VALUES($1, $2, $3);"
      query(sql, background_job_id, maze_formula_id, permutation)
    end

    private

    attr_reader :rotate, :invert

    def each_variation
      sql = "SELECT * FROM set_permutations WHERE permutation = $1;"
      permutation_rotations_and_inversions.each do |variation|
        yield(sql, variation)
      end
    end

    def permutation_rotations_and_inversions
      [permutation] +
        rotate.all_rotations(permutation).values +
        invert.all_inversions(permutation).values
    end
  end
end
