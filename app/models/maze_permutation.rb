class MazePermutation
  attr_reader :permutation

  def initialize(permutation, x, y)
    @permutation = permutation
    @rotate = MazeRotate.new(x, y)
    @invert = MazeInvert.new(x, y)
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
    sql = "SELECT * FROM maze_permutations WHERE permutation = $1;"
    permutation_rotations_and_inversions.each do |variation|
      results = query(sql, variation)
      return true if results.values
    end
    false
  end

  def save!(id)
    sql = "INSERT INTO maze_permutations (maze_formula_id, permutation) VALUES($1, $2);"
    query(sql, id, permutation)
  end

  private

  def query(sql, *params)
    db = DatabaseConnection.new
    results = db.query(sql, *params)
    db.disconnect
    results
  end

  def permutation_rotations_and_inversions
    [permutation] +
    rotate.all_rotations(permutation).values +
    flip.all_inversions(permutation).values
  end
end