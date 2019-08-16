module MazeCraze
  class MazePermutation
    include MazeCraze::Queryable

    attr_reader :permutation, :maze_formula_id, :background_job_id

    def initialize(permutation, maze_id, job_id, x, y)
      @permutation = permutation
      @maze_formula_id = maze_id
      @background_job_id = job_id
      @rotate = MazeCraze::MazeRotate.new(x, y)
      @invert = MazeCraze::MazeInvert.new(x, y)
    end

    # not every unique permutation is saved.
    # we only save a permutation if it doesn't exist, if the
    # permutation when rotated 90, 180, 270 degress doesn't exist,
    # and if the permutation when inverted horizontally and vertically
    # doesn't exist. Later, when the admin goes to approve a maze, s/he
    # is presented with the original permutation, along with the 90, 180,
    # and 270 rotated versions and the horizontally and vertically inverted
    # versions of the permutation, which s/he can choose to approve. That
    # way, any rotated or inverted versions can be grouped together
    # as being derivitaves of the same original permutation.
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
      sql = "INSERT INTO maze_formula_set_permutations (background_job_id, maze_formula_id, permutation) VALUES($1, $2, $3);"
      query(sql, background_job_id, maze_formula_id, permutation)
    end

    private

    attr_reader :rotate, :invert

    def each_variation
      sql = "SELECT * FROM maze_formula_set_permutations WHERE permutation = $1;"
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
