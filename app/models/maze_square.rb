module MazeCraze
  class MazeSquare
    SQUARE_TYPE_CLASS_NAMES = ['EndpointSquare',
                               'BarrierSquare',
                               'BridgeSquare',
                               'TunnelSquare',
                               'PortalSquare']

    attr_reader :type, :index
    attr_accessor :status

    def initialize(type, status, index)
      @status = status
      @type = type
      @index = index
    end

    def self.types_popover
      SQUARE_TYPE_CLASS_NAMES.each_with_object({}) do |class_name, popover_content|
        class_name = 'MazeCraze::' + class_name
        square_class = Kernel.const_get(class_name) if Kernel.const_defined?(class_name)
        popover_content[square_class.to_symbol] = square_class.popover
      end
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
      { title: "The Barrier Square", body: "<p>Here's a description of barrier squares.</p>"}
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
      { title: "The Bridge Square", body: "<p>Here's a description of bridge squares.</p>"}
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
      { title: "The Endpoint Square", body: "<p>Here's a description of endpoint squares.</p>"}
    end
  end

  class TunnelSquare < PairSquare
    def self.to_symbol
      :tunnel
    end

    def self.popover
      { title: "The Tunnel Square", body: "<p>Here's a description of tunnel squares.</p>"}
    end
  end

  class PortalSquare < PairSquare
    def self.to_symbol
      :portal
    end

    def self.popover
      { title: "The Portal Square", body: "<p>Here's a description of portal squares.</p>"}
    end
  end
end
