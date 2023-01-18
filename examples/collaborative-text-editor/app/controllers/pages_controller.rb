# frozen_string_literal: true

class PagesController < ApplicationController
  def index
    full_state = REDIS.get(session.to_s)
    @editor_content = ""
    return if full_state.nil?

    @editor_content = Y::Lib0::Encoding.encode_uint8_array_to_base64(
      full_state.unpack("C*")
    )
  end

  private

  def session
    Session.new(path)
  end

  def path
    index_params[:path] || "default"
  end

  def index_params
    params.permit(:path)
  end
end
