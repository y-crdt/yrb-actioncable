# frozen_string_literal: true

class SyncChannel < ApplicationCable::Channel
  include Y::Actioncable::Reliable
  include Y::Actioncable::Sync

  # TODO: we can have a wide range of strategies to truncate message streams,
  #   periodically flushing is just one option.
  periodically :truncate_message_stream, every: 5.seconds

  def subscribed
    # initiate sync & subscribe to updates, with optional persistence mechanism
    sync_for(session) { |id, update| save_doc(id, update) }

    # tracker
    tracker.add(connection)
  end

  def unsubscribed
    tracker.remove(connection)
  end

  def receive(message)
    entry_id = append(message)

    # broadcast update to all connected clients on all servers
    sync_to(session, message)

    offset = entry_id
             .split("-")
             .reduce("") { |v, p| v + p.to_s.ljust(3, "0") }
             .to_i

    tracker.move(connection, offset)
  end

  def doc
    @doc ||= load { |id| load_doc(id) }
  end

  def truncate_message_stream
    min_offset = tracker.min
    entry_id = [min_offset[0..-4], min_offset[-3, 3]].join("-")
    truncate(entry_id)
  end

  private

  def session
    @session ||= Session.new(params[:path])
  end

  def load_doc(id)
    data = REDIS.get(id)
    data = data.unpack("C*") unless data.nil?
    data
  end

  def save_doc(id, state)
    REDIS.set(id, state.pack("C*"))
  end
end
