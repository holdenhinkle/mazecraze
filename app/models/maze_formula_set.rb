class MazeFormulaSet
  # def initialize()
  #   @formula_set = create_set
  # end

  # def create_set
  #   maze = []
  #   (x * y).times do
  #     maze << if (count_pairs(maze, 'endpoint') / 2) != endpoints
  #               format_pair(maze, 'endpoint')
  #             elsif (count_pairs(maze, 'portal') / 2) != portals
  #               format_pair(maze, 'portal')
  #             elsif (count_pairs(maze, 'tunnel') / 2) != tunnels
  #               format_pair(maze, 'tunnel')
  #             elsif maze.count('bridge') != bridges
  #               'bridge'
  #             elsif maze.count('barrier') != barriers
  #               'barrier'
  #             else
  #               'normal'
  #             end
  #   end
  #   maze
  # end

  # def count_pairs(maze, square_type)
  #   maze.count { |square| square.match(Regexp.new(Regexp.escape(square_type))) }
  # end

  # def format_pair(maze, square_type)
  #   count = count_pairs(maze, square_type)
  #   group = count / 2 + 1
  #   subgroup = count.even? ? 'a' : 'b'
  #   "#{square_type}_#{group}_#{subgroup}"
  # end
end
