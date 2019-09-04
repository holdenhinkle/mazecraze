module MazeCraze
  class Permutation
    include MazeCraze::Queryable
    extend MazeCraze::Queryable

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
        permutation_count = 0

        permutations.each do |permutation|
          permutation_values = { 'permutation' => permutation, 
                                 'x' => formula.x,
                                 'y' => formula.y,
                                 'formula_id' => formula.id,
                                 'background_job_id' => formula.background_job_id }

          permutation = Permutation.new(permutation_values)
          next if permutation.exists?
          permutation.save!
          permutation_count += 1
        end

        permutation_count
      end

      def update_status(id, status)
        sql = "UPDATE permutations SET status = $1 WHERE formula_id = $2;"
        query(sql, status, id)
      end
    end

    attr_reader :permutation, :formula_id, :background_job_id

    def initialize(permutation)
      @permutation = permutation['permutation']
      x = permutation['x'].to_i
      y = permutation['y'].to_i
      @rotate = MazeCraze::MazeRotate.new(x, y)
      @invert = MazeCraze::MazeInvert.new(x, y)
      @formula_id = permutation['formula_id']
      @background_job_id = permutation['background_job_id']
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
      sql = "INSERT INTO permutations (background_job_id, formula_id, permutation) VALUES($1, $2, $3);"
      query(sql, background_job_id, formula_id, permutation)
    end

    def variations
      { 'original' => permutation }
        .merge(rotate.all_rotations(permutation))
        .merge(invert.all_inversions(permutation))
    end

    private

    attr_reader :rotate, :invert

    def each_variation
      sql = "SELECT * FROM permutations WHERE permutation = $1;"
      variations.values.each do |variation|
        yield(sql, variation)
      end
    end
  end
end
