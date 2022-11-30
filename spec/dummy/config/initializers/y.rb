# frozen_string_literal: true

Y::Actioncable.configure do
  redis { |block| block.call(Redis.new) }
end
