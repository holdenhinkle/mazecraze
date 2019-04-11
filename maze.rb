require 'pry'
require 'yaml'
require 'fileutils'
require 'json'
require 'date'

require_relative 'rotator'
require_relative 'inverter'
require_relative "database_persistence"
require_relative 'navigate'
require_relative 'solve'

# MAZE - DONE
board = { type: :simple, x: 3, y: 2, endpoints: 1, barriers: 1, level: 1 }

# BRIDGE MAZE - DONE
# board = { type: :bridge, x: 4, y: 4, endpoints: 1, barriers: 1, bridges: 1, level: 1 }

# TUNNEL MAZE - DONE
# 1 tunnel, 1 barrier
# board = { type: :tunnel, x: 3, y: 3, endpoints: 1, barriers: 1, tunnels: 1, level: 1 }

# PORTAL MAZE - DONE
# 1 portal, 1 barrier
# board = { type: :portal, x: 3, y: 3, endpoints: 1, barriers: 1, portals: 1, level: 1 }

Board.new(board)
