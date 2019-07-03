module MazeCraze
  class MazePermutation
    include MazeCraze::Queryable

    attr_reader :permutation

    def initialize(permutation, x, y)
      @permutation = permutation
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

    def save!(id)
      sql = "INSERT INTO maze_formula_set_permutations (maze_formula_id, permutation) VALUES($1, $2);"
      query(sql, id, permutation)
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
