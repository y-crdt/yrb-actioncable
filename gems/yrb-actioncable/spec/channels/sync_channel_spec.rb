# frozen_string_literal: true

RSpec.describe SyncChannel do
  let(:session) { Session.new("issues/1") }

  it "successfully subscribes" do
    subscribe path: session.id

    expect(subscription).to be_confirmed
  end

  it "sends sync step 1" do
    subscribe path: session.id

    transmission = transmissions.last
    update = Y::Lib0::Decoding.decode_base64_to_uint8_array(transmission["update"])
    decoder = Y::Lib0::Decoding.create_decoder(update)
    actual = Y::Lib0::Decoding.read_var_uint(decoder)

    expect(actual).to eq(Y::Sync::MESSAGE_YJS_SYNC_STEP_1)
  end

  it "replies with sync step 2" do
    subscribe path: session.id

    message = { update: "aabb", origin: "1" }

    expect do
      described_class.broadcast_to(session, message)
    end.to have_broadcasted_to(session).exactly(:once).with(message)
  end
end
