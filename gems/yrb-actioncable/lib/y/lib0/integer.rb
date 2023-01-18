# frozen_string_literal: true

module Y
  module Lib0
    module Integer
      N_BYTES = [42].pack('i').size
      N_BITS = N_BYTES * 16
      MAX = 2 ** (N_BITS - 2) - 1
      MIN = -MAX - 1
    end
  end
end
