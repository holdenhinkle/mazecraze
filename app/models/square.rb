class Square
  attr_reader :type, :index
  attr_accessor :status

  def initialize(type, status, index)
    @status = status
    @type = type
    @index = index
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

class PairSquare < Square
  attr_reader :group, :subgroup

  def initialize(type, status, group, subgroup, index)
    super(type, status, index)
    @group = group
    @subgroup = subgroup
  end
end

class EndpointSquare < PairSquare; end

class TunnelSquare < PairSquare; end

class PortalSquare < PairSquare; end

class BridgeSquare < Square
  attr_accessor :horizontal_taken, :vertical_taken

  def initialize(type, status, index)
    super(type, status, index)
    @horizontal_taken = false
    @vertical_taken = false
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