class MazeSquare
  attr_reader :type, :index
  attr_accessor :status

  def initialize(type, status, index)
    @status = status
    @type = type
    @index = index
  end

  def self.types_popovers
    popover_content = {}
    MazeSquare.descendants.each do |square_name|
      next if square_name.to_s == 'PairSquare'
      popover_content[square_name.to_symbol] = square_name.popover
    end
    popover_content
  end

  def taken?
    return true if status == :taken
    false
  end

  def not_taken?
    !taken?
  end

  def taken!
    self.status = :taken
  end

  def start_square?
    type == :endpoint && subgroup == 'a'
  end

  def finish_square?
    type == :endpoint && subgroup == 'b'
  end

  def normal_square?
    type == :normal
  end

  def barrier_square?
    type == :barrier
  end

  def bridge_square?
    type == :bridge
  end

  def endpoint_square?
    type == :endpoint
  end

  def tunnel_square?
    type == :tunnel
  end

  def portal_square?
    type == :portal
  end
end

class BarrierSquare < MazeSquare
  def self.to_symbol
    :barrier
  end

  def self.popover
    { title: "The Barrier Square", body: "Here's a description of barrier squares."}
  end
end

class BridgeSquare < MazeSquare
  attr_accessor :horizontal_taken, :vertical_taken

  def initialize(type, status, index)
    super(type, status, index)
    @horizontal_taken = false
    @vertical_taken = false
  end

  def self.to_symbol
    :bridge
  end

  def self.popover
    { title: "The Bridge Square", body: "Here's a description of bridge squares."}
  end

  def vertical_taken?
    vertical_taken
  end

  def vertical_not_taken?
    !vertical_taken
  end

  def vertical_taken!
    self.vertical_taken = true
  end

  def horizontal_taken?
    horizontal_taken
  end

  def horizontal_not_taken?
    !horizontal_taken
  end

  def horizontal_taken!
    self.horizontal_taken = true
  end
end

class PairSquare < MazeSquare
  attr_reader :group, :subgroup

  def initialize(type, status, group, subgroup, index)
    super(type, status, index)
    @group = group
    @subgroup = subgroup
  end
end

class EndpointSquare < PairSquare
  def self.to_symbol
    :endpoint
  end

  def self.popover
    { title: "The Endpoint Square", body: "Here's a description of endpoint squares."}
  end
end

class TunnelSquare < PairSquare
  def self.to_symbol
    :tunnel
  end

  def self.popover
    { title: "The Tunnel Square", body: "Here's a description of tunnel squares."}
  end
end

class PortalSquare < PairSquare
  def self.to_symbol
    :portal
  end

  def self.popover
    { title: "The Portal Square", body: "Here's a description of portal squares."}
  end
end

